#!/usr/bin/env bash
# Copies Claude's live login state (/paperclip/.claude, /paperclip/.claude.json)
# into $PAPERCLIP_HOME/claude-home, which is in Supervisor's persisted /data
# volume. run.sh restores from there on boot. Called every 60s by run.sh's
# background sync loop, and immediately after a login/logout from the
# ingress login page (claude_login.sh) so there's no sync window to miss.
# Runs as root; ownership under the backup dir doesn't matter since only
# run.sh ever reads it back.

CLAUDE_BACKUP="$PAPERCLIP_HOME/claude-home"

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
