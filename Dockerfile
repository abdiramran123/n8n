# syntax = docker/dockerfile:1

# n8n officially supports Node 22 LTS
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-slim AS base

LABEL fly_launch_runtime="Node.js"

WORKDIR /app

# Use the exact pnpm version pinned in package.json ("packageManager" field)
# instead of pnpm@latest, so it matches the lockfile.
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
RUN npm install -g corepack@latest && corepack enable


# Throw-away build stage
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential node-gyp pkg-config python-is-python3 git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy the whole monorepo BEFORE installing. pnpm-workspace.yaml (which holds
# the "catalogs" config) and every packages/*/package.json must be present,
# otherwise pnpm reports ERR_PNPM_LOCKFILE_CONFIG_MISMATCH.
COPY . .

RUN pnpm install --frozen-lockfile --prod=false

# Build application
RUN pnpm run build


# Final stage for app image
FROM base

ENV NODE_ENV="production" \
    N8N_PORT=8080 \
    N8N_LISTEN_ADDRESS=0.0.0.0

COPY --from=build /app /app

# Matches internal_port = 8080 in fly.toml
EXPOSE 8080
CMD [ "node", "packages/cli/bin/n8n" ]