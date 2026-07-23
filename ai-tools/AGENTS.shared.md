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
