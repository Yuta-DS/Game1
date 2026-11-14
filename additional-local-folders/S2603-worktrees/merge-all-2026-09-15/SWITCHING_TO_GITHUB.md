# Switching Your Local Clone to GitHub

This project's canonical home has moved from GitLab to GitHub:

**New home:** https://github.com/wsu-comp3018/COMP3018-S26-G3

The old GitLab project is kept around as a secondary/backup remote — it
isn't going away, but **GitHub is where you should push and pull from now
on.**

## If you already have a local clone (most people)

Run these from inside your existing clone:

```
git remote rename origin gitlab
git remote add origin https://github.com/wsu-comp3018/COMP3018-S26-G3.git
git fetch origin
git branch -u origin/main main
```

That's it. This doesn't touch any of your local work, branches, or commit
history — all existing branches and tags are already mirrored on GitHub, so
`git fetch origin` will just confirm everything's there.

Check it worked:

```
git remote -v
```

You should see `origin` pointing at the GitHub URL and `gitlab` pointing at
the old GitLab URL.

## If you're cloning fresh

Just clone the new GitHub URL directly:

```
git clone https://github.com/wsu-comp3018/COMP3018-S26-G3.git
```

You'll still need Git LFS set up per the main `README.md`:

```
git lfs install
git lfs pull
```

## Authentication

GitHub stopped accepting your GitHub password over HTTPS years ago, so your
GitLab login won't carry over. The first time you push or pull from GitHub
you'll need one of:

- **A Personal Access Token** — GitHub → Settings → Developer settings →
  Personal access tokens. Use it in place of a password when Git prompts
  you; most credential managers will cache it after the first successful
  auth so you won't be asked again. See GitHub's own docs on [creating a
  personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).
- **An SSH key** — add one to your GitHub account and use the `git@github.com:...`
  clone URL instead of HTTPS. See GitHub's docs on [connecting with SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh).

Either works fine — pick whichever you're already comfortable with.

## Going forward

Push and pull against `origin` (GitHub) as normal:

```
git push origin <branch>
git pull origin <branch>
```

The `gitlab` remote still works if you ever need it
(`git push gitlab <branch>` / `git fetch gitlab`), but it's a backup now,
not the primary.
