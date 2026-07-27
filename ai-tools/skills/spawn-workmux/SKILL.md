---
name: spawn-workmux
description: Spawn parallel workmux worktrees for a project — one per logical feature area — without opening panes or starting empty agent sessions. Reads plan.md for the worktree list, writes per-worktree prompt files, creates worktrees in background with no pane commands, and opens a GitLab MR for each branch. Trigger when user says "spawn worktrees", "set up parallel agents", "delegate to worktrees", "start all worktrees", or invokes /spawn-workmux.
disable-model-invocation: true
allowed-tools: Bash, Write, Read
---

# spawn-workmux

Dispatch a project across parallel workmux worktrees. Each worktree gets an
isolated branch, a detailed prompt file for later use, no live Claude pane by
default, and a GitLab MR opened automatically.

$ARGUMENTS

## You are a dispatcher, not an implementer

**HARD RULE:** Do NOT explore, read, grep, or search the codebase beyond reading
`plan.md`. Do NOT implement anything. Your only job: write prompt files, run
`workmux add --background --no-pane-cmds`, and open MRs. Worktree agents do all
the work when explicitly started later.

---

## Step 1 — Read plan.md

Read `plan.md` at the project root. Find the **Worktree Responsibilities** section
(table or list). Each row defines one worktree:
- Branch name (e.g., `feat/nx-workspace`)
- What it builds

If `plan.md` does not exist or has no Worktree Responsibilities section, ask the
user to list the features/areas to parallelize. Do NOT guess.

---

## Step 2 — Write ALL prompt files first (in parallel)

For each worktree entry, write a temp prompt file. **Start every prompt with
`/plan`** so Claude enters plan mode immediately on spawn.

The prompt must be **fully self-contained** — the spawned agent has no
conversation history. Include:
- `/plan` on the first line (triggers plan mode)
- What to build (all files, exact paths)
- Key architectural decisions already made (agent must not relitigate them)
- Absolute path to `plan.md` for broader context
- Packages/libraries to use (no choosing allowed)
- How to commit when done

Prompt file structure:
```
/plan

Read the full architecture context at /absolute/path/to/plan.md

## Your task: <worktree-name>

Build the following files in this worktree:

### <file-path>
<exact content or description>

## Rules
- <key decision 1>
- <key decision 2>

## When done
git add -A && git commit -m "feat(<scope>): <description>"
```

Write ALL temp files before running any workmux commands:
```bash
tmpfile=$(mktemp).md
cat > "$tmpfile" << 'EOF'
/plan

Read the full architecture at /absolute/path/plan.md

## Your task: nx-workspace
...
EOF
echo "$tmpfile"
```

---

## Step 3 — Push each branch and open GitLab MR

Before creating worktrees, push each branch to origin and open a Draft MR so
work is tracked from the start. The MR is a Draft so it cannot be accidentally
merged before the agent finishes.

For each branch:
```bash
# Push branch (create it on remote)
git push origin HEAD:refs/heads/<branch-name> 2>/dev/null || true

# Open Draft MR via glab CLI
glab mr create \
  --source-branch <branch-name> \
  --target-branch main \
  --title "Draft: <what this worktree builds>" \
  --description "Automated worktree branch. Agent working in plan mode. See plan.md for full context." \
  --draft \
  --yes 2>/dev/null || true
```

If `glab` is not installed, fall back to printing the GitLab UI URL:
```
https://<remote-host>/<namespace>/<repo>/-/merge_requests/new?merge_request[source_branch]=<branch>
```

Derive the GitLab remote URL from:
```bash
git remote get-url origin
```

---

## Step 4 — Create all worktrees (in parallel, after all files written)

```bash
workmux add feat/nx-workspace --background --no-pane-cmds -P /tmp/tmp.abc123.md
workmux add feat/ui-layout-lib --background --no-pane-cmds -P /tmp/tmp.def456.md
# etc.
```

Flags:
- `--background` — run in background; don't switch to the new window
- `--no-pane-cmds` — do not run pane startup commands or create an empty agent session
- `-P <file>` — inject prompt file as Claude's first message (triggers `/plan`)
- `-o` — add this flag if the worktree already exists (idempotent)

Run from the **current directory** (the main worktree root). Do NOT `cd` elsewhere.

---

## Step 5 — Report

After all commands complete:
```bash
workmux list
```

Report to user:
- Which worktrees were created (branch → tmux window)
- Which GitLab MRs were opened (URL for each)
- No agent pane was started. Use the saved prompt file when explicitly starting an agent later.
- Tip: `workmux dashboard` to monitor all agents at once

---

## Later agent startup

Because `--no-pane-cmds` is mandatory for agent-created sessions, no Claude
session starts during `workmux add`. If the user explicitly asks to start the
agent later, open the worktree/window and send the saved prompt file then.

Use `workmux status` to track worktrees that already have active agents. Do not
run `workmux sidebar` unless the user explicitly asks for the sidebar.

---

## Handle derivation reference

| Branch | Handle |
|--------|--------|
| `feat/nx-workspace` | `feat-nx-workspace` |
| `feat/ui-layout-lib` | `feat-ui-layout-lib` |

Slashes → hyphens. Special chars stripped.

---

## Merge workflow (after agents finish)

Each agent commits on its branch. MR already exists in GitLab (Draft).
User un-drafts and merges via GitLab UI, or:
```bash
glab mr merge <mr-id> --rebase --remove-source-branch
```

Or use `/merge` skill inside each worktree window to merge via workmux.

---

## Your task is COMPLETE once worktrees are created and MRs are opened

Do NOT implement anything. Do NOT wait for agents. Report and exit.
