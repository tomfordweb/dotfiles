# caveman overlay

Single source of truth for caveman across Claude Code, opencode, and codex is the
**pinned upstream submodule** `vendor/caveman` (`JuliusBrussee/caveman`). This
directory records the small set of **local deltas** we carry on top of it, so the
divergence is explicit and time-bounded — **not a silent fork**.

## Why an overlay instead of a fork

Our one upstream-worthy fix (the opencode plugin's real hook API) **already merged
upstream** — we had simply pinned a stale commit (v1.8.2) that predated it. Bumping
to v1.9.1 collapsed the overlay: `plugin.js` and three skills/commands are now
identical to upstream. **No upstream PR is needed.** What remains is classified:

- `local-integration` — how *we* wire caveman into opencode (inline `AGENTS.md`,
  agent `tools:` line). Not meant for upstream.
- `local-opinion` — a deliberate content choice that diverges from upstream design
  (the `skills/caveman` anti-abbreviation stance). Kept local by decision.
- `stale-regen` — we are *behind* upstream; refresh from the submodule in `ops-y2w`
  (`caveman-config.cjs`, missing #601).

Files under `identical_to_upstream` have no local delta and are sourced directly
from the submodule by the wiring (bd `ops-y2w`). On a future submodule bump, re-run
the diff (below) — anything that converges moves to `identical_to_upstream`.

## Layout

- `MANIFEST.yml` — pinned SHA, upstream PR URL, per-file deltas + identical list.
- The delta files themselves currently live at their `live_path` under
  `opencode/` (what opencode consumes today). `ops-y2w` moves the wiring
  to resolve **overlay-file-if-present, else submodule**; this catalogue is the
  authority for which is which.

## Resync procedure (bump the submodule)

```bash
cd vendor/caveman && git fetch origin && git checkout <new-sha> && cd ../..
# update pinned_sha in MANIFEST.yml, then for each delta:
#   diff <live_path> vendor/caveman/<upstream_path>
#   - merged upstream? drop the entry, delete the local copy, let wiring use submodule
#   - still differs?   re-apply/rebase the local change, keep the entry
git add vendor/caveman caveman-overlay/MANIFEST.yml
```

## Consumers

- **Claude Code** — consumes upstream **verbatim** (no delta); skills + `src/hooks`
  wired from the submodule (bd `ops-2pb`). Replaces the retired marketplace plugin.
- **opencode** — consumes overlay-else-submodule (bd `ops-y2w`).
- **codex** — `AGENTS.md` + skills from overlay/submodule; `~/.codex/rules/default.rules`
  is machine trust-state and is **never** tracked (bd `ops-c42`).
