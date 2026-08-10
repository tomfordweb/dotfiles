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

- **The gate runs ONCE, at push time — not after every edit.** If the repo enforces its gate
  in a pre-push hook (check `.git/hooks/pre-push`, `core.hooksPath`, husky), the hook IS the
  gate: do not run the full gate manually before pushing, and never bypass the hook
  (`--no-verify`, skip env vars) to land work. Only when a repo has no gate hook do you run
  its gate yourself — `bin/ci`, `nx affected -t lint,test,build`, `pnpm test`, whatever it
  actually has — once, before opening the PR/MR. Never open an MR on unvalidated work.
- **While iterating, run only targeted checks** for what you touched — a single project's
  test/lint target, one spec file. Do not run the whole affected graph mid-task, at every
  commit, or as a session-close ritual; the "quality gates" step of any session-close
  checklist is satisfied by the pre-push hook firing at push time.
- **Rebase onto the default branch first**, then push (the hook gates the rebased state).
  A green run against a stale base proves nothing.
- Report failures. Do not route around a failing gate, mark it flaky, or narrow its scope to get
  green.
- When the repo has an issue tracker, link the PR/MR back on the issue.
- Create worktrees with `workmux`, not hand-rolled `git worktree add`. Agent-created
  sessions should default to
  `workmux add --mode session --background --no-pane-cmds --base <base> <branch>`
  so worktree setup runs without opening panes or starting empty agent windows.
  `--mode session` is the important one: in the default window mode every worktree
  puts a window in the attached tmux session, so an agent working an epic leaves
  tens of empty windows behind. Session mode parks each worktree in its own
  detached session instead, and `workmux rm` tears that down with the worktree.
  Do NOT try to get this from `workmux add --config <file>`: a `--config` file
  replaces the project `.workmux.yaml` instead of layering on it, so the worktree
  lands outside `worktree_dir` and skips the repo's `post_create` hooks and file
  copy/symlink ops. Pass the flag.
- When sidemux is available, run heavy commands through the sidemux MCP `run` tool instead of
  invoking `sidemux` from the shell. Shell `sidemux`/`workmux sidebar` commands are user-control
  commands, not the default path for agent validation.

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

## Provisioning credentials through a browser session

Applies when you are driving a browser to create or retrieve a credential on someone's behalf —
issuing an API key, generating a client secret, reading a connection string out of a hosting
console. Ordinary browsing is not the concern; a page that is about to hand you a live secret is.

Redacting what is *visible* is not enough on those pages. Consoles routinely keep the full value
somewhere the eye never goes — an attribute behind a copy button, a data property, a hidden
input, a JSON blob in page state — so enumerating elements to find a control captures the secret
without ever "reading" it. Assume the page has at least one such hiding place you have not
thought of.

- **Never dump attributes or full page state there** — no `aria-label`/`title`/`value` listings,
  no `innerHTML`, no whole-page accessibility snapshot. Locate controls by role and position, and
  return booleans or counts rather than element text.
- **Route the secret around yourself, not through yourself:** use the page's own copy control,
  then have the human paste it into the password manager. A value that never enters the
  transcript cannot leak from it later.
- Identifiers meant to be public — client IDs, publishable keys, account emails — are fine to
  state. The rule is about anything that authenticates.
- **If a secret does land in the transcript, say so immediately and rotate it.** Both halves
  matter: a leak you don't mention is a leak the human can't fix, and a rotation that skips the
  old secret's deletion leaves it live.
- Same care in the other direction: don't type credentials into a page on someone's behalf, and
  don't ask for a password to do it. Hand the human the tab.

## Prose and editorial content

- Run any hand- or LLM-authored prose through the `humanizer` skill before it ships: site copy,
  blog posts, release notes, outreach, free-text form answers, cover letters.
- **No em/en dashes (`—` / `–`) in shipped prose.**
- **No small muted explainer captions in UI.** No eyebrow labels above headings ("GET STARTED",
  "DOCUMENTATION"), no hint lines under a chart ("hue = type · area = size"), no interaction
  instructions ("drag to pan", "click a cell to select"). Real input labels stay; the rest goes —
  captioning every element is an obvious AI tell. If something needs a caption to be understood,
  fix the design instead.
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
