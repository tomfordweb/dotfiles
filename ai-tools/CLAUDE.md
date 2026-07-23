# Global CLAUDE.md (system-level, all projects)

## Git — merging approved PRs/MRs

Agents MAY merge any PR/MR that is **approved**. Approval is the gate — once a
human (or required reviewer) has approved it, merging is authorized; you do not
need a separate per-merge confirmation. Applies to GitHub PRs (`gh pr merge`) and
GitLab MRs (`glab mr merge`), including merges into a protected default branch.

- Verify the **approved** state before merging (`gh pr view` / `glab mr view`);
  never merge an unapproved or changes-requested PR/MR.
- Respect the repo's merge strategy (rebase/squash/merge) and any green-CI gate.
- After merging into the default branch, rebase/refresh dependent working branches.
- A project CLAUDE.md may still narrow this (specific overrides general); if a repo
  explicitly bans agent merges, follow the repo. Otherwise this rule holds.

## Git — general workflow

- **PR/MR-only.** Never push directly to a protected default branch; land changes
  through a reviewed PR/MR. Conventional Commits for commit messages.
- **Rebase is the preferred integration.** Plain `git rebase` (refresh a branch
  onto the default branch, tidy history, rebase a dependent branch after a merge)
  is fine without prompting — it's local and reflog-recoverable. Prefer rebase
  merges over merge-commits/squash where the repo allows it.
- **Confirm before genuinely destructive rewrites — never autonomously:**
  force-push, `git reset --hard`, `git filter-branch`, amending a commit that's
  already been pushed.
- **No AI attribution in commits.** No `Co-Authored-By: Claude` trailer, no
  "Generated with Claude Code" line, no robot emoji — the work belongs to whoever
  is paying for it, not the assistant.
- **Task tracking + persistent memory belong in a dedicated tool**, not ad-hoc
  todo comments or scratch files — use whatever issue tracker / memory system the
  repo already has wired up rather than inventing a parallel one.

## Tooling

- Prefer a repo's CLI (`gh`, `glab`, etc.) over a web UI for repo/issue/PR/MR
  operations — web-UI editing is more prone to mangling commits or losing state
  than a scripted CLI call.
- Keep responses concise when there's an output-token budget in play; break long
  work into checkpoints rather than one giant reply.

## Infra changes

- Inspect real current state first; make scoped, reversible changes.
- State the blast radius before any firewall / DB / migration edit.

## Playwright MCP — browser setup & troubleshooting

Managed by home-manager (`dotfiles/nixos/home/ai-tools.nix`): the browser comes
from nixpkgs' `pkgs.playwright-driver.browsers` (an immutable `/nix/store` path,
not a mutable `~/.cache/ms-playwright` install), and `PLAYWRIGHT_CHROMIUM_EXECUTABLE`
is exported at shell login by globbing the versioned `chromium-<rev>` dir under it
— so MCP configs reference the env var, never a hand-chased version-suffixed path.

playwright (and context7) are launched `node`-direct (NOT `npx`, which costs
~2s/launch) from a shared pinned install home-manager maintains — no per-tool
duplication, no stray `npx @playwright/mcp@latest` downloads.

### Why not the alternatives
- Default (no flag) = the `chrome` channel → needs system Google Chrome, which
  usually isn't installed → fails.
- A distro-packaged chromium (e.g. a snap build) is commonly sandboxed in a way
  that blocks Playwright's custom user-data-dir/flags — symlinking it into the
  cache does not work around that.
- `--browser chromium` triggers the MCP server's own auto-download, which is
  flaky in a sandboxed/offline environment — avoid it; let nixpkgs own the binary.

### Verify working
Navigate to `https://example.com` via the playwright MCP tools; expect title
"Example Domain".

## workmux — git worktrees + tmux + Claude agents

`workmux` (`~/.local/bin/workmux`) orchestrates git worktrees, tmux windows, and
Claude Code agents. One worktree = one branch = one tmux window = one agent.
Config: project `.workmux.yaml` overrides global `~/.config/workmux/config.yaml`
(`workmux config edit` / `config reference`).

### Worktree lifecycle
```bash
workmux add <branch>            # new worktree + tmux window + agent
workmux add -A -p "fix X"       # -A auto-names branch from prompt via LLM
workmux add --pr 123            # check out a PR into a worktree
workmux add --base main feat-x  # branch from an explicit base
workmux ls                      # list worktrees   (alias: list)
workmux path <name>             # print a worktree's filesystem path
workmux open <name>             # reopen tmux window for existing worktree
workmux merge [name] --rebase   # merge branch then clean up worktree+window
workmux rm <name>               # remove worktree+window+branch, NO merge
workmux resurrect               # restore windows after tmux/computer crash
```
- `add` runs `post_create` hooks (e.g. `pnpm install`) and file ops (`copy`/`symlink`) from `.workmux.yaml`. Skip with `-H` / `-F` / `-C`.
- `merge` defaults to `main_branch` from config; `--into` overrides. `--squash`, `--rebase`, `-k`/`--keep` available.

### Agent orchestration (parallel Claude agents across worktrees)
```bash
workmux send <name> "do the thing"   # send a prompt to a running agent (or stdin/--file)
workmux status [names] --json --git  # query agent status (+ git staged/unstaged/unmerged)
workmux wait <names>... --status done # block until agents reach status (--any = first one)
workmux run <name> -- <cmd>          # run a command in a worktree's window
workmux capture <name>               # capture terminal output from an agent
workmux dashboard                    # TUI of all active agents
workmux sidebar                      # toggle live agent-status sidebar in tmux
```
Cross-project handles use `project:handle` syntax in `send`/`wait`/`status`.

### Claude Code integration / setup
```bash
workmux setup            # install agent status-tracking hooks + workmux skills into Claude
workmux setup --hooks    # hooks only
workmux setup --skills   # skills only
workmux claude prune     # remove stale ~/.claude.json entries for deleted worktrees
```
- `setup` wires Claude hooks so `status`/`wait`/`dashboard` can track each agent's state (working / waiting-for-input / done).
- Run `workmux claude prune` periodically — deleted worktrees leave dangling `~/.claude.json` entries.
- `workmux docs` renders full README; `workmux changelog` shows what's new.
