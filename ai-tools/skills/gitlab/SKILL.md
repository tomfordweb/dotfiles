---
name: gitlab
description: Interact with any GitLab repository following Tom's established workflow — creating issues, updating checklists during implementation, opening MRs with Closes #id, linking milestones, and closing issues. USE WHEN user types /gitlab, says "create a GitLab issue", "open an MR", "update the issue checklist", "link milestone", "list issues", starts feature work in a GitLab repo, or asks to audit/fix open MRs.
user-invocable: true
allowed-tools:
  - Bash
  - AskUserQuestion
---

# /gitlab

You are managing GitLab issues, milestones, and merge requests for the current repository. Detect everything from the working tree — never hard-code project paths, IDs, or branch names.

## Context

- **Working dir:** !`pwd`
- **Origin remote:** !`git remote get-url origin 2>/dev/null || echo "(no origin)"`
- **Current branch:** !`git branch --show-current 2>/dev/null || echo "(no branch)"`

## Setup — run once per invocation

Verify `glab` is authenticated before any operation:

```bash
glab auth status
```

If auth is missing, stop and tell the user to run `! glab auth login` in the Claude Code prompt.

**Critical:** Do NOT override `XDG_CONFIG_HOME`. Call `glab` directly — the config lives in the user's XDG base dir and overriding it breaks auth.

Get the URL-encoded project path (needed for `glab api` calls):

```bash
glab repo view --output json | jq -r '.full_path' | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))"
```

Store this as `<encoded-path>` for API calls below.

---

## Operations

The user's request determines which operation to run. If ambiguous, ask with `AskUserQuestion`.

---

### List issues

```bash
glab issue list                        # all open issues
glab issue list --label now            # priority work only
glab issue list --label medium-term
glab issue list --milestone <title>
```

Print each issue's id, title, labels, and milestone. Highlight `now`-labeled issues.

---

### View issue

```bash
glab issue view <id>
```

Read the full description including any sub-task checklist. Surface: title, labels, milestone, description, open/closed state.

---

### Create issue

Ask the user (via `AskUserQuestion`) for:
- Title
- Description / acceptance criteria (include a markdown checklist if the issue has sub-tasks)
- Label(s): `now`, `medium-term`, `deferred`, `stage-a`, `stage-b`, `stage-c`
- Milestone (list with `glab api projects/<encoded-path>/milestones` first)

Then:

```bash
glab issue create \
  --title "<title>" \
  --description "<description>" \
  --label "<label>" \
  --milestone "<milestone-title>"
```

Print the created issue URL.

---

### Update issue (tick checklist sub-tasks)

Get current description first:

```bash
glab api projects/<encoded-path>/issues/<id> | jq -r '.description'
```

Tick the completed items in the markdown (`- [ ]` → `- [x]`), then:

```bash
glab issue update <id> --description "$(cat <<'EOF'
<updated description>
EOF
)"
```

Do this whenever a sub-task is completed during implementation — don't batch at the end.

---

### Close issue

```bash
glab issue close <id>
```

Use this after confirming the linked MR was merged and the issue did **not** auto-close via `Closes #id`.

---

### List milestones

```bash
glab api projects/<encoded-path>/milestones | jq '.[] | {id, iid, title, state}'
```

Known milestones for Tom's tattoo project:
- `1` = Phase 1 Growth Infrastructure
- `2` = Phase 2 Scale
- `3` = Backlog

(These may differ in other projects — always fetch live.)

---

### Create milestone

```bash
glab api projects/<encoded-path>/milestones \
  --method POST \
  -f title="<title>" \
  -f description="<description>"
```

---

### Open merge request

Ask the user for:
- Issue number(s) this MR closes (for `Closes #id` footer)
- MR title (default: branch name prettified)
- Additional description

Then:

```bash
glab mr create \
  --title "<title>" \
  --description "$(cat <<'EOF'
## Summary
<bullet points>

## Test plan
<checklist>

Closes #<id>
EOF
)" \
  --target-branch main
```

After creating, link the milestone:

```bash
MR_IID=$(glab mr list --source-branch "$(git branch --show-current)" --output json | jq -r '.[0].iid')
glab api projects/<encoded-path>/merge_requests/$MR_IID \
  --method PUT \
  -f milestone_id=<milestone_id>
```

Print the MR URL.

---

### Link milestone to existing MR

```bash
glab api projects/<encoded-path>/merge_requests/<mr_iid> \
  --method PUT \
  -f milestone_id=<milestone_id>
```

---

### Audit open MRs — run automatically after any MR operation

**Trigger:** run this audit automatically at the end of every invocation that creates, lists, or otherwise touches MRs. Also run when the user says "audit MRs", "link milestones", "go through open PRs/MRs", or similar.

```bash
# 1. Fetch milestones so we can map names → IDs
glab api projects/<encoded-path>/milestones | jq '.[] | {id, iid, title}'

# 2. Fetch all open MRs
glab api "projects/<encoded-path>/merge_requests?state=opened" \
  | jq '.[] | {iid, title, source_branch, milestone: (.milestone.title // null), description}'
```

For each MR, check two things:

**A. Milestone missing?**
- Look for a `Closes #N` reference in the MR description.
- If found, fetch that issue: `glab api projects/<encoded-path>/issues/<N> | jq '{milestone, labels}'`
- Use the issue's milestone if set; otherwise infer from labels (`now`/`stage-*` → Phase 1, `medium-term` → Phase 2, `deferred` → Backlog).
- If no issue reference exists, default to the Phase 1 milestone unless the work is clearly longer-term.
- Set via `glab api projects/<encoded-path>/merge_requests/<iid> --method PUT -f milestone_id=<id>`

**B. Issue link missing (no `Closes #N` in description)?**
- Scan title and branch name for `#N` patterns.
- If an issue is identifiable but not in the description, update the MR description to append `\n\nCloses #N`:
  ```bash
  CURRENT=$(glab api projects/<encoded-path>/merge_requests/<iid> | jq -r '.description')
  glab api projects/<encoded-path>/merge_requests/<iid> \
    --method PUT \
    --field "description=${CURRENT}

Closes #<N>"
  ```
- If no issue can be determined (pure maintenance/chore), skip — do not fabricate an issue link.

Print a summary table of what was fixed vs what was already correct.

---

## Feature work workflow

When the user is **starting** a feature task, follow this sequence automatically:

1. **Pick the issue**
   ```bash
   glab issue list --label now
   ```
   If multiple `now` issues exist, ask the user which to tackle.

2. **Read the scope**
   ```bash
   glab issue view <id>
   ```

3. **During implementation** — tick each sub-task as it's completed:
   ```bash
   glab issue update <id> --description "<updated markdown with [x]>"
   ```

4. **Commit messages** — reference the issue: `feat: add booking flow (#<id>)`

5. **Open MR** — always include `Closes #<id>` in the description body (not just the title). Link the milestone.

6. **After merge** — confirm the issue auto-closed. If not:
   ```bash
   glab issue close <id>
   ```

---

## Hard rules

- **Never push directly to `main`.** Always open an MR.
- Every MR description **must** contain `Closes #<id>` so GitLab auto-closes the issue on merge (skip only for pure maintenance with no linked issue).
- **Every MR must have a milestone set.** Linking a milestone is not optional — do it immediately after `glab mr create` using `glab api ... --method PUT -f milestone_id=<id>`.
- **Run the MR audit automatically** after any invocation that creates or lists MRs. Never leave the session without verifying all open MRs have milestones and issue links.
- Do NOT override `XDG_CONFIG_HOME` when calling `glab`.
- Milestone linking must use `glab api` (the `glab mr create` command does not expose `--milestone-id`).
- On any `glab` error, surface it verbatim. Do not silently retry.
- Detect project path, default branch, and milestone IDs from live API calls — never hard-code them.
