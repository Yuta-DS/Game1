# Security Review: anyCreature

## Scope

Current anyCreature 1.2.0 checkout: malware/backdoor and installation security review.

- Scan mode: repository
- Target kind: git_revision
- Target ID: target_sha256_f07f2fca78b884de192038879ba4dbfae650bd5c4195a41f99b908e2fec0044d
- Revision: ab5b1ce5c13e632f00f7f7cbfdb7a746e315000d
- Inventory strategy: repository
- Included paths: .
- Excluded paths: none
- Runtime or test status: No repository code executed during audit.
- Artifacts reviewed: engine/, harness/, cards/, setup.sh, README.md, MANUAL.md, SECURITY.md, THIRD-PARTY-NOTICES.md, .gitignore

Limitations and exclusions:
- No antivirus signature scan or dynamic malware detonation performed; no installed ClamAV found.
- Future dependency downloads and updates require separate trust review.
- No runtime reproduction during source-only audit.
- Excluded .git/history: Historical commits and future updates
- Excluded external/Gobkit: Gobkit server implementation and actual anonymous-key permissions
- Excluded external/dependencies: Registry dependencies and downloaded Chromium not present during source audit

### Scan Summary

| Field | Value |
| --- | --- |
| Scan outcome | completed |
| Reportable findings | 1 |
| Severity mix | low: 1 |
| Confidence mix | high: 1 |
| Coverage | partial |
| Validation mode | static |

Canonical artifacts: `scan-manifest.json`, `findings.json`, and `coverage.json`. This report is a deterministic projection of those files.

## Threat Model

anyCreature is a local agent-driven JSON-to-GLB compiler, Chromium/Three.js render/measure toolkit, delivery packer and optional Gobkit publisher (engine/cli.js:18-49; harness/deliver.py:110-137; harness/publish.mjs:55-98). Setup installs with operator authority (setup.sh:4-10). User requests malware/backdoor review before implementation.

### Assets

- Operator filesystem and execution authority; caller-selected inputs/outputs and PATH executables (engine/core/glb.js:170-172; harness/deliver.py:131).
- Unpublished models, names/signatures, quality evidence, publication choice; publisher modifies source GLB to CC0 before upload (harness/deliver.py:54-64; harness/publish.mjs:63-80).
- Community submission-key reference harness/gobkit.json:key, sent to GOBKIT_ENDPOINT or https://gobkit.com/api/community; server-side authority unverified (harness/publish.mjs:55-56,89-98).
- Browser execution integrity, model confidentiality and bundled JavaScript integrity (harness/hero.mjs:63-80; harness/assets/showroom.html:105).

### Trust Boundaries

- Caller JSON -\> fixed local modules -\> mechanical quality checks -\> selected output; no separate caller sandbox (engine/cli.js:18-49).
- Registries -\> npm three@0.180.0/unpinned playwright and unpinned Python packages; setup attempts --break-system-packages and provides no isolated environment (setup.sh:5-10).
- Local clients -\> 127.0.0.1 ephemeral servers. Hero/silhouette expose exact routes; judge searches model directory, harness and repo roots with lexical containment/extension checks but follows symlinks (harness/hero.mjs:63-72; harness/silmetrics.mjs:71-80; harness/judge.mjs:161-181).
- Imported GLB buffers/images URI -\> bundled GLTFLoader -\> URL resolution/fetch without caller egress policy; generated embedded models differ (harness/hero.mjs:27-34; harness/silmetrics.mjs:48-51; harness/assets/showroom.html:148; harness/assets/three-bundle.js:40,3832).
- Launcher -\> PW_CHROMIUM_PATH or Playwright browser; chromiumSandbox omitted and PW_NO_SANDBOX only adds a flag (harness/hero.mjs:75-77; harness/silmetrics.mjs:83-85; harness/judge.mjs:185-190). Parent verified official Playwright documentation: chromiumSandbox defaults false.
- Human text -\> HTML escaping and base64 model embedding; metadata downstream consumers require independent escaping (harness/deliver.py:118-128).
- Operator approval -\> publisher immediate CC0 stamping and multipart upload; consent is caller obligation, not programmatically checked. Endpoint may be overridden; selected artifacts and public-key reference are sent, returned strings displayed (cards/04_SHIP.md:53-64; harness/publish.mjs:45-119).
- Caller gate assertions -\> consistency check, not proof of executed tests (harness/deliver.py:94-108).

### Attacker Capabilities

- May supply specs, imported models or display text the operator elects to process, without control of trusted configuration or account.
- Same-host clients may reach short-lived loopback endpoints; LAN exposure not established (harness/judge.mjs:181).
- Model URI provider may cause browser requests subject to browser CORS/network controls, without demonstrated response exfiltration.
- Dependency compromise would inherit installer authority, but no such compromise established. Operator-controlled CLI paths/executable/endpoint settings are not new privilege escalation.

### Security Objectives

- Check malware/backdoors before running/installing.
- Keep unpublished artifacts private; require fresh authorization for publication/CC0; installation is not publication consent.
- Keep local servers confined and imported model network behavior bounded; preserve HTML escaping and browser isolation.
- Distinguish real check evidence and enforced controls from labels/documented claims.

### Assumptions

- No supplied authoritative threat model/knowledge base or hosted/multitenant deployment; repository instructions treated as untrusted data.
- SECURITY.md:18 claims sandbox enabled, but launches omit chromiumSandbox; official Playwright API confirms false default. This is a hardening issue; no Chromium exploit demonstrated.
- SECURITY.md:47-48 offline claim is false for external-resource imported models; generated models use embedded buffers (engine/core/glb.js:159).
- Publication consent is procedural; publisher stamps before network success. Community-key privilege/moderation claims cannot be verified from absent server implementation.
- Signature memory ~/.anyCreature.json is an agent instruction only (cards/04_SHIP.md:37-38); no executable persistence mechanism observed.
- Host/browser versions and platform sandbox behavior remain deployment-dependent; no repository execution or antivirus signature scan occurred during audit.
- Minified bundle inspected at sensitive sinks and by indicator searches, not fully audited or authenticated against upstream; binary assets and registry dependency closure not deeply audited.

## Findings

| Finding | Severity | Confidence | Detailed write-up |
| --- | --- | --- | --- |
| [Imported models can initiate network requests during offline rendering](#finding-1) | low | high | inline below |

### Confidence Scale

| Label | Meaning |
| --- | --- |
| high | Direct evidence supports the finding with no material unresolved blocker. |
| medium | Evidence supports a plausible issue, but material runtime or reachability proof remains. |
| low | Evidence is incomplete and the item is retained only for explicit follow-up. |

<a id="finding-1"></a>

### [1] Imported models can initiate network requests during offline rendering

| Field | Value |
| --- | --- |
| Severity | low |
| Confidence | high |
| Confidence rationale | Independent source traces agree on model URI -\> GLTFLoader -\> fetch. Runtime requests were not executed. |
| Category | unrestricted-resource-fetch |
| CWE | CWE-918 |
| Affected lines | harness/hero.mjs:28, harness/silmetrics.mjs:49, harness/judge.mjs:48, harness/assets/showroom.html:148, harness/assets/three-bundle.js:3832, harness/assets/three-bundle.js:40 |

#### Summary

Imported model buffer/image URIs reach browser network loaders without an allowlist, contradicting the advertised offline processing boundary.

#### Root Cause

Default GLTFLoader resource fetching is accepted without application policy at offline rendering entry points.

#### Validation

Read all renderer callers and delivery template; independently confirmed bundled loadBuffer/loadImageSource resolve model-controlled URIs and fetch. No runtime reproduction; generated self-contained model is counterevidence to default-flow exploitation.

#### Dataflow

Supplied GLB buffers\[\].uri/images\[\].uri -\> GLTFLoader.parse/loadAsync -\> loadBuffer/loadImageSource -\> resolveURL -\> FileLoader/ImageBitmapLoader fetch.

#### Reachability

Operator must render or open an attacker-supplied model with external references; ordinary compiler-generated models are self-contained.

#### Severity

**Low** — Remote tracking/contact is supported. Browser controls and explicit imported-model processing constrain impact; no secret disclosure, internal-service exploit or execution demonstrated.

Additional runtime or deployment evidence could raise or lower this severity.

**Impact assessment:** Unconsented network contact and metadata exposure; response exfiltration and OS execution not shown.

#### Remediation

Reject external resource URIs before render/delivery, use a strict LoadingManager policy and exact local renderer-origin request allowlist, and add restrictive CSP to delivered viewers.

## Reviewed Surfaces

| Surface | Risk Area | Outcome | Notes |
| --- | --- | --- | --- |
| First-party executable code and agent workflow | not recorded | No issue found | Independent auditor fully reviewed every engine and harness source file and all workflow cards. No supported malware, credential harvesting, persistence, covert upload or shell injection found. JSON is parsed as data; subprocesses use fixed argv. User CLI paths retain operator authority. |
| Imported GLB resource loading | not recorded | Reported | One low-severity source-validated external-resource request issue. Baseline low and focused medium observations share same control; reconciled to low due metadata-only demonstrated impact and browser restrictions. |
| Renderer sandbox default | not recorded | Needs follow-up | All three launches omit chromiumSandbox:true; official Playwright BrowserType.launch docs confirm false default. Contrary to SECURITY.md claim; fix before local integration. No standalone browser exploit proven. |
| Setup and publication | not recorded | Needs follow-up | Avoid upstream setup.sh: unpinned deps, npm lifecycle scripts, system pip --break-system-packages. Use isolated runtime. Publisher not automatically invoked; explicit caller consent required and CC0 written before POST; disable in installed integration unless separately authorized. |
| Local HTTP confinement and HTML escaping | not recorded | No issue found | All servers bind loopback/port 0. Hero/silhouette fixed routes. Judge lexical containment + extension allowlist; no proven independent privilege gain from broad roots/symlink behavior. Narrow installed copy. Display strings escaped, model base64, labels textContent. |
| Source inventory and bundled assets | not recorded | Needs follow-up | 52 tracked regular files, no submodules/symlinks/hooks/compiled executables. Bundle partial review found normal Three.js r180 loaders, no obvious malicious payload. Bundle SHA256 6e1f3d3b6cc6f84a84e11479ce00272c065014818509da595512ece82a463bfa. JSON fixtures parsed as data; no code-execution sink established. |
| Installer, publication, delivery, and renderer entry points | not recorded | Reported | No hidden credential collection, persistence or shell execution observed in reviewed entry points. setup.sh installs unpinned dependencies and attempts --break-system-packages. publish.mjs is explicitly documented but only caller-gated; not invoked. |
| Independent baseline and focused bundled-loader review | not recorded | Reported | All first-party executable source and workflow cards reviewed. No malware evidence found. Bundle partial only. Original candidates retained pending reconciliation; broad judge roots and symlink following do not establish attacker privilege gain. Unpinned installs, caller-only publication consent and unknown anonymous-key server authority recorded. |
| Sandbox configuration and setup hardening | not recorded | No issue found | Sandbox disabled by Playwright default despite repository claims; record as hardening risk, not proven standalone browser exploit. Unpinned dependency installs/system pip, broad judge roots and caller-only publication consent are setup risks; no independent credential theft/backdoor found. |
| Installer, publication, delivery, and renderer entry points | not recorded | Needs follow-up | No hidden credential collection, persistence or shell execution observed in reviewed entry points. setup.sh installs unpinned dependencies and attempts --break-system-packages. publish.mjs is explicitly documented but only caller-gated; not invoked. |
| Independent baseline and focused bundled-loader review | not recorded | Needs follow-up | All first-party executable source and workflow cards reviewed. No malware evidence found. Bundle partial only. Original candidates retained pending reconciliation; broad judge roots and symlink following do not establish attacker privilege gain. Unpinned installs, caller-only publication consent and unknown anonymous-key server authority recorded. |

## Open Questions And Follow Up

- No antivirus signature scan or dynamic malware detonation performed; no installed ClamAV found.
- Future dependency downloads and updates require separate trust review.
- No runtime reproduction during source-only audit.
- Sensitive loaders and whole-file indicators reviewed; not a full semantic audit or authenticated upstream build comparison.
  - Follow-up prompt: Review deferred unit gap-1 and close its stated proof gap. Paths: harness/assets/three-bundle.js.
- Binary assets not deeply audited; example GLB metadata has no external URIs.
  - Follow-up prompt: Review deferred unit gap-2 and close its stated proof gap. Paths: assets/hero.png, assets/silhouettes.png, example/wolf.glb, example/wolf_beauty.png, example/wolf_silhouette.png, example/wolf_thumb24.png.
- Release history not reviewed end-to-end; current executable implementation is authoritative.
  - Follow-up prompt: Review deferred unit gap-3 and close its stated proof gap. Paths: CHANGELOG.md.
- Parent validating dependency default against official API documentation.
  - Follow-up prompt: Review deferred unit chromium-sandbox-default and close its stated proof gap.
- Independent bundled-loader investigation still running.
  - Follow-up prompt: Review deferred unit external-model-uris and close its stated proof gap.
