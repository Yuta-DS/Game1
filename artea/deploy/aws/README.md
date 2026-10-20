# Artéa AWS production deployment

Prepared for a **fresh production launch in Sydney (`ap-southeast-2`)**, across two availability zones. No AWS resources are created by packaging or running a plan. This is a billable high-availability setup, not a free-tier playtest.

| Game component | AWS service | Storage and protection |
|---|---|---|
| Landing page, Web runtime, world packs | Private S3 + CloudFront OAC | HTTPS CDN, versioned releases, immutable hashed chunks; public bucket access blocked |
| Usernames, passwords, email verification and recovery | Cognito | Passwords stay in Cognito; production does not store password hashes in PostgreSQL |
| Flask API and AI adapters | ECS Fargate + private ALB + CloudFront VPC origin | Two private tasks in separate AZs, autoscaling up to six; no public task or API origin |
| Player IDs and artwork metadata | RDS PostgreSQL Multi-AZ | Private networking, encrypted storage, verified TLS, 14-day backups, restricted runtime DB role |
| Uploaded artwork | Separate private, versioned S3 bucket | Owner-authorized reads, encryption, 90-day old-version retention |
| Guest and signed-in journey/garden progress | Browser IndexedDB / Godot user data | Existing local saves are preserved. **Cross-device cloud progress sync is not implemented.** Uploaded artwork is cloud-backed. |
| Secrets/provider keys | Secrets Manager | ECS injects secrets; no credentials go into the public game or package |
| Container image | ECR | Immutable tags, scan on push, deployment by digest |
| Operations and protection | CloudWatch, SNS, WAF | Logs, DB-space/API-error alarms, edge managed rules, account endpoint throttling |
| Verification/recovery email | SES via Cognito | Requires a verified sender and SES production access |
| Optional domain | Route 53 + ACM | CloudFront's HTTPS domain works without a custom domain; custom CloudFront certificates belong in us-east-1 |

The API uses a server-only Cognito app-client secret; the task role may describe clients in its configured user pool. Public browser code never receives this secret. Refresh tokens are returned in signed, expiring envelopes held in memory.

Local development still uses the existing Flask/SQLite/bcrypt server at port 8000. Production uses the separate `server/aws_app.py` adapter. Existing team accounts are not migrated, as requested.

## Faster loading

1. The small landing page renders before Godot downloads.
2. The login screen requires only bootstrap assets, engine and startup dependencies.
3. Hub/common runtime packs download during sign-in and mount on hub entry.
4. Once the hub is playable, later worlds prefetch in likely next-use order. Explicit travel takes priority.
5. Pack files use 8 MiB content-hashed chunks, bounded parallel downloads, retries and immutable caching.
6. Packaging precompresses worthwhile JS, Wasm and binary chunks with deterministic gzip and correct S3 `Content-Encoding`. CloudFront does not automatically compress `application/octet-stream`.

Chunking alone does not reduce total data or scene/shader construction time. The deferred common-runtime pack deliberately retains dynamically discovered/legacy resources; auditing these is the next step toward a faster login-to-movement transition. Cold and cached loads must both be measured. The landing page reports measured package download sizes.

`web-packs.json` records all current packs, including dependencies. Packaging follows modern hashed manifests and split Wasm, rejects missing/truncated/unsafe paths and mixed exports, and excludes stale parts and private files. Every uploaded file has SHA-256, MIME, cache and encoding metadata. Only `site/` is public; backend code and deployment tools are outside it.

## Prepare and validate

From the source repository, use the standard **non-Mono** Godot exporter (set `GODOT_BIN` for Git Bash):

```powershell
bash artea/scripts/export_web.sh
python artea/deploy/aws/deploy_backend.py
python artea/deploy/aws/package.py
```

The first Python command prints an offline plan. The second prints a standalone package directory. Inside that directory:

```powershell
python verify.py
python deploy.py --plan
python preview.py --port 8877
```

Open `http://127.0.0.1:8877/`. This previews packaged static content and guest gameplay; it does not simulate deployed Cognito. Production account requests use same-origin `/api`. For local username/password testing, continue using the regular local preview with Flask running on port 8000.

Source checks:

```powershell
server/venv/Scripts/python.exe -m unittest server.test_aws_production
python -m unittest discover -s artea/deploy/aws -p test_package.py
cfn-lint artea/deploy/aws/*cloudformation.json
```

Boundary tests mock Cognito/S3 and use real signed test tokens with an isolated database. They do not certify real email delivery, AWS connectivity or failover. Docker must be running to validate the Linux container image.

## Deploy in this order

Use AWS CLI v2 with your own SSO/profile login. Never put access keys in the repository or ZIP. The deployment identity needs permissions for the template resources and IAM/service-linked-role creation; application runtime roles are much narrower.

1. Verify an SES sender in Sydney and obtain production email access. Choose an operations mailbox. Create the ECR repository:

   ```powershell
   aws cloudformation deploy --template-file registry-cloudformation.json --stack-name artea-production-images --region ap-southeast-2 --profile YOUR_PROFILE
   aws cloudformation describe-stacks --stack-name artea-production-images --region ap-southeast-2 --profile YOUR_PROFILE --query "Stacks[0].Outputs"
   ```

2. Use its repository URI/registry hostname to build Linux AMD64, push and review scan findings:

   ```powershell
   aws ecr get-login-password --region ap-southeast-2 --profile YOUR_PROFILE | docker login --username AWS --password-stdin REGISTRY_HOST
   docker buildx build --platform linux/amd64 -t REPOSITORY_URI:RELEASE_ID --load server
   docker push REPOSITORY_URI:RELEASE_ID
   ```

   Retrieve the image digest with `aws ecr describe-images`. Use `REPOSITORY_URI@sha256:DIGEST`, not `latest`.

3. Deploy the backend:

   ```powershell
   python deploy_backend.py --execute --profile YOUR_PROFILE --image REPOSITORY_URI@sha256:DIGEST --ses-identity-arn arn:aws:ses:ap-southeast-2:ACCOUNT:identity/VERIFIED_IDENTITY --account-email-from accounts@YOUR_DOMAIN --operations-email operations@YOUR_DOMAIN
   ```

   This creates WAF in us-east-1 and the private backend in Sydney. Initially, API tasks remain at zero until a one-shot task creates the fresh schema and restricted `artea_app` DB role. It then starts two tasks and waits for stability. Updates keep the existing service running during schema preparation. Future schema changes require explicit backward-compatible migrations; `create_all` is not an upgrade migration system.

   Confirm the SNS email subscription. Check the account's CloudFront origin response-timeout quota against 100 seconds, ECS/service-linked-role permissions, SES limits, and two-AZ RDS capacity. These checks require the target AWS account.

4. Publish the site using the four outputs in `backend-deployment.json`:

   ```powershell
   python deploy.py --stack artea-production-web --region ap-southeast-2 --profile YOUR_PROFILE --backend-domain API_DOMAIN --backend-vpc-origin-id VPC_ORIGIN_ID --backend-origin-secret-arn SECRET_ARN --web-acl-arn WAF_ARN
   ```

   API responses are never cached. CloudFront privately reaches the internal ALB and adds an origin-only secret, which Flask checks. Browser requests never contain that secret. The private origin also avoids API Gateway's shorter timeout for existing AI requests. Previous Web releases remain available; the landing page pointer is published last.

5. Run `python verify.py --url https://DISTRIBUTION.cloudfront.net/` and the acceptance checks below before launch.

## Optional AI configuration

Without provider keys, existing offline/degraded fallbacks remain available. Do not point production at the developer's `localhost:20128`. Create a Secrets Manager JSON secret containing all these keys (unused values may be empty), then supply its ARN with `deploy_backend.py --ai-secret-arn ...`:

```json
{
  "OMNIROUTE_BASE_URL": "https://YOUR_PROVIDER/v1",
  "OMNIROUTE_CREATIVE_GUIDE_API_KEY": "",
  "OMNIROUTE_WORLD_BUILDER_API_KEY": "",
  "OMNIROUTE_BACKUP_API_KEY": "",
  "OPENROUTER_API_KEY": ""
}
```

Production AI requests require authentication. Configure provider spending limits. AI cache files are ephemeral per-task optimizations, not durable player records; a shared cache/async job queue can follow measured demand.

## Acceptance, costs and operations

- Test verified-email signup, confirmation/resend, wrong passwords, password recovery, sign-in and token refresh using real deployed Cognito/SES.
- Measure bytes/time to login, bytes/time to hub, and input responsiveness on a cold profile and cached revisit. Test retries and world entry before prefetch finishes.
- Play Castle, World 1 and Heart Melody; verify Milo, instruments, camera and return gates. A second account and guest must not download another user's private artwork.
- Confirm both tasks are healthy in separate AZs, stop one and verify recovery, then schedule RDS failover/reconnect and backup-restore drills. Linting is not a failover test.
- Verify secure context, cross-origin isolation, WebGL2, network assets and script logs. Exercise WAF rules against legitimate artwork/AI payloads before broad launch.
- Do not log passwords, bearer tokens, provider keys, artwork or player reflections. Operators should use IAM Identity Center/MFA. Review image scan results and IAM access before promotion.
- Buckets and Cognito users are retained on stack removal; RDS snapshots and deletion protection are enabled. These protections need a documented retention, erasure and incident-response policy before collecting real user data.
- Rotate the application DB password together with the actual DB role and ECS rollout. Coordinate origin-secret rotation between CloudFront and API tasks. The template does not rotate only one side silently.
- Two NAT gateways, Multi-AZ RDS, two Fargate tasks, ALB, WAF, logs and storage incur baseline costs even with few users. CDN transfer, Cognito, SES and optional AI add usage charges. Estimate Sydney traffic/active users with the [AWS Pricing Calculator](https://calculator.aws/); no fixed monthly price is implied.

References: [private S3 origins](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html), [private VPC origins and Sydney support](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-vpc-origins.html), [compression conditions/MIME types](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/ServingCompressedFiles.html), [Cognito access tokens](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-the-access-token.html), [RDS managed credentials](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html), [Godot Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).
