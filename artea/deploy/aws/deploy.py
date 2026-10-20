"""Create/update the AWS playtest stack and publish a verified release."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from verify import validate, verify_host

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--stack", default="artea-playtest", help="Use the same name for updates")
    parser.add_argument("--region", default="ap-southeast-2")
    parser.add_argument("--profile", help="Optional named AWS CLI profile")
    parser.add_argument("--backend-vpc-origin-id", default="")
    parser.add_argument("--backend-domain", default="")
    parser.add_argument("--backend-origin-secret-arn", default="")
    parser.add_argument("--web-acl-arn", default="")
    parser.add_argument("--plan", action="store_true", help="Validate files and show plan without contacting AWS")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9-]{0,63}", args.stack): parser.error("Stack name must be 1-64 letters, digits or hyphens, starting with a letter")
    package = args.package.resolve()
    manifest = validate(package)
    if args.plan:
        print(json.dumps({"stack": args.stack, "region": args.region, "release": manifest["release"], "files": len(manifest["files"]), "bytes": manifest["total_bytes"], "actions": ["Create/update private S3 + CloudFront stack", "Upload immutable release with MIME metadata", "Verify release HTTP headers and assets", "Publish landing page last", "Invalidate landing page cache", "Verify public endpoint"]}, indent=2))
        return
    if not all([args.backend_domain, args.backend_vpc_origin_id, args.backend_origin_secret_arn, args.web_acl_arn]):
        parser.error("Production publishing requires the backend domain, private VPC origin ID, origin secret ARN and WAF ARN.")
    aws = shutil.which("aws")
    if not aws: raise SystemExit("Install AWS CLI v2 and configure an AWS login first. See README.md.")
    common = ["--region", args.region, "--no-cli-pager"]
    if args.profile: common += ["--profile", args.profile]
    env = dict(os.environ, AWS_PAGER="", AWS_CLI_AUTO_PROMPT="off")
    def run(*command, json_output=False):
        result = subprocess.run([aws, *command, *common, *(["--output", "json"] if json_output else [])], env=env, check=True, text=True, capture_output=json_output)
        return json.loads(result.stdout) if json_output else None
    # Confirm credentials before creating anything. Do not store or package keys.
    run("sts", "get-caller-identity", json_output=True)
    print("Creating/updating AWS stack. CloudFront provisioning can take several minutes.", flush=True)
    run("cloudformation", "deploy", "--template-file", str(package / "cloudformation.json"), "--stack-name", args.stack, "--no-fail-on-empty-changeset", "--parameter-overrides", "BackendDomain=" + args.backend_domain, "BackendVpcOriginId=" + args.backend_vpc_origin_id, "BackendOriginSecretArn=" + args.backend_origin_secret_arn, "WebAclArn=" + args.web_acl_arn)
    stack = run("cloudformation", "describe-stacks", "--stack-name", args.stack, json_output=True)["Stacks"][0]
    outputs = {item["OutputKey"]: item["OutputValue"] for item in stack["Outputs"]}
    bucket, distribution, url = (outputs[k] for k in ("BucketName", "DistributionId", "WebsiteURL"))
    run("cloudfront", "wait", "distribution-deployed", "--id", distribution)
    def upload(item):
        run("s3", "cp", str(package / "site" / item["path"]), f"s3://{bucket}/{item['path']}", "--content-type", item["content_type"], "--cache-control", item["cache_control"], "--only-show-errors", *(["--content-encoding", item["content_encoding"]] if item.get("content_encoding") else []))
    releases = [item for item in manifest["files"] if item["path"] != "index.html"]
    print(f"Uploading {len(releases)} release files; existing releases remain available.", flush=True)
    with ThreadPoolExecutor(max_workers=4) as pool: list(pool.map(upload, releases))
    verify_host(url, manifest, release_only=True)
    upload(next(item for item in manifest["files"] if item["path"] == "index.html"))
    invalidation = run("cloudfront", "create-invalidation", "--distribution-id", distribution, "--paths", "/", "/index.html", json_output=True)
    run("cloudfront", "wait", "invalidation-completed", "--distribution-id", distribution, "--id", invalidation["Invalidation"]["Id"])
    verify_host(url, manifest)
    receipt = {"stack": args.stack, "region": args.region, "release": manifest["release"], **outputs}
    (package / "deployment.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(f"Published: {url}\nHeart Melody: {url}releases/{manifest['release']}/heart.html")
    print("Now perform the browser playtest checklist in README.md; HTTP checks alone do not prove gameplay.")

if __name__ == "__main__": main()
