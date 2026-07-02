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
export PAPERCLIP_DEPLOYMENT_MODE=authenticated
export PAPERCLIP_DEPLOYMENT_EXPOSURE=private

mkdir -p "$PAPERCLIP_HOME"

exec docker-entrypoint.sh node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
