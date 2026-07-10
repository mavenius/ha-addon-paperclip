# Changelog

## 1.0.8

- Adds an optional Telegram bridge: four new config fields
  (`telegram_bot_token`, `telegram_chat_id`, `telegram_target_issue_id`,
  `telegram_api_key`), all off by default. When set, `run.sh` starts
  `telegram_poll.sh` in the background, which long-polls Telegram for new
  messages in the configured chat and posts them as comments on a fixed
  Paperclip issue — no LLM call involved, so it's free to run continuously.
  `telegram_notify.sh` is also bundled for manual outbound sends via
  `docker exec`. Poll offset is stored under `$PAPERCLIP_HOME` so it
  survives restarts/updates. See the "Telegram bridge" section in `DOCS.md`.

## 1.0.7

- Confirmed fix for Claude subscription auth failing with "Not logged in"
  when invoked by Paperclip's own server process: `HOME` must stay at the
  upstream image's own default (`/paperclip`), not be redirected into
  `/data`.
- To keep that login durable across add-on updates/reinstalls anyway,
  `run.sh` now shadows a copy of `/paperclip/.claude` into
  `$PAPERCLIP_HOME/claude-home` (which *is* persisted), restoring it on
  every boot and re-syncing it every 60 seconds while running.
- `run.sh` also chowns `/paperclip` to `node:node` on every boot, so
  credentials accidentally created by a root-run `claude login` (missing
  `-u node`) don't silently become unreadable to the actual server process.
- Adds `DOCS.md`, rendered in the add-on's own Documentation tab in Home
  Assistant, with the Claude login steps.

## 1.0.6

- Reverted the `HOME=/data/paperclip` override from 1.0.2 as a diagnostic
  step, to test whether it was the source of the Claude "Not logged in"
  failures. Confirmed it was.

## 1.0.5

- Moved static environment variables (`PAPERCLIP_HOME`, `PAPERCLIP_CONFIG`,
  deployment mode/exposure, `HOST`/`PORT`/`SERVE_UI`) from `run.sh` exports
  into Dockerfile `ENV` instructions, so they're consistent for `docker
  exec` sessions too, not just the process tree `run.sh` itself spawns.
  Previously, `docker exec ... pnpm paperclipai <cmd>` silently operated
  against the upstream image's unpersisted defaults instead of `/data`.
- Removed the temporary boot-env diagnostic dump added in 1.0.4 (it wrote
  secrets to disk in plaintext).

## 1.0.4

- (Temporary/diagnostic release, superseded by 1.0.5.)

## 1.0.3

- Persisted `PAPERCLIP_CONFIG` under `/data` instead of the image's
  unpersisted default path.

## 1.0.2

- Persisted `$HOME` under `/data` so Claude/Codex CLI logins would survive
  restarts. (Reverted in 1.0.6 — see above.)

## 1.0.1

- Fixed `EACCES: permission denied` on startup by chowning
  `$PAPERCLIP_HOME` before dropping privileges to the `node` user.
  `docker-entrypoint.sh` only chowns the image's default `/paperclip` path,
  and only when `USER_UID`/`USER_GID` differ from the `node` user's default
  (1000:1000) — which they don't in this add-on.

## 1.0.0

- Initial release: wraps `ghcr.io/paperclipai/paperclip` as a Home Assistant
  add-on.
