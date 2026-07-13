#!/usr/bin/env bash
# Sends a Telegram message via the raw Bot API. Convenience script for
# manual/ad-hoc use from a shell inside the container (e.g. `docker exec`);
# nothing in this add-on calls it automatically.
#
# Reads TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID, which run.sh exports into PID 1's
# process tree from the add-on's Configuration options. A fresh `docker exec`
# shell does not inherit those (they're per-install secrets from
# /data/options.json, not baked into the image) -- pass them explicitly in
# that case, e.g.:
#   docker exec -e TELEGRAM_BOT_TOKEN=... -e TELEGRAM_CHAT_ID=... <container> /telegram_notify.sh "hello"
#
# Usage: telegram_notify.sh "message text"

set -euo pipefail

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
  echo "TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set" >&2
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 \"message text\"" >&2
  exit 1
fi

MESSAGE="$1"

RESPONSE=$(curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${MESSAGE}")

echo "$RESPONSE"

if ! grep -q '"ok":true' <<<"$RESPONSE"; then
  echo "Telegram API call failed" >&2
  exit 1
fi
