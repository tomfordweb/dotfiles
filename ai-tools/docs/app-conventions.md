# App conventions — patterns worth reusing

Read this when setting up or reworking a project's build, deploy, CI, ports or local
infrastructure. It is reference material, not always-on context: the short rules live in
`ai-tools/AGENTS.shared.md`, and this file explains the shapes behind them.

Written generically. The worked example throughout is an Nx/pnpm monorepo of small deployed apps,
but nothing here depends on Nx.

---

## Deploy dispatcher

One entry point, `./bin/deploy <app> [stage]`, with stages that can each be run alone:

```
security | lint | test | typecheck | build | e2e | migrate | deploy | ingest | all
```

What the dispatcher owns, so that no caller ever has to:

- **A deterministic build environment.** Task-runner daemons are a classic silent failure: a
  daemon started earlier keeps its own stale environment and drops inline build-time variables, so
  a build "succeeds" with the analytics/Sentry/feature tags missing. Disable the daemon for the
  whole deploy (`export NX_DAEMON=false` before anything can spawn one) rather than per command.
- **Secret injection at the right phase.** Build-time (browser) values must be present when the
  bundle is built; runtime (server) values are injected at start. Bootstrap a read-only token once
  at the top of the run, then reuse it for every subsequent secret read instead of prompting per
  call.
- **Platform quirks in one place.** Example: on NixOS, browsers downloaded by `playwright install`
  are linked against FHS libraries that do not exist, so the dispatcher points
  `PLAYWRIGHT_BROWSERS_PATH` at the nix-provided browsers. Guard such fixes on "variable unset" and
  "this platform" so an explicit override, or another machine, is untouched.
- **A verbose switch** (`DEPLOY_VERBOSE=1`) that turns on both the task runner's full output and
  shell xtrace, exported so it propagates into stage scripts.
- **A record of what shipped.** Tag each successful deploy: `deploy/prod/<app>/<timestamp>-<sha>`.

Per-app stage logic lives in `apps/<app>/bin/stage-*.sh` sourcing a shared library, so an app opts
into the stages it supports and the dispatcher fails loudly when a stage is missing.

## CI gate

A single script (`bin/ci`) is the gate, run locally and by whatever hosted CI exists — same code
path, no drift:

- Default: **affected** projects only, compared against `origin/main`, running
  lint + format + test + typecheck + build + e2e.
- `--all`: everything, for release branches and dependency bumps.
- `--pre-push`: the fast subset (lint, typecheck, test, format — no build, no e2e), wired into a
  git pre-push hook so pushing stays quick but never unchecked.
- Exclusions are explicit and commented with the condition for removing them ("pre-launch, remove
  at cutover"). An undocumented exclusion becomes permanent by accident.

## Port registry

A `docs/PORTS.md` table with a row per app and a column per purpose — dev, prod-preview, e2e —
plus a line for shared infrastructure (database, mail catcher, SMTP). Rules that make it worth
keeping:

- Every port is distinct, so nothing collides when several apps run at once.
- Every port is overridable (`PORT`, `E2E_PORT`) for ad-hoc runs.
- Every process is therefore findable and killable by port: `lsof -ti :<port> | xargs kill`.
- A uniform `serve-prod` target per app (build, then run the production server on the reserved
  port) means "does the production build actually work" is one command, not a deploy.
- In worktrees, hash the path to a port instead (`wtport`) so parallel checkouts never fight.

## Environment and secrets

Layered, cheapest first:

1. **`.env.example` → `.env`** for local infrastructure values (host ports, mail catcher). Committed
   example, gitignored real file.
2. **direnv** (`.envrc`, committed): auto-loads `.env`, puts `bin/` and `node_modules/.bin` on
   `PATH`, bootstraps read-only tokens, exports profile toggles. First checkout needs one
   `direnv allow`; worktree tooling can do it in a post-create hook.
3. **A secret manager** for anything real, referenced by *pointer* in committed files
   (`op://<vault>/<item>/<KEY>`) and resolved at run time (`op run --env-file=… --`, `op inject`).
   Templates commit; values never do.
4. **nix flakes** when the toolchain itself needs pinning, not just the environment.

Two details that cost hours when missed: `.trim()` every value read from a secret CLI (trailing
newlines break auth in ways that look like wrong credentials), and prefer a read-only service
account for automation while keeping an explicit escape hatch for the rare write.

## Local infrastructure

One database server and one mail catcher for the whole workspace, each app owning its own schema
inside them — not one container stack per app. Brought up with a single `./bin/dev-up`. Containers
are fine here even when production does not use them; keep that boundary explicit so nobody
promotes the dev compose file to a deploy mechanism.

## AI/model toggles

When apps call a model API, put the provider behind a profile switch (`bin/ai-profile
local|cloud|status`) that swaps base URL, key and model together, with state in a gitignored file
and per-run environment overrides always winning. Default to the local model: free, private, and it
keeps the cloud path honest because both are exercised.
