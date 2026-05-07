---
name: gitlab
description: Interact with any GitLab repository following Tom's established workflow — creating issues, updating checklists during implementation, opening MRs with Closes #id, linking milestones, and closing issues. USE WHEN user types /gitlab, says "create a GitLab issue", "open an MR", "update the issue checklist", "link milestone", "list issues", or starts feature work in a GitLab repo.
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
- Every MR description **must** contain `Closes #<id>` so GitLab auto-closes the issue on merge.
- Do NOT override `XDG_CONFIG_HOME` when calling `glab`.
- Milestone linking must use `glab api` (the `glab mr create` command does not expose `--milestone-id`).
- On any `glab` error, surface it verbatim. Do not silently retry.
- Detect project path, default branch, and milestone IDs from live API calls — never hard-code them.
