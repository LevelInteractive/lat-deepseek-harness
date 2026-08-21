# Level Agency deployment — DeepSeek Harness (`dsh`)

Level's hosted deployment of DeepSeek's open-source agent harness
([`deepseek-ai/deepseek-harness`](https://github.com/deepseek-ai/deepseek-harness),
MIT). This repo is the Level fork `LevelInteractive/lat-deepseek-harness`,
consumed as a submodule at `services/deepseek-harness` in
`LevelInteractive/level-agency-tools` and deployed on Dokploy at
**https://deepseek-harness.dash.level.agency**.

Only two things are Level-specific; everything else is upstream, tracked via the
fork so we can pin and re-sync:

- **`Dockerfile`** — installs the pinned published CLI (`npm i -g @deepseek-ai/dsh@<ver>`)
  and runs `deploy/entrypoint.sh`. It does **not** build the upstream monorepo.
- **`deploy/`** — the hosting overlay (`entrypoint.sh` + `host.patch.yml`).

## Why this needs an overlay

`dsh web` is a **local-first, single-user, no-auth** harness:

1. It refuses `--host 0.0.0.0` on purpose — the web UI is remote-code-execution
   capable. We bypass the CLI guard by overriding the `webserver` plugin config
   directly (`deploy/host.patch.yml`) and put **Traefik forward-auth (Google
   SSO)** in front of the subdomain. dsh itself adds no authentication.
2. Its credential/settings plane is **loopback-only** ("until a real
   authentication layer exists"), so hosted users can't set the model key in the
   UI. We pre-bake it: the **`DEEPSEEK_API_KEY` container env** is dsh's
   highest-precedence credential source (its credentials-local layering treats a
   container `-e` as explicit run intent). The default `web` profile ships the
   `deepseek-official` provider, so setting the key is all that's needed.
3. It's **one shared workspace/instance** for everyone who can reach it. Fine as
   an internal eval/demo tool; it is not multi-tenant.

## State

`DSH_HOME=/data` holds credentials, the SQLite session store, and the agent
workspace. It is a persistent Dokploy volume so state survives redeploys.

## Deploy

Provisioned + operated from the monorepo:
`scripts/dokploy/deploy-deepseek-harness.sh` (Dokploy project/app, single app,
volume, domain, env) and `scripts/dokploy/gen-deepseek-harness-forward-auth.py`
(the Traefik forward-auth wiring). Env/secrets live in the monorepo root
`.env.dokploy.local` under the `DEEPSEEK_HARNESS_*` prefix and are assembled in
`scripts/dokploy/_env-block.sh` (`deepseek-harness` arm).

## Updating dsh

Bump `DSH_VERSION` in the `Dockerfile` and redeploy (`application.deploy` with
`cleanCache,forcePull`). Re-sync fork ↔ upstream separately when you want new
upstream commits; the overlay files (`Dockerfile`, `deploy/`) are ours and
should survive the merge.
