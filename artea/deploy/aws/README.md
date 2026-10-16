# Artéa AWS playtest package

This package hosts the existing browser game on **private Amazon S3 + public HTTPS Amazon CloudFront**. Testers open a link; they do not need AWS accounts or a game installation. It includes the latest automatic Heart Melody return gates, readable banners, and fruit bucket eating feature.

## Quick deployment from your computer

1. Extract the ZIP completely. Open a terminal in the extracted `artea-aws-...` folder, beside this README.
2. Install **Python 3.11 or newer** and **AWS CLI v2** if needed. The Python scripts use only the standard library.
3. Sign in using your own AWS account. For an organization with IAM Identity Center, run `aws configure sso`, then `aws sso login --profile YOUR_PROFILE`. If you already use a different AWS CLI login method, keep that configured profile. Do not put AWS keys into the game, ZIP, or source code.
4. Check the package without contacting AWS:

   ```powershell
   python deploy.py --plan
   ```

5. Deploy when ready:

   ```powershell
   python deploy.py --stack artea-playtest --region ap-southeast-2 --profile YOUR_PROFILE
   ```

   Omit `--profile YOUR_PROFILE` if you use the default profile. Keep the same stack name and region for future updates. The region defaults to Sydney; CloudFront distributes the game globally. Provisioning and the first upload can take several minutes. Leave the terminal running. Running this command creates billable AWS resources and makes the game publicly accessible.

6. The script prints `Published: https://....cloudfront.net/` and records it in `deployment.json`. Open that URL, complete the browser checks below, and share it with testers. No custom domain or certificate purchase is needed for the CloudFront URL.

Your AWS identity needs permission to manage this CloudFormation stack, its S3 bucket/policy/objects, and the CloudFront distribution, OAC, cache policy, response headers policy, and invalidations. The template creates no IAM users, access keys, or roles. If your account restricts these services, ask its administrator to deploy the supplied template; do not use root credentials for routine deployment.

## What testers do

- **Play the full game:** choose **Offline Guest** on the game start screen.
- **Try Heart Melody:** opens the world directly as an offline guest.
- Walk into a castle-return arch to return automatically.
- In Heart Melody, open **Valley map / journal → Open fruit bucket / eat fruit**. Eating restores up to 20 health and 20 focus. Story fruit and unlocked instrument voices stay protected.
- Include the build ID shown on the landing page, browser/device, reproduction steps and a screenshot when reporting issues through your usual feedback channel. This package does not collect or send feedback automatically.

The landing page states the download size. The current game is a large download (roughly three-quarters of a GB before transport compression). Desktop/laptop testing with WebGL2 and a stable connection is the initial target; mobile performance is not certified. Guest progress lives in that browser's local storage, not in S3. Clearing site data or changing browser/domain can make saves unavailable. Versioned releases on the same CloudFront origin retain the same browser storage origin.

## Check locally before uploading

```powershell
python verify.py
python preview.py
```

Open `http://127.0.0.1:8877/`. Keep that terminal open. In a second terminal:

```powershell
python verify.py --url http://127.0.0.1:8877/
```

Do not double-click `index.html`; WebAssembly, workers and browser isolation require an HTTP server locally and HTTPS on the public site.

## AWS Console alternative

1. In **CloudFormation**, create a standard stack using **Upload a template file → cloudformation.json**. Name it `artea-playtest` and wait for `CREATE_COMPLETE`.
2. In stack **Outputs**, note `BucketName`, `DistributionId`, and `WebsiteURL`.
3. In the named S3 bucket, upload the contents of `site/releases/` under the `releases/` prefix, keeping all paths exactly as packaged. Do not upload the ZIP itself or the enclosing `site` directory as a prefix. Keep **Block Public Access** enabled; do not enable S3 website hosting or public ACLs.
4. Set object metadata according to `manifest.json`: `.wasm` = `application/wasm`, `.js` = `application/javascript`, `.html` = `text/html; charset=utf-8`, `.json` = `application/json`, `.png` = `image/png`, and `.partNN` = `application/octet-stream`. Release objects use `Cache-Control: public, max-age=31536000, immutable`. S3's MIME guesses alone are insufficient for all files.
5. Upload `site/index.html` to the bucket root **last**, with `Content-Type: text/html; charset=utf-8` and `Cache-Control: no-store, max-age=0`.
6. On updates, invalidate `/` and `/index.html` in the CloudFront distribution and wait for completion.
7. Run `python verify.py --url https://YOUR_DISTRIBUTION.cloudfront.net/` and complete the browser checks below. Use the CloudFront URL, not the S3 object or website URL.

The deployment script is preferable because it handles the metadata, order and checks automatically. No AWS resources were created when this package was prepared.

## Public browser verification

HTTP verification checks every runtime file, length, MIME type, and isolation header. It is not a substitute for gameplay testing:

1. Open the HTTPS link in a fresh Chrome/Edge browser profile with hardware acceleration enabled.
2. Confirm the landing page appears. Start the full game and wait through the complete download.
3. Confirm the start screen renders; choose Offline Guest and move around the castle.
4. Open the Heart Melody link. Test movement, an automatic return gate, fruit collection/eating, and banner readability from several camera angles.
5. Reload and confirm saved progress survives. In DevTools, check for missing assets, WebGL2 errors, script exceptions, and failed network requests.
6. In the browser console, `window.isSecureContext` and `window.crossOriginIsolated` should both be `true`. The Network tab should show `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`.

The source repository also includes `artea/tools/web-smoke.js`, a Chromium smoke test. It can be run against a release's `index.html`, or against `heart.html` with `--heart`.

## Updates, rollback and cleanup

Re-export the project using its maintained standard non-Mono Godot Web export script. From the repository root, generate another package:

```powershell
python artea/deploy/aws/package.py
```

Packages appear under `artea/artifacts/aws/`. Only files named by the current runtime and pack manifest are included; export logs, `.import` sidecars, old split parts and local server files are excluded. Every upload file has a SHA-256 checksum. Changing the runtime or generated entry pages produces a new release path.

Run the new package's `deploy.py` using the **same stack and region**. Old releases are not deleted. If an upload or release check fails, the previous landing page remains live. To roll back, run the previous package's deployment script against the same stack. Existing tabs may remain on their old release until testers return to the landing page.

S3 storage, requests and CloudFront delivery incur AWS charges. The template uses `PriceClass_All` so Australian and other global edge locations can serve testers. Set a budget alert in your AWS account and check usage during testing. There is no always-running EC2 server. Remove unused release prefixes only after you no longer need them for rollback. Deleting the stack removes its distribution and policies but **retains the S3 bucket and uploaded data**; empty and delete that retained bucket separately when you want to stop its storage charges. CloudFormation deletion and CloudFront disablement may take time.

## Scope and troubleshooting

- This is static game hosting. It does not deploy the repository's separate backend, a database, multiplayer servers, or cross-device save synchronization. Guest playtesting is the validated entry path. Existing online sign-in/API features need their own backend configuration and authorized domains for the new hostname.
- If the loader reports missing isolation headers, use CloudFront and check the response headers policy. The headers support Godot's WebAssembly/GDExtension runtime; keep them enabled.
- If a `.wasm` fails to compile, check its content type and ensure the bytes are not an HTML error page. Missing resources intentionally retain 403/404 responses; there is no blanket rewrite to HTML.
- If saving fails in private browsing or storage-restricted browsers, use a regular browser profile with site storage enabled.
- This package includes the exported game content. AWS credentials and separate server configuration are neither needed by nor bundled with the browser upload.

## Reference documentation

- [AWS CLI installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [AWS CLI IAM Identity Center setup](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)
- [AWS: private S3 origins with CloudFront OAC](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
- [AWS: response headers policy](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-properties-cloudfront-responseheaderspolicy-customheader.html)
- [AWS: cache-policy minimum TTL](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cache-key-understand-cache-policy.html)
- [Godot: exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
