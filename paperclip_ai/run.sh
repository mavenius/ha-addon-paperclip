#!/usr/bin/env bash
set -e

OPTIONS=/data/options.json

export ANTHROPIC_API_KEY="$(jq -r '.anthropic_api_key // empty' "$OPTIONS")"
export OPENAI_API_KEY="$(jq -r '.openai_api_key // empty' "$OPTIONS")"
export BETTER_AUTH_SECRET="$(jq -r '.better_auth_secret' "$OPTIONS")"
export PAPERCLIP_PUBLIC_URL="$(jq -r '.public_url // empty' "$OPTIONS")"

export HOST=0.0.0.0
export PORT=3100
export SERVE_UI=true
export PAPERCLIP_HOME=/data/paperclip
export PAPERCLIP_INSTANCE_ID=default
export PAPERCLIP_CONFIG=/data/paperclip/instances/default/config.json
export PAPERCLIP_DEPLOYMENT_MODE=authenticated
export PAPERCLIP_DEPLOYMENT_EXPOSURE=private

mkdir -p "$PAPERCLIP_HOME"

# docker-entrypoint.sh only chowns the image's default /paperclip path, not
# $PAPERCLIP_HOME, and only when USER_UID/USER_GID differ from the node
# user's default (1000:1000) -- which they don't here. /data is root-owned
# by Supervisor, so fix ownership ourselves before dropping to the node user.
chown -R node:node "$PAPERCLIP_HOME"

# TEMPORARY: snapshot the env right before handing off to docker-entrypoint.sh
# (still root, no ptrace needed) so we can compare it against what a fresh
# `docker exec` session sees. Remove once the claude-auth investigation is done.
env | sort > /data/boot-env.debug.txt

exec docker-entrypoint.sh node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
