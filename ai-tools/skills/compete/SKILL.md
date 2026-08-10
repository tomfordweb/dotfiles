---
name: compete
description: Competitive parallel problem-solving. Default: 3 agents write independent design proposals, a judge picks, one agent implements the winner (~1.3x tokens). /compete --build: 3 agents each FULLY implement in separate worktrees and the repo's gate picks the winner (~3x tokens). USE WHEN the user invokes /compete, asks for "parallel implementations", "race implementations", "competing designs", or the right approach is genuinely unclear.
---

# compete — race approaches, referee objectively

Wrong approaches are cheapest when they die in parallel. Two modes; `--design` is the
default, `--build` is the full race. Only reach for either when the approach is genuinely
uncertain — routine features get implemented directly.

## Default mode: design-off (~1.3x tokens)

1. **Frame the contract.** Write the acceptance criteria as a short numbered list (what
   must work, what must not break, constraints). Print it.
2. **Spawn 3 proposal agents** (read-only — they explore the repo but change nothing).
   Same contract, different architectural lens:
   - A: minimal diff — smallest change to existing code
   - B: extract/extend a shared library first, then consume it
   - C: restructure — new module/route boundaries, composition-first
   Each returns: approach summary, files it would touch, new deps, risks, est. size.
3. **Judge on the returned proposals**: comparison table, pick a winner, graft clearly
   better ideas from the losers. State WHY in two sentences.
4. **Implement the winner once**, normal workflow (worktree, targeted checks, gate at
   push). If implementation reveals the chosen design is structurally wrong, say so and
   fall back to the runner-up — don't force it.

Trade-off to keep in mind: the judge picks on plausibility, not proof. If the winner
keeps hitting reality mid-implementation, recommend escalating to `--build`.

## --build mode: full implementation race (~3x tokens)

1. **Tests are the contract, written first.** On a shared base branch, write the
   acceptance criteria as executable tests ONLY — unit tests plus an e2e spec where the
   feature is user-facing. No implementation code. Commit to the base branch. Print the
   test list before proceeding.
2. **Create 3 worktrees** off the base branch via workmux (session mode, as always):
   `workmux add --mode session --background --no-pane-cmds --base <base-branch> <feature>-attempt-{a,b,c}`
3. **Spawn one agent per worktree** with the SAME tests but a DIFFERENT constraint (the
   A/B/C lenses above, adjusted to the feature).
4. **Rules for every attempt**: iterate until the repo's full gate is green (targeted
   checks while iterating, per the gate rules); MUST NOT modify test files; report
   "structurally blocked + why" instead of weakening anything.
5. **Judge on facts**: table of lines changed, files touched, new dependencies, test
   runtime, subjective readability note. Recommend one winner; graft any clearly better
   ideas from the losers.
6. **Land the winner** as the MR; `workmux rm` the losing worktrees.

## Guardrails (both modes)

- The contract (criteria or tests) never gets weakened to let an attempt win.
- All batch-scope rules apply: print the agent/worktree list before spawning.
- State the mode and its token cost when suggesting compete unprompted; `--build` only
  when the user asked for it or approved the escalation.
