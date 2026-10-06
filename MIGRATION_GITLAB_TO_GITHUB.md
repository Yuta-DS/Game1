# Migrating This Project from GitLab to GitHub

Maintainer/instructor runbook for moving the project's canonical home from
GitLab to GitHub.

|          |                                                                             |
| -------- | --------------------------------------------------------------------------- |
| From     | https://gitlab.westernsydney.edu.au/capstone/spring-2026/project/S2603      |
| To       | https://github.com/wsu-comp3018/COMP3018-S26-G3                             |
| Audience | Maintainers. **Students** should read [SWITCHING_TO_GITHUB.md](./SWITCHING_TO_GITHUB.md) instead. |

Git history, branches and tags move with a mirror push. Everything else
(issues, merge requests, wiki, permissions, CI, settings) does **not**, and
has to be handled separately. Steps 2 and 4–6 cover those.

## 1. Pre-migration checklist

Facts about this repository, checked before migrating:

- **No GitLab CI.** There is no `.gitlab-ci.yml`, so there is no pipeline to
  port (see step 6 if one is added later).
- **Git LFS is in use** (`.gitattributes`; `.gguf` models and native plugin
  binaries). LFS objects are stored separately from the git history and must
  be pushed explicitly. The `.git` directory is roughly 1 GB.
- **One hard-coded GitLab URL** in tracked files: the compare/repository link
  at `CHANGELOG.md:145`.

Before you start, confirm:

- [ ] You have admin/owner rights on both the GitLab project and the GitHub
      organisation.
- [ ] Git LFS is installed locally (`git lfs version`).
- [ ] The GitHub organisation has enough **LFS storage and bandwidth** for
      the repo's LFS objects (`git lfs ls-files -s` on a full clone shows
      sizes). GitHub's free quota is small; buy a data pack if needed.
- [ ] No single non-LFS file exceeds GitHub's **100 MB** push limit. Find
      offenders with:
      ```
      git rev-list --objects --all \
        | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' \
        | awk '$1=="blob" && $3 > 100*1024*1024'
      ```
      Fix by moving those files into LFS (`git lfs migrate import`) *before*
      pushing. That rewrites history, so do it once, on the mirror, and tell
      everyone to re-clone.
- [ ] Inventory what git does not carry: open issues, merge requests, wiki,
      milestones/labels, releases, CI/CD variables, deploy keys, webhooks,
      protected branches, member list and roles.

## 2. Create the empty GitHub repository

In the GitHub UI (or `gh repo create`):

- Owner: `wsu-comp3018`, name: `COMP3018-S26-G3`.
- **Do not** initialise with a README, `.gitignore` or licence — the
  repository must be empty so the mirror push is a clean fast-forward.
- Visibility: match GitLab (private for student projects).

```
gh repo create wsu-comp3018/COMP3018-S26-G3 --private
```

## 3. Mirror the repository (history, branches, tags, LFS)

Work in a **fresh mirror clone**, not your day-to-day working copy.

```
git clone --mirror https://gitlab.westernsydney.edu.au/capstone/spring-2026/project/S2603 s2603-mirror
cd s2603-mirror

# Get every LFS object for every ref, not just the default branch
git lfs fetch --all origin

# Push git history (all branches and tags)
git push --mirror https://github.com/wsu-comp3018/COMP3018-S26-G3.git

# Push LFS objects
git lfs push --all https://github.com/wsu-comp3018/COMP3018-S26-G3.git
```

Notes:

- `--mirror` also pushes GitLab-internal refs such as `refs/merge-requests/*`.
  GitHub rejects or ignores some of these. If the push fails on them, push
  only branches and tags instead:
  ```
  git push https://github.com/wsu-comp3018/COMP3018-S26-G3.git --all
  git push https://github.com/wsu-comp3018/COMP3018-S26-G3.git --tags
  ```
- Push LFS **before or right after** the git refs. If a branch lands without
  its LFS objects, checkouts fail with "object not found" smudge errors.
- Large first pushes can time out over HTTPS. Retry, or use SSH
  (`git@github.com:wsu-comp3018/COMP3018-S26-G3.git`).

## 4. Migrate issues, merge requests and the wiki

Git does not carry these. Options, in order of effort:

1. **Don't migrate closed items.** For a course project, carrying over only
   *open* issues by hand or by script is usually enough. Link back to
   GitLab for history.
2. **GitHub Importer / a migration tool** (check the GitHub UI and the
   GitHub docs for what's currently offered for GitLab sources) — expect
   reduced fidelity: authors, timestamps and comments are often flattened.
3. **Script it** with the GitLab API (`GET /projects/:id/issues`) and
   `gh issue create`, recording the original GitLab URL and author in the
   body.

Merge requests cannot be recreated as pull requests with their history.
The merged code is already in the branches; record any still-open MRs by
pushing their source branches (step 3 does this) and opening fresh PRs.

Wiki: GitLab wikis are separate git repos
(`<project-url>.wiki.git`). Clone it and push it to
`https://github.com/wsu-comp3018/COMP3018-S26-G3.wiki.git` after enabling
the wiki on GitHub and creating one initial page in the UI.

Tags `v1.0` and `v2.0` arrive with step 3. Recreate GitLab releases as
GitHub Releases from those tags if release notes matter
(`gh release create v2.0 --notes-file ...`; `CHANGELOG.md` has the text).

## 5. Rebuild access and settings

None of these migrate automatically. Recreate them on GitHub:

- **Members and roles** — add students/staff to the organisation and the
  repo, or via a GitHub team, with the equivalent of their GitLab roles.
- **Default branch** — `main`.
- **Branch protection / rulesets on `main`** — require pull requests and
  reviews if GitLab enforced them.
- **Secrets and variables** — GitLab CI/CD variables become GitHub Actions
  secrets. This project has none in the repo, but check the GitLab
  settings page in case.
- **Webhooks and deploy keys** — re-add any that external services rely
  on. The Flask server in `server/` is deployed via `flaskapp.service`;
  if that host pulls from GitLab, repoint its remote (step 8).
- **Issue tracker config** — agent tooling in this repo is already
  configured to use GitHub Issues (see the `agent-skills` config commit).

## 6. CI/CD

There is no pipeline today. If one is added later, the rough mapping from
GitLab CI to GitHub Actions is:

| GitLab CI (`.gitlab-ci.yml`)  | GitHub Actions (`.github/workflows/*.yml`) |
| ----------------------------- | ------------------------------------------ |
| `stages:` / `stage:`          | `jobs:` with `needs:`                      |
| `script:`                     | `steps:` with `run:`                       |
| `image:`                      | `runs-on:` plus `container:` if needed     |
| `variables:`                  | `env:`; secrets in repo settings           |
| `rules:` / `only:` / `except:`| `on:` triggers and `if:` conditions        |
| `artifacts:`                  | `actions/upload-artifact`                  |
| `cache:`                      | `actions/cache`                            |

When adding a workflow that checks out this repo, enable LFS
(`actions/checkout` with `lfs: true`), or the `.gguf` models and plugin
binaries will be pointer files. Also watch LFS bandwidth: every CI checkout
with LFS counts against the quota.

## 7. Update references inside the repository

The only tracked GitLab URLs are in `CHANGELOG.md` (line 145):

```
[Compare v1.0...v2.0](https://gitlab.westernsydney.edu.au/.../-/compare/v1.0...v2.0) · [Repository](https://gitlab.westernsydney.edu.au/...)
```

GitHub's equivalent compare URL is:

```
https://github.com/wsu-comp3018/COMP3018-S26-G3/compare/v1.0...v2.0
```

Re-check for stragglers after editing:

```
grep -rIn -i gitlab . --exclude-dir=.git
```

The only expected hits afterwards are this document and
`SWITCHING_TO_GITHUB.md`.

## 8. Cutover

1. **Announce** a freeze time. Ask everyone to push outstanding work to
   GitLab beforehand.
2. **Freeze GitLab**: Settings → General → set the project to archived
   (read-only), or restrict push access to maintainers.
3. **Final sync**: repeat step 3 from the existing mirror
   (`git remote update` inside `s2603-mirror`, then the two pushes) so
   GitHub has the last commits.
4. **Verify parity** (all should match):
   ```
   git ls-remote https://gitlab.westernsydney.edu.au/capstone/spring-2026/project/S2603 refs/heads/main
   git ls-remote https://github.com/wsu-comp3018/COMP3018-S26-G3.git refs/heads/main

   git ls-remote --heads --tags <each-url> | wc -l     # branch + tag counts
   ```
   Then do a throw-away fresh clone from GitHub and check LFS:
   ```
   git clone https://github.com/wsu-comp3018/COMP3018-S26-G3.git verify && cd verify
   git lfs install && git lfs pull
   git lfs ls-files | head
   ```
   Open `artea/` in Godot 4.4 to confirm the project loads and the models
   and plugin binaries are real files, not LFS pointers.
5. **Point people at the new home**: send students
   [SWITCHING_TO_GITHUB.md](./SWITCHING_TO_GITHUB.md) (repoint `origin`, and
   set up a Personal Access Token or SSH key).
6. **Repoint any server deployment** that pulls from GitLab:
   ```
   git remote set-url origin https://github.com/wsu-comp3018/COMP3018-S26-G3.git
   ```
   Use a read-only deploy key or token, not a personal credential.

## 9. Keeping GitLab as a backup

The current local layout in the maintainer clone is:

```
gitlab  https://gitlab.westernsydney.edu.au/capstone/spring-2026/project/S2603
origin  https://github.com/wsu-comp3018/COMP3018-S26-G3.git
```

That is, GitHub is `origin` and GitLab is a secondary remote named
`gitlab`. GitLab is only a backup once it stops receiving pushes, so pick
one:

- **Archive it** (read-only) and treat it as a historical snapshot. Simplest.
- **Keep it in sync** by pushing to both:
  ```
  git remote set-url --add --push origin https://github.com/wsu-comp3018/COMP3018-S26-G3.git
  git remote set-url --add --push origin https://gitlab.westernsydney.edu.au/capstone/spring-2026/project/S2603
  ```
  (Both `--push` URLs must be added; adding only one replaces the default.)
  Remember to push LFS objects to both as well.

## 10. Troubleshooting and rollback

| Symptom | Likely cause / fix |
| ------- | ------------------ |
| `remote: error: File ... is 1xx MB; this exceeds GitHub's file size limit of 100 MB` | A large file is in history outside LFS. `git lfs migrate import --include=...` on the mirror, then push again (rewrites history; everyone must re-clone). |
| `Object does not exist on the server` / smudge error on checkout | LFS objects were not pushed. Run `git lfs fetch --all` on the mirror and `git lfs push --all <github-url>`. |
| `batch response: This repository is over its data quota` | GitHub LFS storage/bandwidth exhausted. Buy a data pack or wait for the monthly reset. |
| `refusing to update ... refs/merge-requests/...` on `--mirror` push | GitLab-internal refs. Push `--all` and `--tags` instead (step 3). |
| Students get `Authentication failed` | GitHub does not accept account passwords over HTTPS. See the Authentication section of `SWITCHING_TO_GITHUB.md`. |
| A student's `main` has diverged after the move | They committed to GitLab after the freeze. Have them `git fetch origin`, then rebase or merge their work onto `origin/main`. |

**Rollback:** nothing in this process modifies GitLab except the final
archive step, so to abort, un-archive the GitLab project and tell students
to keep using it. Delete or make the GitHub repo private until the migration
is retried.
