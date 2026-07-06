# Paperclip AI

## Configuration

- `anthropic_api_key` — optional. Set this if you want Claude agents to authenticate via API key (pay-per-token) instead of a Claude subscription.
- `openai_api_key` — optional, for OpenAI-backed agents.
- `better_auth_secret` — required. Any random string; used to sign session cookies. Generate one with `openssl rand -hex 32`.
- `public_url` — the address you'll reach this add-on at (e.g. `https://paperclip.yourdomain.com` or `http://<ha-ip>:3100`). Required for auth/session cookies to work correctly — set this before your first login.

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
