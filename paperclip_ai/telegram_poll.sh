#!/usr/bin/env bash
# Optional Telegram inbound poller. Long-polls Telegram's getUpdates API and
# posts new messages from the configured chat as a comment on a fixed
# Paperclip issue, so a team can reply to the bot and have it show up on the
# board without anyone babysitting Telegram directly.
#
# Pure shell + curl — never invokes an LLM or spawns an agent run, so it has
# zero token cost no matter how long it runs.
#
# Only started by run.sh when telegram_bot_token, telegram_chat_id,
# telegram_target_issue_id, and telegram_api_key are all set in the add-on's
# Configuration tab; otherwise this script is never invoked.
#
# The offset (last processed update_id) is kept under $PAPERCLIP_HOME, which
# is Supervisor's persisted /data volume, so restarts/updates don't replay
# old messages and don't re-poll from scratch.

set -euo pipefail

: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID not set}"
: "${TELEGRAM_TARGET_ISSUE_ID:?TELEGRAM_TARGET_ISSUE_ID not set}"
: "${TELEGRAM_API_KEY:?TELEGRAM_API_KEY not set}"
: "${PAPERCLIP_HOME:?PAPERCLIP_HOME not set}"
: "${PORT:?PORT not set}"

OFFSET_FILE="$PAPERCLIP_HOME/telegram_poll_offset"
API_BASE="http://127.0.0.1:${PORT}"

log() {
  echo "[telegram-poll] $(date -u +%FT%TZ) $*"
}

post_comment() {
  local body="$1"
  curl -sS -o /dev/null -w '%{http_code}' -X POST \
    "$API_BASE/api/issues/${TELEGRAM_TARGET_ISSUE_ID}/comments" \
    -H "Authorization: Bearer ${TELEGRAM_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"body": sys.argv[1]}))' "$body")"
}

get_offset() {
  [[ -f "$OFFSET_FILE" ]] && cat "$OFFSET_FILE" || echo 0
}

log "Starting Telegram poll loop for issue ${TELEGRAM_TARGET_ISSUE_ID}, offset=$(get_offset)"

while true; do
  OFFSET=$(get_offset)
  RESPONSE=$(curl -sS --max-time 35 \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates" \
    --data-urlencode "offset=$((OFFSET + 1))" \
    --data-urlencode "timeout=30" \
    --data-urlencode 'allowed_updates=["message"]') || {
      log "getUpdates request failed, backing off 10s"
      sleep 10
      continue
    }

  # Extract (update_id, chat_id, from, text) tuples; skip non-message updates.
  mapfile -t ROWS < <(python3 - "$RESPONSE" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
for r in data.get("result", []):
    msg = r.get("message")
    if not msg:
        continue
    print(r["update_id"], msg.get("chat", {}).get("id"), msg.get("from", {}).get("username") or msg.get("from", {}).get("first_name", "?"), json.dumps(msg.get("text", "")))
PY
  )

  MAX_ID=$OFFSET
  for ROW in "${ROWS[@]:-}"; do
    [[ -z "$ROW" ]] && continue
    read -r UPD_ID MSG_CHAT_ID FROM TEXT_JSON <<<"$ROW"
    TEXT=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]))' "$TEXT_JSON")
    (( UPD_ID > MAX_ID )) && MAX_ID=$UPD_ID

    if [[ "$MSG_CHAT_ID" != "$TELEGRAM_CHAT_ID" ]]; then
      log "Skipping message from unexpected chat $MSG_CHAT_ID"
      continue
    fi

    log "New message from $FROM: $TEXT"
    CODE=$(post_comment "[Telegram] ${FROM}: ${TEXT}")
    log "Posted as comment on issue ${TELEGRAM_TARGET_ISSUE_ID}, HTTP $CODE"
  done

  if (( MAX_ID > OFFSET )); then
    echo "$MAX_ID" > "$OFFSET_FILE"
  fi

  sleep 2
done
