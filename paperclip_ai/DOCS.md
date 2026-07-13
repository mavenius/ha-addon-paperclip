# Paperclip AI

## Configuration

- `anthropic_api_key` — optional. Set this if you want Claude agents to authenticate via API key (pay-per-token) instead of a Claude subscription.
- `openai_api_key` — optional, for OpenAI-backed agents.
- `better_auth_secret` — required. Any random string; used to sign session cookies. Generate one with `openssl rand -hex 32`.
- `public_url` — the address you'll reach this add-on at (e.g. `https://paperclip.yourdomain.com` or `http://<ha-ip>:3100`). Required for auth/session cookies to work correctly — set this before your first login.
- `telegram_bot_token`, `telegram_chat_id`, `telegram_target_issue_id`, `telegram_api_key` — optional, all four required together to enable the Telegram bridge. See below.

## First run

Open the add-on's web UI (port 3100, or your `public_url`), sign up, then choose **Claim this instance** on the setup screen.

## Logging into Claude with a subscription (Pro/Max) instead of an API key

If you want agents to run on your Claude subscription rather than `anthropic_api_key`, you need to log in interactively, once, via a shell in the container. This **cannot** be done from this config page — it requires an interactive OAuth flow.

1. Install the **Terminal & SSH** add-on if you don't already have shell access to the Home Assistant host.
2. Find this add-on's container name: `docker ps | grep paperclip` (something like `addon_<hash>_paperclip_ai`).
3. Log in as the `node` user specifically — **do not omit `-u node`**, or the credentials will be created as `root` and the actual server (which runs as `node`) won't be able to read them:
   ```sh
   docker exec -it -u node <container-name> claude login
   ```
4. Follow the printed URL to authorize in your browser.
5. Verify: `docker exec -u node <container-name> claude --version`

That's it — the login survives add-on updates/reinstalls automatically. Claude's login state lives at `/paperclip/.claude`, which isn't itself part of Supervisor's persisted `/data` volume (see the comment in this repo's `Dockerfile` for why we can't just relocate it there directly), but `run.sh` shadows a copy of it into `$PAPERCLIP_HOME/claude-home` (which *is* persisted) and restores it automatically on every boot. It also re-syncs that backup every 60 seconds while running, so a fresh login or a token refresh gets captured without any manual step.

If Paperclip's UI ever reports "Not logged in" after an update, it most likely means you logged in for the first time less than a minute before the add-on was updated/restarted (missing the sync window) — just repeat step 3.

## Telegram bridge (optional)

Lets a team reply in a Telegram chat and have it show up as a comment on a
fixed Paperclip issue — useful as a lightweight way to talk to your agents
from your phone. This is a plain shell script that long-polls Telegram's
`getUpdates` API and posts to Paperclip's own REST API; it does not invoke
an LLM or spawn an agent run, so it costs nothing to leave running. It is
**off by default** — nothing contacts Telegram unless you set all four
options below.

1. Create a bot via [@BotFather](https://t.me/BotFather) (`/newbot`) and
   copy the token it gives you into `telegram_bot_token`.
2. Add the bot to a group (or DM it directly), send it a message, then find
   the numeric chat ID — e.g. by messaging [@userinfobot](https://t.me/userinfobot)
   from that same chat, or via `https://api.telegram.org/bot<token>/getUpdates`.
   Put that in `telegram_chat_id`.
3. Pick (or create) the Paperclip issue you want inbound Telegram messages
   to land on as comments, and put its ID (the UUID, from the issue's URL or
   API response — not its short `HOM-16`-style identifier) in
   `telegram_target_issue_id`.
4. Generate a Paperclip API key with comment-posting permission on that
   issue's board (Paperclip's own UI, under your account/API settings), and
   put it in `telegram_api_key`. This is a separate credential from any
   individual agent's own key — it's what the always-on poller process
   authenticates as, since it runs at add-on boot, before any agent run
   exists.
5. Restart the add-on. Check the **Log** tab for `Starting Telegram inbound
   poller` — if you instead see `Telegram bridge not configured`, one of the
   four fields above is still empty.

Outbound (bot → Telegram) isn't wired up automatically — `/telegram_notify.sh
"message text"` is included in the image for manual/scripted use (e.g. from
a `docker exec` shell, or from an agent that has shell access to this
container), reading the same `telegram_bot_token`/`telegram_chat_id`
configured above.

The poller's last-seen Telegram message ID is stored under
`$PAPERCLIP_HOME/telegram_poll_offset` (Supervisor's persisted `/data`
volume), so restarts and add-on updates don't replay old messages.
