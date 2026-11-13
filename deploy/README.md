# Artea web deployment

The web build is served by Caddy over HTTPS and the Flask API is exposed under
the same origin at `/api`. This is required for browser mixed-content rules and
for Godot's cross-origin-isolated WebAssembly runtime.

1. Build the game with `./build_web.sh --build`.
2. Copy `build/web/` to `/srv/artea/web/` on the host.
3. Install Caddy and copy `deploy/Caddyfile` to `/etc/caddy/Caddyfile`.
4. Set `ARTEA_DOMAIN` for the Caddy service to the public hostname.
5. Install `server/flaskapp.service`, and put production secrets in
   `/home/ubuntu/server/.env`:

   ```ini
   ARTEA_JWT_SECRET_KEY=a-long-random-production-secret
   OPENROUTER_API_KEY=optional-key-for-web-chat
   ARTEA_WEB_ALLOWED_ORIGINS=https://your-domain.example
   ```

6. Restart `flaskapp` and Caddy. Verify `/`, `/api/`, `index.pck`, and
   `index.wasm` all return 200. Caddy obtains and renews TLS automatically once
   the hostname points at the server and ports 80/443 are open.
