---
name: dev
description: Start a JS/TS dev server on this worktree's own deterministic port (never the shared default), so parallel worktrees never collide or get killed. USE WHEN about to run a dev server in a JS project — pnpm dev, npm run dev/start, ng serve, vite, next dev, astro dev — or when the user types /dev.
user-invocable: true
allowed-tools: Bash
---

# /dev

Start a JS/TS dev server on a **per-worktree deterministic port** so parallel worktrees never
fight over a default port (Vite 5173, Angular 4200, Next 3000) and Claude never kills another
worktree's server.

## Context

- **Working dir:** !`pwd`
- **Derived port:** !`wtport 2>/dev/null || echo "(wtport not on PATH)"`
- **Already listening on that port:** !`p=$(wtport 2>/dev/null); { lsof -i :"$p" -sTCP:LISTEN -P -n 2>/dev/null || ss -ltnp 2>/dev/null | grep -w ":$p"; } | head -3 || true`

## Workflow

### 1. Resolve the port

```bash
port=$(wtport)
```

Never assume 5173/4200/3000. `wtport` hashes the cwd → a stable port in 3100–3999. Same
worktree always gets the same port; `$PORT` overrides it.

### 2. Reuse, never kill

If the Context above shows something already listening on `$port`, that is *this* worktree's
server. Report `http://localhost:$port` and **stop** — do not restart it.

**Hard rule:** never kill a process on any port other than this worktree's `$port`. Other
listening ports belong to other worktrees.

### 3. Detect framework and launch

Read `package.json` (deps + the `dev`/`start` script), then launch through `devserver` so the
Stop hook can reap it on session end:

- **Vite-based** (`vite`, `@analogjs/*`, SvelteKit+Vite):
  `devserver pnpm dev -- --port "$port" --strictPort`
- **Angular** (`@angular/cli`, `ng serve`):
  `devserver pnpm dev -- --port "$port"`
- **Astro** (`astro dev`):
  `devserver pnpm dev -- --port "$port"`
- **`$PORT`-respecting** (`next`, `react-scripts`, `nuxt`, `@sveltejs/kit` node, `remix`):
  `devserver pnpm dev` — `devserver` already exported `PORT=$port`.
- **Unknown:** try `devserver pnpm dev -- --port "$port"`; if the tool rejects `--port`, fall
  back to `PORT="$port" devserver pnpm dev`.

Use the project's package manager (pnpm by default; honor a `package-lock.json`/`yarn.lock`).
Run the launch with `run_in_background: true`.

### 4. Report

Tell the user the worktree's dev URL: `http://localhost:$port`.

## Hard rules

- Always launch via `devserver` (records the pidfile for cleanup).
- Never assume a framework default port — always `wtport`.
- Only ever kill a dev server on *this* worktree's `wtport`.
