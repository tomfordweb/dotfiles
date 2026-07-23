---
name: donereviewing
description: Read open review discussions on the current repo's open MRs/PRs and attempt to address them. USE WHEN user types /donereviewing or asks to "go through review comments". Auto-detects GitLab vs GitHub from the origin remote. Applies fixes, replies on threads where Claude disagrees, prompts when ambiguous, then pushes the branch back.
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - AskUserQuestion
---

# /donereviewing

You are addressing open code-review discussions on the current repo's merge requests / pull requests. The repo is whatever Claude is currently loaded in. Do not target any other repo. Do not assume any specific project, branch name, or host — detect everything from the working tree.

## Context

- **Working dir:** !`pwd`
- **Origin remote:** !`git remote get-url origin 2>/dev/null || echo "(no origin)"`
- **Current branch:** !`git branch --show-current 2>/dev/null || echo "(no branch)"`

## Workflow

### 1. Determine the host

Inspect the origin URL above.

- Contains `gitlab` → use `glab` for the rest of the run.
- Contains `github` → use `gh` for the rest of the run.
- Anything else (Bitbucket, plain SSH, no origin, not a git repo) → stop and tell the user the skill only supports GitLab and GitHub.

Verify the chosen CLI is authed before going further:

- `glab auth status` (GitLab)
- `gh auth status` (GitHub)

If auth is missing, stop and surface the error verbatim.

### 2. List open MRs/PRs in this repo

- **GitLab:** `glab mr list --opened --output json`
- **GitHub:** `gh pr list --state open --json number,headRefName,url,title`

If the list is empty, tell the user there's nothing to do and stop.

### 3. For each MR/PR, fetch open review discussions

For GitLab, you also need the URL-encoded project path. Get it once:
```
glab repo view --output json | jq -r '.full_path' | jq -sRr @uri
```

Then per MR:

- **GitLab:**
  ```
  glab api projects/<encoded-path>/merge_requests/<iid>/discussions --paginate
  ```
  Keep threads where `notes[0].resolvable == true` AND at least one note has `resolved == false`.
- **GitHub:** GitHub splits review comments across two endpoints — fetch both:
  ```
  gh api repos/<owner>/<repo>/pulls/<number>/comments --paginate     # inline review comments
  gh api repos/<owner>/<repo>/issues/<number>/comments --paginate    # PR-level conversation
  ```
  GitHub REST does not expose a `resolved` flag, so treat every comment as open. (You can still de-dupe replies you've already posted by checking the most recent reply author.)

If an MR/PR has no open discussions, skip it. Don't open a worktree, don't commit, don't push — just move on.

### 4. Process each open discussion

Once you've found an MR/PR that has at least one open discussion, prepare to work on it:

1. **Worktree.** Add a worktree on the MR's existing source branch (don't create a new branch):
   ```
   REPO_ROOT=$(git rev-parse --show-toplevel)
   git fetch origin <source_branch>
   git worktree add "$REPO_ROOT/.worktrees/donereviewing-<id>" <source_branch>
   cd "$REPO_ROOT/.worktrees/donereviewing-<id>"
   ```
   `<id>` is the GitLab `iid` or GitHub PR `number`. Run all subsequent commands for this MR from inside this worktree.

2. **For each open discussion in this MR, decide and act.** Read the comment body and (for inline comments) the file + line it points at, plus enough surrounding context to understand the request.

   - **Clear and reasonable** → make the edit with `Edit` / `Write`.
   - **You disagree** → post a reply on the **same thread**, on the **same backend the comment came from**:
     - GitLab (any discussion):
       ```
       glab api projects/<encoded-path>/merge_requests/<iid>/discussions/<discussion_id>/notes \
         -X POST -f "body=<reasoned response>"
       ```
     - GitHub inline review comment:
       ```
       gh api repos/<owner>/<repo>/pulls/<number>/comments/<comment_id>/replies \
         -X POST -f "body=<reasoned response>"
       ```
     - GitHub PR-level conversation comment:
       ```
       gh api repos/<owner>/<repo>/issues/<number>/comments \
         -X POST -f "body=<reasoned response, quoting the original>"
       ```
     Tone: state your disagreement, give the reasoning, ask the user to confirm or override.
   - **You're unsure what's being asked** → call `AskUserQuestion` with the comment text and 2–3 candidate interpretations. Do not guess.
   - **Never resolve the thread.** The user resolves manually after verifying the push.

### 5. Commit and push, per MR

After all open discussions for one MR have been processed:

```
git commit -am "chore: address review comments"
git push origin <source_branch>
```

The host auto-updates the MR/PR and re-runs CI.

If the commit step finds nothing to commit (everything was a reply or an `AskUserQuestion`-deferred item), skip the commit and the push for that MR.

### 6. Move to the next MR

Return to the repo root, optionally remove the worktree if it's clean:
```
cd "$REPO_ROOT"
git worktree remove ".worktrees/donereviewing-<id>"   # only if `git status` is clean
```
Repeat step 4 for the next MR with open discussions.

### 7. Recap

When the loop is done, print a single summary to the user:
- MRs/PRs touched (id + title + URL)
- Threads addressed vs threads replied-to vs threads deferred (with their discussion IDs)
- Commit SHAs pushed
- Any MRs/PRs skipped because they had no open discussions

## Hard rules

- Do not auto-resolve any review thread. Ever.
- Do not merge the default branch in unless a thread explicitly asks for it. The user runs that themselves.
- Do not push to the repo's default branch — only to each MR/PR's own source branch.
- On any error (auth missing, merge conflict, rejected push, API error), stop the entire run and surface the error verbatim. Do not retry, do not paper over.
- Detect host, default branch, and project path from the working tree — never hard-code them.
