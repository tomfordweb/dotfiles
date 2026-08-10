---
name: later
description: Quick-file a beads task from one line of user input WITHOUT stopping current work, researching, or reading any files. Use when the user says "/later ...", "file this for later", "make a task for that", or drops an idea/bug mid-task that should be captured, not acted on. The whole point is zero context switch.
---

# later — quick-add a beads task, zero context switch

The user handed you a thought to capture. Your ONLY job is to file it and get back to
what you were doing. This skill exists because stopping to investigate the idea wrecks
the working context.

## Hard rules

- **Do NOT research it.** No file reads, no greps, no repo exploration, no "let me just
  check". You file exactly what the user said.
- **Do NOT fix it.** Even if it looks like a one-liner. Even if you know the file.
- **Do NOT stop or derail the task you were doing.** File the issue, confirm in one
  line, resume immediately.
- One shell command total.

## What to run

```bash
bd create \
  --title="<short title distilled from the user's words>" \
  --description="<the user's words, verbatim>. Filed via /later — spec this out further when free; no investigation was done at filing time." \
  --type=task --priority=3
```

- Title: the user's phrasing compressed to a line — do not reinterpret or expand it.
- Type: `bug` if the user clearly described broken behavior, else `task`.
- Priority: 3 unless the user said it's urgent.
- In a repo with app-scoped labels (andromeda): add `--label app:<name>` ONLY when the
  current working context already tells you the app — never look it up.
- If the user gave several distinct items in one message, one `bd create` per item is
  fine — still no research on any of them.

## After filing

Reply with one line: the new issue id + title. Then continue the interrupted work as if
nothing happened.
