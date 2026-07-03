## Summary

`claude_local` adapter's environment probe (and, presumably, real agent runs) reports `claude_hello_probe_auth_required` ("Not logged in · Please run `/login`") when Claude Code CLI is invoked by Paperclip's own Node process — even though the exact same command, with identical user, working directory, environment variables, CLI flags, and even detached/new-session process semantics, succeeds every time when invoked manually via `docker exec` in the same running container.

This is not the `CLAUDE_CONFIG_DIR=/tmp/claude-sandbox` issue from #5661 — that mechanism is confirmed absent here (see elimination steps below).

## Environment

| Item | Value |
|---|---|
| Deployment | Docker, `ghcr.io/paperclipai/paperclip:latest`, wrapped in a thin custom entrypoint (Home Assistant Supervisor add-on) |
| `claude_code_version` | 2.1.198 |
| Auth method | `claude.ai` subscription (Claude Pro), via `claude login` |
| Execution target | Local (`claude_local` adapter, "Local Claude agent" — not sandbox/remote) |
| `PAPERCLIP_DEPLOYMENT_MODE` | `authenticated` |
| `PAPERCLIP_DEPLOYMENT_EXPOSURE` | `private` |
| `HOME` / `PAPERCLIP_HOME` | `/data/paperclip` (both set explicitly, consistent everywhere checked) |
| Server process UID | 1000 (`node`), confirmed via `/proc/1/status` |

## Steps to reproduce

1. Run the `ghcr.io/paperclipai/paperclip` image with `PAPERCLIP_DEPLOYMENT_MODE=authenticated`, `PAPERCLIP_DEPLOYMENT_EXPOSURE=private`, `HOME=/data/paperclip` (or any persisted path).
2. `docker exec -u node <container> claude login`, complete subscription OAuth. Confirm `~/.claude/.credentials.json` and `~/.claude.json` (with populated `oauthAccount`) are both written under the configured `HOME`.
3. In Paperclip's UI, configure a `claude_local` adapter ("Local Claude agent"), no custom environment variables.
4. Run the adapter's environment/probe check ("Test").

## Expected behavior

Probe succeeds, same as a manual `claude --print - --output-format stream-json --verbose` invocation with the same credentials.

## Actual behavior

```json
{"type":"result","subtype":"success","is_error":true,"api_error_status":null,"duration_ms":104,"duration_api_ms":0,"num_turns":1,"result":"Not logged in · Please run /login","stop_reason":"stop_sequence","session_id":"..."}
```

Note `duration_api_ms: 0` — the CLI never reaches Anthropic's API, meaning the rejection is a purely local credential-resolution failure inside the CLI itself, at probe time, every time.

## Elimination steps taken (all ruled out)

Working from `packages/adapter-utils/src/execution-target.ts` (`runAdapterExecutionTargetProcess`) and `packages/adapter-utils/src/server-utils.ts` (`runChildProcess`, `sanitizeInheritedPaperclipEnv`, `ensurePathInEnv`), plus `packages/adapters/claude-local/src/server/test.ts`:

1. **Effective user mismatch.** Confirmed via `/proc/1/status` inside the container: the actual running server process (PID 1) runs as UID 1000 (`node`), same as our manual `docker exec -u node` reproductions.
2. **`$HOME` / environment mismatch.** `runChildProcess` merges `{ ...sanitizeInheritedPaperclipEnv(process.env), ...opts.env }` — `sanitizeInheritedPaperclipEnv` only strips `PAPERCLIP_*` keys (with an allowlist for a few). `opts.env` for a local (non-remote) `claude_local` probe comes from `parseObject(config.env)` only (empty — no adapter-level env overrides configured in the UI). We captured the container's actual boot-time environment (dumped from `run.sh` itself, root, immediately before `exec docker-entrypoint.sh ...`, i.e. as close to PID 1's real env as observable without `CAP_SYS_PTRACE`, which this container lacks even for root reading `/proc/1/environ`). `HOME=/data/paperclip`, `PATH` includes `/usr/local/bin` (where the global `claude` install lives), no `CLAUDE_CONFIG_DIR`, no `NODE_OPTIONS`. All confirmed to match what a fresh `docker exec` session sees.
3. **`CLAUDE_CONFIG_DIR` redirect (the #5661 mechanism).** Confirmed absent: no `.env` files anywhere under the Paperclip instance directory, no `CLAUDE_CONFIG_DIR` string anywhere under `/data` or `/app` (excluding test fixtures/source references), not present in the captured boot-time environment. The remote-only seeding path in `test.ts` (`prepareClaudeConfigSeed` / `materializeRemoteClaudeConfig`, gated on `targetIsRemote && adapterExecutionTargetUsesManagedHome(target)`) never runs for a local target, so it can't be silently injecting anything either.
4. **Wrong/shadow `claude` binary.** `command -v claude` / `which -a claude` both resolve to a single binary: `/usr/local/bin/claude -> ../lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe`, version 2.1.198 — matching what the probe itself reports (`claude_code_version` in the `system/init` event).
5. **CLI flags.** `test.ts` defaults `dangerouslySkipPermissions` to `true`, adding `--dangerously-skip-permissions` for local targets (`buildClaudeProbePermissionArgs`). Reproduced manually with this flag included — still succeeds.
6. **Detached process group / new session.** `runChildProcess` spawns with `detached: process.platform !== "win32"` (i.e. `true` here), which calls `setsid()` on Linux. Reproduced manually via `setsid sh -c '... | claude ...'` — still succeeds.
7. **Stale/cached UI result.** Confirmed the Warnings panel timestamp updates to the current time on every retry — this is a genuinely fresh probe each time, not a cached DB result being redisplayed.
8. **Credential/token validity.** `~/.claude/.credentials.json` present, correct ownership (`node:node`), correct mode. `~/.claude.json` present and healthy: `hasCompletedOnboarding: true`, populated `oauthAccount` (valid `accountUuid`/`emailAddress`/`organizationUuid`, `organizationType: "claude_pro"`), and a `projects["/app"]` entry showing `hasTrustDialogAccepted: true` with a real prior `lastSessionId` — i.e. Claude Code has already run successfully against this exact `HOME`/cwd combination (via our manual tests), using this exact credential file.
9. **Concurrency/token rotation.** Repeated manual reproductions across a ~20 minute window all succeeded, interleaved with repeated failures of the internal probe — inconsistent with a one-time token-refresh race.

Every manual reproduction that matches Paperclip's actual invocation (user, cwd, env, flags, detachment) succeeds. Only the invocation actually made by Paperclip's own server process fails, every time, with no discernible external difference. This suggests the divergence is something internal to the spawn call we couldn't observe from outside the container (e.g. stdio handling/timing, `resolveSpawnTarget`'s exact resolved command/args, or something Claude Code's own (closed-source) CLI does differently when its parent process is a Node.js `child_process` versus a shell) — I couldn't narrow it further without adding instrumentation to Paperclip's own source or getting visibility into the CLI's internals.

## Workaround

Switching the adapter to `ANTHROPIC_API_KEY`-based auth avoids this entirely, since it's a separate code path from subscription/credential-file resolution.
