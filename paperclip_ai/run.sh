#!/usr/bin/env bash
set -e

OPTIONS=/data/options.json

export ANTHROPIC_API_KEY="$(jq -r '.anthropic_api_key // empty' "$OPTIONS")"
export OPENAI_API_KEY="$(jq -r '.openai_api_key // empty' "$OPTIONS")"
export BETTER_AUTH_SECRET="$(jq -r '.better_auth_secret' "$OPTIONS")"
export PAPERCLIP_PUBLIC_URL="$(jq -r '.public_url // empty' "$OPTIONS")"

# Static vars (PAPERCLIP_HOME, PAPERCLIP_CONFIG, deployment mode/exposure,
# HOST/PORT/SERVE_UI) are baked in as Dockerfile ENV instead of exported here,
# so they're consistent for `docker exec` sessions too, not just this process tree.
#
# HOME is deliberately NOT overridden -- it stays at the upstream image's own
# default (/paperclip). Pointing it at /data/paperclip (for claude login
# persistence) caused Claude Code to report "not logged in" specifically when
# invoked by the real server process, for reasons we couldn't pin down in
# Paperclip's source. Since /paperclip itself isn't in Supervisor's persisted
# /data volume, we instead shadow just Claude's login state (.claude/,
# .claude.json) into a backup dir under $PAPERCLIP_HOME (which is persisted),
# restore it on boot below, and keep it synced while running. See DOCS.md.

mkdir -p "$PAPERCLIP_HOME"

# docker-entrypoint.sh only chowns /paperclip when USER_UID/USER_GID differ
# from the node user's default (1000:1000), which they don't here -- and it
# never touches $PAPERCLIP_HOME at all. Fix both ourselves before dropping to
# the node user: /data is root-owned by Supervisor, and /paperclip needs to
# be writable/readable by node regardless of which user happened to create
# files there first (e.g. a `docker exec` for `claude login` run without
# `-u node`, which would otherwise leave root-owned credentials that the
# real (node-uid) server process can't read).
chown -R node:node "$PAPERCLIP_HOME"
mkdir -p /paperclip

CLAUDE_BACKUP="$PAPERCLIP_HOME/claude-home"

# Restore Claude's login state from the persisted backup, if we have one
# (e.g. after an add-on update rebuilt the container and wiped /paperclip).
if [ -d "$CLAUDE_BACKUP/.claude" ]; then
  rm -rf /paperclip/.claude
  cp -a "$CLAUDE_BACKUP/.claude" /paperclip/.claude
fi
if [ -f "$CLAUDE_BACKUP/.claude.json" ]; then
  cp -a "$CLAUDE_BACKUP/.claude.json" /paperclip/.claude.json
fi
chown -R node:node /paperclip

# Keep the backup in sync with whatever's live at /paperclip/.claude while
# the server runs, so a fresh `claude login` (or a token refresh) gets
# captured automatically instead of requiring a manual step. Runs as root in
# the background; ownership under $CLAUDE_BACKUP doesn't matter since only
# this script ever reads it (unlike /paperclip/.claude itself, which the
# node-uid server process needs to read directly).
(
  while true; do
    sleep 60
    mkdir -p "$CLAUDE_BACKUP"
    if [ -d /paperclip/.claude ]; then
      rm -rf "$CLAUDE_BACKUP/.claude.new"
      cp -a /paperclip/.claude "$CLAUDE_BACKUP/.claude.new" \
        && rm -rf "$CLAUDE_BACKUP/.claude" \
        && mv "$CLAUDE_BACKUP/.claude.new" "$CLAUDE_BACKUP/.claude"
    fi
    if [ -f /paperclip/.claude.json ]; then
      cp -a /paperclip/.claude.json "$CLAUDE_BACKUP/.claude.json"
    fi
  done
) &

exec docker-entrypoint.sh node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
