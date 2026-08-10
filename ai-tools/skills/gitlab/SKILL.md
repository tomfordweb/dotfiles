---
name: gitlab
description: Handle explicitly requested GitLab repository operations such as merge requests, reviews, or CI inspection.
user-invocable: true
---

# GitLab operations

Use this skill only when user explicitly requests a GitLab operation.

Do not create, list, update, link, or close GitLab issues unless user explicitly asks for that exact action. Do not infer GitLab issue tracking from feature work, commits, branches, merge requests, or review work.

For merge requests, use details supplied by user. Do not add issue references, milestones, labels, or automatic audits unless requested.

Verify `glab auth status` before a GitLab operation. Do not override `XDG_CONFIG_HOME`.
