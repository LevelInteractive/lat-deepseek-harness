# Level Agency deployment image for DeepSeek Harness (`dsh`) web UI.
#
# We do NOT build the upstream monorepo. DeepSeek publishes the CLI on npm as
# `@deepseek-ai/dsh`, so this image just installs the pinned CLI and runs
# `dsh web`. The fork's own source tree is ignored (see .dockerignore); only
# ./deploy/ is copied in.
#
# Hosting model (see LEVEL_DEPLOY.md): `dsh web` is a LOCAL-first, single-user,
# no-auth agent harness. Upstream deliberately blocks `--host 0.0.0.0` (the web
# UI exposes remote code execution). We bypass that guard by overriding the
# webserver plugin config directly (deploy/host.patch.yml) and put Level's
# Traefik forward-auth (Google SSO) in front of the public subdomain. The app's
# own credential/settings plane stays loopback-only upstream, so the model key
# is pre-baked via the DEEPSEEK_API_KEY container env (highest-precedence
# credential source per dsh's credentials-local layering).

FROM node:22-bookworm-slim

# Runtime tools dsh agents may shell out to, plus a minimal node-gyp toolchain
# as insurance for any transitive native dependency (the dsh tree is mostly
# pure JS; g++/make/python3 only matter if a prebuild is missing). dumb-init
# gives us correct PID-1 signal handling for the long-lived server.
RUN apt-get update && apt-get install -y --no-install-recommends \
      git python3 make g++ pkg-config ca-certificates dumb-init tini \
    && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production \
    DSH_HOME=/data \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false

# Pin the CLI version. Bump this ARG (and rebuild) to take a new upstream release.
ARG DSH_VERSION=0.1.1-rc.2
RUN npm install -g "@deepseek-ai/dsh@${DSH_VERSION}" && npm cache clean --force

WORKDIR /app
COPY deploy/ /app/deploy/
RUN chmod +x /app/deploy/entrypoint.sh

# DSH_HOME holds credentials, the SQLite session store, and the agent workspace.
# Mounted as a persistent Dokploy volume so state survives redeploys.
RUN mkdir -p /data
VOLUME ["/data"]

EXPOSE 3080
ENTRYPOINT ["dumb-init", "--"]
CMD ["/app/deploy/entrypoint.sh"]
