# Paperclip AI — Home Assistant add-on

Wraps the official `ghcr.io/paperclipai/paperclip` image (built from
https://github.com/paperclipai/paperclip) with a small entrypoint that reads
Home Assistant's `/data/options.json` and exports it as environment
variables, since the upstream image doesn't know about HA's options format.

## Install

1. Push this folder to its own GitHub repo (or copy it to `/addons` on the
   HAOS host over Samba/SSH — either works as a Supervisor add-on source).
2. In Home Assistant: **Settings → Add-ons → Add-on Store → ⋮ (top right) →
   Repositories**, add the repo URL (skip this step if you used the local
   `/addons` folder).
3. Refresh the store, find **Paperclip AI**, click **Install**.
4. Open the **Configuration** tab and set:
   - `better_auth_secret` — any random string (required, used to sign
     session cookies).
   - `anthropic_api_key` — set this if you want Claude agents to run on
     API-key billing. Skip it if you'd rather use a Claude subscription
     instead (see `paperclip_ai/DOCS.md`, or the add-on's own
     **Documentation** tab in HA, for the login steps that requires).
   - `openai_api_key` — optional, only if you want agents that use OpenAI.
   - `public_url` — e.g. `http://homeassistant.local:3100` or whatever
     address you'll reach the add-on at. Needed for auth redirects to work.
5. **Start** the add-on, check the **Log** tab for errors.
6. Open `http://<your-ha-ip>:3100` for the Paperclip dashboard.

## Notes

- Data (including the embedded Postgres database) persists under the add-on's
  `/data/paperclip` directory, which Supervisor keeps across restarts/updates
  automatically — no extra volume mapping needed.
- `$HOME` (and thus Claude Code's own login state, at `/paperclip/.claude`)
  is deliberately **left at Paperclip's own default and not redirected into
  `/data`**. We tried persisting it directly and it caused Claude's CLI to
  report "not logged in" specifically when invoked by Paperclip's own server
  process — see the comment in `paperclip_ai/Dockerfile` for the full story.
  Instead, `run.sh` shadows a copy of `/paperclip/.claude` into
  `$PAPERCLIP_HOME/claude-home` (which *is* persisted), restoring it on every
  boot and re-syncing it every 60s while running — so subscription-based
  Claude login (see `paperclip_ai/DOCS.md`) survives updates/reinstalls
  without needing to be redone.
- This does **not** use HA's ingress (sidebar-embedded) UI, since Paperclip
  manages its own auth/session cookies that assume a fixed `public_url`.
  You reach it via the mapped port directly instead.
- `arch:` in `config.yaml` assumes the upstream GHCR image is a multi-arch
  manifest (amd64 + arm64); if the add-on fails to pull on your hardware,
  check https://github.com/paperclipai/paperclip/pkgs/container/paperclip
  for which platforms are actually published.
