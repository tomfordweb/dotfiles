---
name: rebase-mrs
description: Rebase this repo's open MRs/PRs onto the default branch, resolve conflicts, merge the approved ones, and hand back a push list. USE WHEN the user invokes /rebase-mrs, asks to "rebase open MRs", "get branches current", "integrate approved MRs", or after a merge lands and dependent branches need refreshing.
---

# rebase-mrs — MR hygiene as one flow

Scope is THIS repo only (plus its worktrees). Detect the forge from the origin remote
(gitlab.com → `glab`, github.com → `gh`).

## Process

1. **Scope printout first** (batch-op rule): list open MRs — `glab mr list` /
   `gh pr list` — print the table (id, branch, title, approved?, draft?) and the count,
   then proceed. If the user named specific MRs, only those.
2. **Fetch once**: `git fetch origin`. All rebases target `origin/<default-branch>`.
3. **Per MR, oldest first**:
   - Check out the branch (its existing worktree if one exists — `workmux ls` — else a
     temporary local checkout; never touch a worktree with uncommitted changes, skip and
     report those).
   - `git rebase origin/main`. Conflicts: resolve them (mergiraf handles the structural
     ones automatically; think about the textual remainder — if a resolution requires a
     product decision, abort the rebase, mark the MR `needs-human`, move on).
   - Validate with targeted checks only for what the conflict resolution touched. The
     full gate runs at push time via the pre-push hook — do not run it here.
4. **Merge what's approved**: an MR already approved may be merged (rebase strategy
   where allowed) per the standing merge rule. After each merge into the default branch,
   restack the remaining branches onto the new tip before continuing.
5. **Hand off the pushes**: rebased branches need a force-push to update their MRs, and
   pushes need explicit per-push approval. End with a table —
   `MR | branch | rebased? | conflicts | targeted checks | merged/awaiting-push/needs-human`
   — plus the exact `git push --force-with-lease origin <branch>` list, and wait.
   On approval, run them (guard override only for these approved force-pushes:
   `CLAUDE_ALLOW_GIT_REWRITE=1 git push --force-with-lease origin <branch>`).

## Guardrails

- Never merge an unapproved or changes-requested MR. Never weaken a failing check to
  get an MR through. Draft MRs: rebase them, never merge them.
- `--force-with-lease` always, never bare `--force`.
- Beads: comment the outcome on each MR's linked issue; close issues for merged MRs.
