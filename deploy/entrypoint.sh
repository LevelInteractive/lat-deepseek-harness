#!/usr/bin/env sh
# Level Agency container entrypoint for DeepSeek Harness (`dsh web`).
#
# Binds 0.0.0.0:3080 (via deploy/host.patch.yml) and declares the public
# authority to the /api browser-trust fence via --trusted-host. Network auth is
# handled OUTSIDE the container by Traefik forward-auth (Google SSO). The
# DeepSeek model key is read from the DEEPSEEK_API_KEY env var (dsh's
# highest-precedence credential source).
set -eu

# Public host(s) the deployment is reached by. Space-separated; the default is
# the production subdomain. Override with DSH_TRUSTED_HOSTS if the domain changes.
TRUSTED_HOSTS="${DSH_TRUSTED_HOSTS:-deepseek-harness.dash.level.agency}"

export DSH_HOME="${DSH_HOME:-/data}"
mkdir -p "$DSH_HOME"

# Build the repeatable --trusted-host argument list.
set -- web --no-open --patch /app/deploy/host.patch.yml
for h in $TRUSTED_HOSTS; do
  set -- "$@" --trusted-host "$h"
done

echo "[entrypoint] dsh $(dsh --version 2>/dev/null | head -n1 || echo '?') | DSH_HOME=$DSH_HOME | bind=0.0.0.0:3080 | trusted=[$TRUSTED_HOSTS]"
if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
  echo "[entrypoint] WARNING: DEEPSEEK_API_KEY is not set — the web UI will serve but agent runs will fail until a key is provided." >&2
fi

exec dsh "$@"
