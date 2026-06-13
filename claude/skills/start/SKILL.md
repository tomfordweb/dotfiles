---
name: start
description: Start feature work the right way — check GitLab issues, pick one, enter an isolated worktree, and surface the issue scope. USE WHEN user types /start, says "start working on", "pick up an issue", or "begin a feature".
user-invocable: true
allowed-tools:
  - Bash
  - AskUserQuestion
  - EnterWorktree
---

# /start

You are starting a feature task for a GitLab project. Follow this sequence exactly — do not skip steps.

## Context

- **Working dir:** !`pwd`
- **Origin remote:** !`git remote get-url origin 2>/dev/null || echo "(no origin)"`
- **Current branch:** !`git branch --show-current`

## Workflow

### 1. Check `glab` auth

```bash
glab auth status
```

If not authenticated, stop and tell the user to run `! glab auth login`.

Do NOT override `XDG_CONFIG_HOME` when calling `glab`.

---

### 2. List priority issues

```bash
glab issue list --label now
```

If the user already named an issue (e.g. `/start 12`), skip this step and go to step 3 with that ID.

If multiple `now` issues exist, ask the user which to tackle via `AskUserQuestion`. Show id + title for each option.

If no `now` issues, show all open issues and ask which to pick.

---

### 3. Read the issue scope

```bash
glab issue view <id>
```

Print the full title, description (including any sub-task checklist), labels, and milestone. This is the source of truth for scope — don't proceed until you've read it.

---

### 4. Enter a worktree

Use the `EnterWorktree` tool to create an isolated git worktree for this work. Name the branch after the issue: e.g. `feat/issue-<id>-short-slug` where the slug is 2-4 words from the issue title, kebab-cased.

Do NOT work on `main` or in the primary working tree.

---

### 5. Confirm and surface context

Tell the user:
- Issue # and title
- Worktree branch name
- The acceptance criteria / sub-tasks from the issue description (formatted as a checklist)
- The milestone (if any)
- The worktree's dev URL — run `wtport` in the new worktree and report `http://localhost:<port>`. Dev servers launch via `/dev` (per-worktree deterministic port; never the shared default).

Then stop — the user takes it from here. Do not begin implementation.

## Hard rules

- Always enter a worktree before any code changes.
- Never push directly to `main`.
- Do not override `XDG_CONFIG_HOME`.
- If `glab issue view` shows the issue is already closed, stop and tell the user.
