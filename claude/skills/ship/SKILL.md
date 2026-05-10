---
name: ship
description: Close out a feature — commit staged changes with issue reference, push, open MR with Closes #id, link milestone, and tick remaining issue checklist items. USE WHEN user types /ship, says "ship this", "open an MR", "close out the feature", or "I'm done".
user-invocable: true
allowed-tools:
  - Bash
  - AskUserQuestion
---

# /ship

You are closing out a feature task. This skill stages, commits, pushes, opens an MR, links a milestone, and updates the issue checklist.

## Context

- **Working dir:** !`pwd`
- **Origin remote:** !`git remote get-url origin 2>/dev/null || echo "(no origin)"`
- **Current branch:** !`git branch --show-current`
- **Git status:** !`git status --short`

## Workflow

### 1. Identify the issue

Ask the user for the GitLab issue number this work closes, if not already known (e.g. `/ship 12`).

Fetch it to confirm it's open and get its title/milestone:

```bash
glab issue view <id>
```

---

### 2. Review uncommitted changes

```bash
git diff --stat
git status --short
```

If there are unstaged changes the user hasn't mentioned, ask whether to include them before proceeding.

---

### 3. Commit

Generate a commit message following Conventional Commits format (`feat:`, `fix:`, `chore:`, etc.). Include the issue reference:

```
feat: <short description> (#<id>)
```

Only add a body if the "why" is non-obvious. Subject ≤ 50 chars.

Stage and commit:

```bash
git add <relevant files>
git commit -m "$(cat <<'EOF'
feat: <description> (#<id>)
EOF
)"
```

If nothing to commit, skip this step.

---

### 4. Sync main

Fetch and merge the latest `main` into the current branch before pushing, so the MR has no divergence:

```bash
git fetch origin main
git merge origin/main
```

If `git merge` exits non-zero (conflicts), **stop immediately**. Report the conflicting files verbatim and ask the user to resolve them. Do not push until the merge is clean and committed.

If the merge is clean (fast-forward or auto-resolved), commit the merge result if git didn't already (i.e. `git status` shows unmerged paths — stage and commit). Then proceed.

---

### 5. Push

```bash
git push -u origin "$(git branch --show-current)"
```

---

### 6. Open MR

Get URL-encoded project path:

```bash
glab repo view --output json | jq -r '.full_path' | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))"
```

Create the MR. Title comes from the issue title. Description **must** include `Closes #<id>`:

```bash
glab mr create \
  --title "<issue title>" \
  --description "$(cat <<'EOF'
## Summary
- <bullet summary of what changed>

## Test plan
- [ ] <key thing to verify>

Closes #<id>
EOF
)" \
  --target-branch main
```

Print the MR URL.

---

### 7. Link milestone

Get the MR iid:

```bash
MR_IID=$(glab mr list --source-branch "$(git branch --show-current)" --output json | jq -r '.[0].iid')
```

Get milestone id from the issue (if it had one), or ask the user. Then link:

```bash
ENCODED_PATH=<encoded-path from step 5>
glab api "projects/$ENCODED_PATH/merge_requests/$MR_IID" \
  --method PUT \
  -f milestone_id=<milestone_id>
```

Skip if no milestone applies.

---

### 8. Tick remaining checklist items

Get the current issue description:

```bash
glab api "projects/$ENCODED_PATH/issues/<id>" | jq -r '.description'
```

Tick any completed sub-tasks that aren't already checked (`- [ ]` → `- [x]`). Update:

```bash
glab issue update <id> --description "$(cat <<'EOF'
<updated description with all done items checked>
EOF
)"
```

---

### 9. Recap

Print:
- Commit SHA
- MR URL
- Issue # and current state
- Any checklist items still open (not yet done)

## Hard rules

- MR description **must** contain `Closes #<id>` in the body — not just the title.
- Never push to `main` directly.
- Do NOT override `XDG_CONFIG_HOME` when calling `glab`.
- Milestone linking uses `glab api` — `glab mr create` does not expose `--milestone-id`.
- On any `glab` error, surface it verbatim and stop.
