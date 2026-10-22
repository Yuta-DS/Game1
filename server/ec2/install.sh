#!/usr/bin/env bash
# Installs Artéa on an Ubuntu server from an unpacked release (release.sh), or
# updates it to a newer one: the same command both times.
#
#   tar -xf artea-release.tar
#   bash artea-release/server/ec2/install.sh play.example.com you@example.com
#
# nginx serves the game from /var/www/artea and passes /api/ to the Flask
# server (gunicorn, flaskapp.service) in ~/server; certbot adds HTTPS. Player
# accounts (database.db), uploaded artwork (uploads/) and the secrets (.env) in
# ~/server are made once and never replaced. See server/ec2/README.md.
set -euo pipefail
DOMAIN=${1:?usage: install.sh DOMAIN EMAIL}
EMAIL=${2:?usage: install.sh DOMAIN EMAIL}
RELEASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER="${HOME}/server"
[[ -d "${RELEASE}/www" ]] || { echo "Run this from an unpacked artea-release.tar" >&2; exit 1; }
command -v apt-get > /dev/null || { echo "This needs Ubuntu (24.04 LTS)" >&2; exit 1; }

echo "== Installing system packages"
sudo apt-get update -q
sudo apt-get install -y -q nginx python3-venv certbot python3-certbot-nginx

echo "== Installing the server in ${SERVER}"
mkdir -p "${SERVER}"
cp -r "${RELEASE}/server/." "${SERVER}/"
python3 -m venv "${SERVER}/venv"
"${SERVER}/venv/bin/pip" install --quiet -r "${SERVER}/requirements.txt"
# Secrets are made once and kept: a new JWT_SECRET_KEY signs every player out.
if [[ ! -f "${SERVER}/.env" ]]; then
	(umask 077 && cat > "${SERVER}/.env" <<EOF
JWT_SECRET_KEY=$(openssl rand -hex 32)
ADMIN_RESET_KEY=$(openssl rand -hex 32)
CORS_ALLOWED_ORIGINS=https://${DOMAIN}
BEHIND_PROXY=1
# AI features (optional; without a key the game uses its offline replies).
# Set a spending limit with the provider. After editing:
#   sudo systemctl restart flaskapp
#OPENROUTER_API_KEY=
EOF
	)
	echo "Wrote ${SERVER}/.env with new secrets."
fi
# Create the database tables here, once: importing server.py does it, and
# gunicorn's three workers each doing it at once on a fresh SQLite file can
# collide and stop the service.
(cd "${SERVER}" && set -a && . ./.env && set +a && venv/bin/python -c "import server")
# The unit as committed names user ubuntu in /home/ubuntu; fit it to whoever
# is installing.
sed -e "s|/home/ubuntu|${HOME}|g" -e "s|^User=ubuntu$|User=$(id -un)|" "${SERVER}/flaskapp.service" \
	| sudo tee /etc/systemd/system/flaskapp.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable flaskapp
sudo systemctl restart flaskapp

echo "== Installing the game in /var/www/artea"
# Copied beside the live one and swapped in, so players never load a
# half-copied release.
sudo rm -rf /var/www/artea.new /var/www/artea.old
sudo cp -r "${RELEASE}/www" /var/www/artea.new
sudo cp "${RELEASE}/VERSION" /var/www/artea.new/VERSION.txt
sudo mkdir -p /var/www/artea
sudo mv /var/www/artea /var/www/artea.old
sudo mv /var/www/artea.new /var/www/artea
sudo rm -rf /var/www/artea.old

echo "== Configuring nginx for ${DOMAIN}"
sed "s/__DOMAIN__/${DOMAIN}/" "${SERVER}/ec2/nginx-artea.conf" \
	| sudo tee /etc/nginx/sites-available/artea > /dev/null
sudo ln -sf /etc/nginx/sites-available/artea /etc/nginx/sites-enabled/artea
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx

echo "== Turning on HTTPS"
# Renewed automatically by certbot's timer. On an update this puts the
# existing certificate back into the freshly written site file.
if ! sudo certbot --nginx -d "${DOMAIN}" -m "${EMAIL}" --agree-tos --non-interactive \
		--redirect --keep-until-expiring; then
	echo "HTTPS isn't set up yet. Check ${DOMAIN} points at this server's IP, and" >&2
	echo "that port 443 is open in the firewall, then run this command again." >&2
	exit 1
fi

echo
echo "Done: https://${DOMAIN}/"
cat "${RELEASE}/VERSION"
