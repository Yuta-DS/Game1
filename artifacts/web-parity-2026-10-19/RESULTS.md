# Artéa Web and desktop result views

These screenshots show the rebuilt local Web export at `localhost:8801` unless
marked **desktop**. Browser views were captured from the rendered game, not
from source scene previews.

| Result | Screenshot |
| --- | --- |
| Web start screen after `./web rebuild` | [00-web-start-after-rebuild.jpg](00-web-start-after-rebuild.jpg) |
| Successful local Web login | [01-web-login-hub.jpg](01-web-login-hub.jpg) |
| Successful local Web login after rebuild | [02-web-login-after-rebuild.jpg](02-web-login-after-rebuild.jpg) |
| Successful login on the published site | [11-public-login-success.jpg](11-public-login-success.jpg) |
| Rebuilt hub with fountain and grass assets included | [12-web-hub-assets-fixed.jpg](12-web-hub-assets-fixed.jpg) |
| Current `main` PR branch Web start screen | [13-pr75-web-start.png](13-pr75-web-start.png) |
| Current `main` PR branch playable hub | [14-pr75-web-hub.png](14-pr75-web-hub.png) |
| Current `main` PR branch account login to the ready hub | [15-pr75-account-login-hub.png](15-pr75-account-login-hub.png) |
| Published site account login to the ready hub | [16-published-account-login.png](16-published-account-login.png) |
| World One gameplay | [03-world-one-web.jpg](03-world-one-web.jpg) |
| Gallery gameplay | [04-gallery-web.jpg](04-gallery-web.jpg) |
| Creator paving, table, and studio from verification camera | [05-creator-floor-web.jpg](05-creator-floor-web.jpg) |
| Heart Melody ground and teleport from verification camera | [06-heart-melody-web.jpg](06-heart-melody-web.jpg) |
| Island Two gate and barrier | [08-island-two-gate-web.jpg](08-island-two-gate-web.jpg) |
| Island Three gate and frame | [09-island-three-gate-web.jpg](09-island-three-gate-web.jpg) |
| Bridge approach portal position | [10-bridge-portal-web.jpg](10-bridge-portal-web.jpg) |
| World One Island Two, **desktop** capture | [02-island-two-evidence-court.png](../../artea/artifacts/world_one_matched_player_views/02_island_two_evidence_court.png) |
| World One Island Three, **desktop** capture | [03-island-three-stormworks-arrival.png](../../artea/artifacts/world_one_matched_player_views/03_island_three_stormworks_arrival.png) |
| Gallery entry, **desktop** capture | [art-castle-galaxy-transit.png](../../artea/artifacts/art_castle_galaxy_transit.png) |

Local Web checks passed for login, gallery entry, Creator ground contact,
Heart Melody walking and teleport, and World One gates, ground, save state,
and three portal trips using real browser Q input. The desktop World One
capture and the desktop Godot API login check passed. The Web smoke test
reported a playable hub with no fatal resource errors. It measured 197.2 MiB
transferred and 22.3 seconds to the hub on a cold local visit; a repeat visit
using production cache headers transferred 3,069 bytes.

The published site at `https://artea-web.vercel.app` now uses the Flask API at
`https://artea-api.vercel.app` with a Neon Postgres database. A test account
registered and logged in through the hosted API, and the published game login
reached the playable hub. Its generated pack manifests matched the local Web
export after deployment. Hosted accounts are separate from local SQLite
accounts until account data is explicitly migrated.

The final published hub produced zero browser error log entries during the
login and hub load check. Its core pack includes the fountain stone, animated
water, and grass shader required by the desktop hub.

A [draft PR to `main`](https://github.com/wsu-comp3018/COMP3018-S26-G3/pull/75)
contains the hosted account API and local Web launcher integration adapted to
the current `main` branch. Its Flask test client passed register, login, CORS,
and artwork upload/list/download. A fresh Godot Web export from that exact
branch passed. Its gameplay smoke check began building the hub in 14.6 seconds
after transferring 296.9 MiB, moved the player, entered the Crown of Life story,
Art Castle, Mind Spark, Heart Melody, and Creator's Light, and returned to
the hub from each with no fatal resource errors. A second cold browser run
stalled after the 250 MB core download reached 100%, though two later cold
starts loaded normally. An account login through the exact PR Web export passed
and reached the rendered hub in 20.9 seconds, transferring 296.9 MiB to that
point with zero failed requests. Windows and Linux runs remain unverified.
The published deployment was built from the local Web parity branch, and its
cold account login check transferred 137.1 MiB and reached the ready hub in
66.5 seconds with zero failed requests.
