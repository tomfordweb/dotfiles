---
name: compete
description: Competitive parallel implementation — several agents attack the same spec in separate worktrees under different architectural constraints; the repo's gate picks the winner. USE WHEN the user invokes /compete, asks for "parallel implementations", "race implementations", or a feature is gnarly enough that the right approach is genuinely unclear.
---

# compete — race N implementations, let the gate referee

Wrong approaches are cheapest when they die in parallel. This flow only pays off when
the approach is genuinely uncertain — for routine features, implement directly instead.

## Process

1. **Tests are the contract, written first.** On a shared base branch, write the
   acceptance criteria as executable tests ONLY — unit tests plus an e2e spec where the
   feature is user-facing. No implementation code. Commit to the base branch. Print the
   test list to the user before proceeding.
2. **Create 3 worktrees** off the base branch via workmux (session mode, as always):
   `workmux add --mode session --background --no-pane-cmds --base <base-branch> <feature>-attempt-{a,b,c}`
3. **Spawn one agent per worktree** with the SAME tests but a DIFFERENT architectural
   constraint. Default trio (adjust to the feature):
   - A: minimal diff — smallest change to existing code that passes
   - B: extract/extend a shared library first, then consume it
   - C: restructure — new module/route boundaries, composition-first
4. **Rules for every attempt**: iterate until the repo's full gate is green (targeted
   checks while iterating, per the gate rules); MUST NOT modify test files; report
   "structurally blocked + why" instead of weakening anything.
5. **Judge on facts**: table of lines changed, files touched, new dependencies, test
   runtime, subjective readability note. Recommend one winner; graft any clearly better
   ideas from the losers.
6. **Land the winner** as the MR; `workmux rm` the losing worktrees.

## Guardrails

- Tests never get weakened to let an attempt pass — the contract outranks every attempt.
- All batch-scope rules apply: print the worktree/branch list before creating it.
- This burns ~3x tokens; say so when suggesting it unprompted.
