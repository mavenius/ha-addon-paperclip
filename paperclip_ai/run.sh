#!/usr/bin/env bash
set -e

OPTIONS=/data/options.json

export ANTHROPIC_API_KEY="$(jq -r '.anthropic_api_key // empty' "$OPTIONS")"
export OPENAI_API_KEY="$(jq -r '.openai_api_key // empty' "$OPTIONS")"
export BETTER_AUTH_SECRET="$(jq -r '.better_auth_secret' "$OPTIONS")"
export PAPERCLIP_PUBLIC_URL="$(jq -r '.public_url // empty' "$OPTIONS")"

# Static vars (HOME, PAPERCLIP_HOME, PAPERCLIP_CONFIG, deployment mode/exposure,
# HOST/PORT/SERVE_UI) are baked in as Dockerfile ENV instead of exported here,
# so they're consistent for `docker exec` sessions too, not just this process tree.

mkdir -p "$PAPERCLIP_HOME"

# docker-entrypoint.sh only chowns the image's default /paperclip path, not
# $PAPERCLIP_HOME, and only when USER_UID/USER_GID differ from the node
# user's default (1000:1000) -- which they don't here. /data is root-owned
# by Supervisor, so fix ownership ourselves before dropping to the node user.
chown -R node:node "$PAPERCLIP_HOME"

exec docker-entrypoint.sh node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
