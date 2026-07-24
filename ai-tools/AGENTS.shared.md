<!-- shared-rules-begin -->
# Shared working rules (every agent, every directory)

Loaded by Claude Code, opencode and codex alike. Generic on purpose — no repo names, no
infrastructure facts. A project's own CLAUDE.md/AGENTS.md is more specific and wins where it
disagrees. Source: `dotfiles/ai-tools/AGENTS.shared.md`.

## Shell hygiene

Always use non-interactive flags — `cp`/`mv`/`rm` are frequently aliased to `-i` and an agent
waiting on a y/n prompt hangs forever:

```bash
cp -f src dst      mv -f src dst      rm -f file      rm -rf dir      cp -rf src dst
ssh -o BatchMode=yes      scp -o BatchMode=yes      apt-get -y      HOMEBREW_NO_AUTO_UPDATE=1
```

Same rule for anything else that can prompt: pass the flag that makes it fail instead of ask.

## Validation and landing work

- **Run the repo's own gate before opening a PR/MR and before any push aimed at the default
  branch** — `bin/ci`, `nx affected -t lint,test,e2e,build`, `pnpm test`, whatever that repo
  actually has. Never open an MR on unvalidated work.
- **Rebase onto the default branch first**, then re-run the gate. A green run against a stale base
  proves nothing.
- Report failures. Do not route around a failing gate, mark it flaky, or narrow its scope to get
  green.
- When the repo has an issue tracker, link the PR/MR back on the issue.
- Create worktrees with `workmux`, not hand-rolled `git worktree add`.

## Issue tracking — beads (`bd`)

When a repo has a `.beads/` directory, beads is the task tracker. Use it for **all** task
tracking and persistent notes — never the harness's built-in todo tools, never a markdown
TODO list, never a scratch file.

```bash
bd prime                       # workflow context (session start, after a compaction)
bd ready                       # work with no open blockers
bd show <id>                   # detail, dependencies
bd create --title=… --description=… --type=task|bug|feature --priority=0..4
bd update <id> --claim         # claim before you start
bd close <id> --reason="…"     # close on finish; takes several ids at once
bd remember "…" / bd memories <kw>   # persistent knowledge across sessions
```

Add `--json` to anything you are going to parse. `bd edit` opens `$EDITOR` and will hang an
agent — use `bd update --title/--description/--notes` instead.

**Sync is Dolt, not the JSONL.** The issues live in a local Dolt database and travel over
`refs/dolt/data` on the git remote: `bd dolt pull` when you start, `bd dolt push` before you
finish. `.beads/issues.jsonl` is a passive export for viewers and backup — importing it is
upsert-only, so it can carry a new issue but never a close or a delete. Treating it as the
sync channel is what produces rebase conflicts and issues that rise from the dead.

Two things every beads repo should have; check and fix them once rather than fighting the
symptoms:

- A Dolt remote. `git ls-remote origin 'refs/dolt/*'` must return something. If it is empty:
  `bd dolt remote add origin <git origin url> && bd dolt push`.
- `.beads/issues.jsonl merge=ours` in `.gitattributes` (with `merge.ours.driver = true` in the
  git config), so git stops three-way-merging a generated file.

**Worktrees need no beads setup.** `bd` discovers the parent repo's `.beads/` through git's
common dir. Never run `bd init` in a worktree and never symlink or copy `.beads` into one; a
worktree with its own database is the documented failure mode. The `.beads/*.jsonl` files
visible inside a worktree are just the git-tracked export — leave them.

If `bd` warns about multiple binaries in `PATH`, that is a real problem, not noise: two
versions will disagree about the schema. Resolve it before continuing.

## Architecture defaults

- **Shared libraries stay app-agnostic.** No per-site IDs, domains, API keys, analytics tags,
  feature flags or `if (site === 'x')` maps inside a shared lib. A lib defines a generic contract
  (props, or generic env vars like `SITE_GTM_ID`); each consuming app supplies the values from its
  own environment or call site. Reaching for an app name inside a lib means that config belongs one
  level up.
- **Apps build to Docker images by default.** Use nix flakes and/or direnv (`.envrc` committed,
  `direnv allow` on first checkout) when an app needs a pinned or complex toolchain. Projects that
  deviate say so in their own CLAUDE.md, and that wins.
- **Deploy through the repo's dispatcher** (`./bin/deploy <app> [stage]` or equivalent). Never
  hand-run `docker push`, `rsync`, `pm2`, or an ssh deploy — the pipeline owns that.

## Ports

- Every app reserves distinct ports per purpose (dev / prod-preview / e2e), recorded in a
  `docs/PORTS.md` table and overridable by `PORT` / `E2E_PORT`. Nothing collides, and any stuck
  process is findable: `lsof -ti :<port> | xargs kill`.
- Kill by port, never by process name.
- In a worktree, use the `/dev` skill (`wtport` hashes the path to a stable port) instead of a
  framework default like 5173/4200/3000 — and never kill a port that is not this worktree's.

## Prose and editorial content

- Run any hand- or LLM-authored prose through the `humanizer` skill before it ships: site copy,
  blog posts, release notes, outreach, free-text form answers, cover letters.
- **No em/en dashes (`—` / `–`) in shipped prose.**
- Humanize the prose only — leave frontmatter, HTML/markup and headings untouched.
- Voice sample: `~/code/tomfordweb/dotfiles/docs/ai/writing-voice.md` (curated register) plus
  `docs/ai/writing-voice-observed.md` (structure and vocabulary mined from real transcripts) unless
  another sample is given. Skill: `~/code/tomfordweb/dotfiles/ai-tools/skills/humanizer/SKILL.md`.
- Observed working preferences: `~/code/tomfordweb/dotfiles/docs/ai/preferences-observed.md`.

## Reference

Deeper patterns (deploy dispatcher shape, CI gate layout, port registries, direnv/secret layering,
local infra) live in `~/code/tomfordweb/dotfiles/ai-tools/docs/app-conventions.md`. Read it when
setting up or reworking that part of a project; don't preload it.
<!-- shared-rules-end -->
