"""Plan or deploy the production API. Default is an offline plan, not deployment."""
import argparse
import json
import os
import re
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="Create billable AWS resources")
    parser.add_argument("--stack", default="artea-production-api")
    parser.add_argument("--region", default="ap-southeast-2")
    parser.add_argument("--profile")
    parser.add_argument("--image", help="ECR image URI pinned with @sha256:digest")
    parser.add_argument("--ses-identity-arn", help="Verified SES identity in the backend region")
    parser.add_argument("--account-email-from")
    parser.add_argument("--operations-email")
    parser.add_argument("--ai-secret-arn", default="")
    parser.add_argument("--receipt", type=Path, default=HERE / "backend-deployment.json")
    args = parser.parse_args()
    if not args.execute:
        print(json.dumps({"region": args.region, "stack": args.stack, "creates_resources": False,
            "architecture": ["CloudFront private VPC origin", "2 Fargate API tasks across 2 AZs; autoscale to 6", "private PostgreSQL Multi-AZ with 14-day backups", "Cognito verified email accounts", "private versioned artwork S3", "2 NAT gateways", "WAF in us-east-1", "CloudWatch alarms and SNS"],
            "prerequisites": ["AWS CLI v2 and authenticated profile", "ECR image digest built from server/Dockerfile", "verified SES identity and production email access", "operations email subscription confirmation"],
            "sequence": ["Create WAF", "Create private backend with zero tasks only for first deployment", "Run restricted one-shot schema task", "Start/maintain at least two API tasks", "Write edge deployment parameters containing IDs and ARNs only", "Publish packaged Web build separately"]}, indent=2))
        return
    for key in ["image", "ses_identity_arn", "account_email_from", "operations_email"]:
        if not getattr(args, key): parser.error("--" + key.replace("_", "-") + " is required with --execute")
    pattern = json.loads((HERE / "backend-cloudformation.json").read_text())["Parameters"]["ImageUri"]["AllowedPattern"]
    if not re.fullmatch(pattern, args.image): parser.error("Use an ECR image URI pinned by its sha256 digest")
    aws = shutil.which("aws")
    if not aws: parser.error("AWS CLI v2 is not installed")
    env = dict(os.environ, AWS_PAGER="", AWS_CLI_AUTO_PROMPT="off")
    def run(*command, region=None):
        invocation = [aws, *command, "--region", region or args.region, "--no-cli-pager", "--output", "json"]
        if args.profile: invocation += ["--profile", args.profile]
        result = subprocess.run(invocation, env=env, check=True, capture_output=True, text=True)
        return json.loads(result.stdout) if result.stdout.strip().startswith(("{", "[")) else None
    def outputs(stack, region=None):
        result = run("cloudformation", "describe-stacks", "--stack-name", stack, region=region)
        return {item["OutputKey"]: item["OutputValue"] for item in result["Stacks"][0]["Outputs"]}
    identity = run("sts", "get-caller-identity")
    if not args.ses_identity_arn.startswith(f"arn:aws:ses:{args.region}:{identity['Account']}:identity/"):
        parser.error("Use an SES identity in the same AWS account and region")
    if not run("sesv2", "get-account").get("ProductionAccessEnabled"):
        raise SystemExit("SES production email access is required before creating the production stack.")
    email_identity = args.ses_identity_arn.split(":identity/", 1)[1]
    if not run("sesv2", "get-email-identity", "--email-identity", email_identity).get("VerifiedForSendingStatus"):
        raise SystemExit("The SES identity is not verified for sending.")
    prefix = run("ec2", "describe-managed-prefix-lists", "--filters", "Name=prefix-list-name,Values=com.amazonaws.global.cloudfront.origin-facing")["PrefixLists"][0]["PrefixListId"]
    existing = run("cloudformation", "list-stacks", "--stack-status-filter", "CREATE_COMPLETE", "UPDATE_COMPLETE", "UPDATE_ROLLBACK_COMPLETE")
    is_update = any(item["StackName"] == args.stack for item in existing["StackSummaries"])
    parameters = ["CloudFrontPrefixListId=" + prefix,
        "SesIdentityArn=" + args.ses_identity_arn, "AccountEmailFrom=" + args.account_email_from,
        "OperationsEmail=" + args.operations_email, "AiSecretArn=" + args.ai_secret_arn]
    runtime_image = args.image
    if is_update:
        current = run("cloudformation", "describe-stacks", "--stack-name", args.stack)["Stacks"][0]
        runtime_image = next(parameter["ParameterValue"] for parameter in current["Parameters"] if parameter["ParameterKey"] == "ImageUri")
    def deploy(count, image):
        run("cloudformation", "deploy", "--stack-name", args.stack, "--template-file", str(HERE / "backend-cloudformation.json"),
            "--capabilities", "CAPABILITY_IAM", "--no-fail-on-empty-changeset", "--parameter-overrides", *parameters, "ImageUri=" + image, "MigrationImageUri=" + args.image, "DesiredCount=" + str(count))
    print("Deploying WAF and private backend. Initial database provisioning can take tens of minutes.", flush=True)
    run("cloudformation", "deploy", "--stack-name", args.stack + "-waf", "--template-file", str(HERE / "waf-cloudformation.json"), "--no-fail-on-empty-changeset", region="us-east-1")
    deploy(2 if is_update else 0, runtime_image)
    result = outputs(args.stack)
    network = {"awsvpcConfiguration": {"subnets": result["PrivateSubnets"].split(","), "securityGroups": [result["AppSecurityGroup"]], "assignPublicIp": "DISABLED"}}
    task = run("ecs", "run-task", "--cluster", result["ClusterName"], "--task-definition", result["MigrationTaskArn"], "--launch-type", "FARGATE", "--network-configuration", json.dumps(network))
    if task.get("failures") or not task.get("tasks"): raise SystemExit("Migration task could not start; inspect ECS events.")
    arn = task["tasks"][0]["taskArn"]
    run("ecs", "wait", "tasks-stopped", "--cluster", result["ClusterName"], "--tasks", arn)
    status = run("ecs", "describe-tasks", "--cluster", result["ClusterName"], "--tasks", arn)["tasks"][0]
    if not status.get("containers") or any(container.get("exitCode") != 0 for container in status["containers"]):
        raise SystemExit("Database preparation failed. Inspect the migration CloudWatch log; the API was not promoted.")
    deploy(2, args.image)
    run("ecs", "wait", "services-stable", "--cluster", result["ClusterName"], "--services", result["ServiceName"])
    result = outputs(args.stack)
    result["WebAclArn"] = outputs(args.stack + "-waf", "us-east-1")["WebAclArn"]
    result["region"] = args.region
    args.receipt.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("Backend is stable. Edge deployment parameters:")
    print(json.dumps({key: result[key] for key in ["ApiDomain", "VpcOriginId", "OriginSecretArn", "WebAclArn"]}, indent=2))
    print("Receipt: " + str(args.receipt))


if __name__ == "__main__": main()
