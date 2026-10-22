# Hosting Artéa

How to put Artéa on the internet on your own server, so players can open it in
a web browser at your own address (for example `https://play.example.com`),
create accounts and save their artwork.

You'll need about an hour the first time. You don't need to know how to
program: the steps are clicks on the AWS website and two commands to paste.

**What you'll end up with:** one small Ubuntu Linux server on Amazon Web
Services (AWS) Lightsail that runs the whole game: the game files, the player
accounts and the uploaded artwork. Nothing else to set up or pay for.

**What you need:**

- `artea-release.tar` from the development team (about 380 MB). This is the
  game plus the server program, in one file.
- An AWS account (a credit card is needed to sign up).
- A domain name for the address players will use, e.g. `play.example.com`.
  The game only works over a secure (`https://`) address, and that needs a
  domain.
- Optional: an OpenRouter API key for the game's AI features. Without one the
  game uses its built-in offline replies.

**What it costs (approximate, check current AWS pricing):**

| Item | Cost |
|---|---|
| Lightsail server, 2 GB plan (includes 1.5 TB of data transfer a month, roughly 4,000 first-time game downloads) | about US$12 a month |
| Domain name | about US$15 a year |
| Automatic daily backups (snapshots) | a few dollars a month |
| AI features (optional) | pay-as-you-go with OpenRouter; set a spending limit |

---

## Part 1: Set up the server (once)

### 1. Create the server

1. Sign in to the AWS console and open **Lightsail**
   (<https://lightsail.aws.amazon.com>).
2. Choose **Create instance**.
3. **Region:** Sydney (`ap-southeast-2`), or whichever is closest to your
   players.
4. **Platform:** Linux/Unix. **Blueprint:** *OS Only* → **Ubuntu 24.04 LTS**.
5. **Plan:** the **2 GB RAM** plan. (Smaller plans may run out of memory.)
6. Give it a name, e.g. `artea`, and choose **Create instance**. Wait until it
   says *Running*.

### 2. Give it a fixed address and open the secure web port

Open the instance and go to its **Networking** tab:

1. Under **IPv4 networking**, choose **Attach static IP** (it's free while
   attached). Note the address, e.g. `3.105.12.34`. This is your
   **SERVER_IP**. Without a static IP the address would change whenever the
   server restarts.
2. Under **IPv4 Firewall**, choose **Add rule** → **HTTPS** (port 443) →
   **Create**. SSH (22) and HTTP (80) are already open; keep them.

### 3. Point your domain at the server

Buy a domain if you don't have one (Amazon Route 53, or any domain company).
In its DNS settings, add an **A record**:

| Name | Type | Value |
|---|---|---|
| `play` (for `play.example.com`) or `@` (for `example.com` itself) | A | your SERVER_IP |

It can take from a few minutes to an hour to start working. You can check from
a Windows Command Prompt with `nslookup play.example.com`: when it shows your
SERVER_IP, it's ready.

### 4. Upload the game to the server

1. In Lightsail, go to **Account** (top right) → **SSH keys** and download the
   **default key** for your region. It's a file like
   `LightsailDefaultKey-ap-southeast-2.pem`. Keep it private: it opens your
   server.
2. Open **PowerShell** (Windows) or **Terminal** (Mac) and run, with your own
   file locations and SERVER_IP:

   ```powershell
   scp -i "C:\Users\you\Downloads\LightsailDefaultKey-ap-southeast-2.pem" "C:\Users\you\Downloads\artea-release.tar" ubuntu@SERVER_IP:
   ```

   Type `yes` if it asks whether to trust the server. The upload takes a few
   minutes. (On a Mac, run `chmod 400` on the key file first if it complains.
   On Windows, see *Troubleshooting* if it says the key is unprotected.)

### 5. Install

In Lightsail, open the instance and choose **Connect using SSH**. A terminal
opens in your browser. Paste this line, with your own domain and email address
(the email is only used for security-certificate notices):

```bash
rm -rf artea-release && tar -xf artea-release.tar && bash artea-release/server/ec2/install.sh play.example.com you@example.com
```

It takes a few minutes and finishes with `Done: https://play.example.com/`.

### 6. Check it

Open `https://play.example.com` in Chrome. The first load downloads the game
(about 170 MB), which can take a minute. Create an account, log in, and try
uploading an artwork.

### 7. Turn on backups

On the instance's **Snapshots** tab, turn on **Automatic snapshots**. A
snapshot is a copy of the whole server, including player accounts and artwork,
that you can restore if something goes wrong.

---

## Part 2: Running it

### Updating to a new version

When the team sends a new `artea-release.tar`: take a manual snapshot first
(Snapshots tab), then do step 4 (upload) and step 5 (the same install line)
again. Player accounts, artwork and settings are kept. To see which version is
live, open `https://play.example.com/VERSION.txt`.

### Turning on the AI features

In the browser terminal (**Connect using SSH**):

```bash
nano ~/server/.env
```

Find the line `#OPENROUTER_API_KEY=`, delete the `#`, and paste your key after
the `=`. Save with **Ctrl+O**, **Enter**, then exit with **Ctrl+X**. Then:

```bash
sudo systemctl restart flaskapp
```

Set a monthly spending limit in your OpenRouter account. Only signed-in players
can use the AI.

### Stopping and starting

You can stop the instance in Lightsail when nobody needs it; the game starts
again by itself when you start the instance. Note that a stopped Lightsail
instance is still billed; to stop paying, delete it (after taking a snapshot
if you want to come back).

### Players' data

Player accounts and uploaded artwork are stored on this server
(`~/server/database.db` and `~/server/uploads/`). Decide how long you keep
them and tell playtesters. Deleting the instance and its snapshots deletes
everything.

### Setting a billing alert

In the AWS console, open **Billing and Cost Management** → **Budgets** and
create a monthly budget with an email alert, so you hear about any unexpected
cost.

---

## Troubleshooting

**The install stops at "HTTPS isn't set up yet".** The domain doesn't point
at the server yet, or port 443 isn't open. Check step 2 (firewall) and step 3
(`nslookup` shows your SERVER_IP), wait a little, and run the install line
again.

**The site doesn't open at all.** Check the instance is running, and that the
domain's A record has the static IP (step 2), not an old address.

**The game loads but signing up or logging in fails.** In the browser
terminal, run `sudo systemctl status flaskapp` (it should say *active
(running)*) and `sudo journalctl -u flaskapp -n 50` to see recent errors. Send
those to whoever supports the game. `sudo systemctl restart flaskapp`
restarts it.

**Windows `scp` says "UNPROTECTED PRIVATE KEY FILE".** In PowerShell, in the
folder with the key:

```powershell
icacls .\LightsailDefaultKey-ap-southeast-2.pem /inheritance:r /grant:r "$($env:USERNAME):R"
```

**The server seems full.** `df -h` shows free disk space. Old snapshots are
managed on the Snapshots tab.

---

## For developers: making a release

From the repository root in Git Bash, on the branch you want to release, with
your changes committed (the server code goes in as committed):

```bash
./web rebuild          # export the game; stop it with Ctrl+C once it says "Serving"
./web verify           # check the build is playable
server/ec2/release.sh  # writes artea/builds/artea-release.tar
```

Send the client `artea-release.tar` (it's too big for email; use a shared
drive). `install.sh` works on any Ubuntu 24.04 server where the login account
has sudo and ports 80 and 443 are open, so the same file also installs on an
EC2 instance. After installing, `./web verify --url https://YOUR_DOMAIN/` runs
the full playability check against the live site.

How it fits together: nginx serves the game from `/var/www/artea` and passes
`/api/...` to the Flask server (gunicorn, `flaskapp.service`) in `~/server`,
because the game calls `location.origin + "/api"`
(`artea/scripts/API_Manager.gd`). `install.sh` writes the secrets to
`~/server/.env` (git-ignored, generated with `openssl rand -hex 32`) with
`BEHIND_PROXY=1`, so Flask sees each visitor's real address, and signed-out
visitors can't reach the AI.
