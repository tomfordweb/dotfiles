---
name: ship
description: Commit, push, and open a merge request when user explicitly asks to ship work.
user-invocable: true
---

# Ship

Review changes, run required repository validation, commit scoped files, push the working branch, and open a merge request when user requests shipping.

Do not create, update, or link GitLab issues. Do not add `Closes #` text, milestones, or labels unless user explicitly requests them.

Never push directly to the default branch.
