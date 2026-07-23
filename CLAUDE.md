# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal dotfiles + NixOS flake for a Hyprland desktop environment.
`config/` is the source of truth for hand-managed app configs; `bin/` goes
on `$PATH`. Two apply mechanisms create the same `~/.config/<app>` symlinks
into the repo:

- **NixOS hosts** (minerva desktop, t480 laptop): home-manager
  (`nixos/home/dotfiles.nix`, `mkOutOfStoreSymlink`). Packages, shell, and
  nvim runtime deps are all declared under `nixos/` — see `nixos/README.md`
  for the module map and install/rebuild docs.
- **Non-nix hosts** (work Ubuntu/Debian, mac): `install/bootstrap.sh`
  (`--minimal` for the dev core only). Keep its app list in sync with
  `dotfiles.nix`.

Because both are symlinks into the repo, config edits are live — no rebuild.
Rebuilds (`sudo nixos-rebuild switch --flake ./nixos#<host>`) are only
needed for changes under `nixos/`.

## Setup

```bash
git clone git@github.com:tomfordweb/dotfiles.git ~/code/tomfordweb/dotfiles
cd dotfiles && git submodule update --init
sh install/bootstrap.sh   # non-nix hosts only; NixOS hosts use the flake
```

The repo must live at `~/code/tomfordweb/dotfiles` — the home-manager
symlinks bake in that absolute path.

## macOS

The tmux/nvim config is also used on macOS (via `bootstrap.sh --minimal`). macOS
ships an ancient ncurses (5.7) whose `tmux-256color` terminfo entry is broken, so
inside tmux nvim misreads key/bracketed-paste capabilities — pasting injects stray
control chars and registers stop working. Run once per Mac:

```bash
sh install/macos-terminfo.sh   # compiles a modern terminfo into ~/.terminfo
tmux kill-server               # restart so nvim picks up the new entry
```

This keeps `default-terminal "tmux-256color"` (set in `config/tmux/tmux.conf`)
working instead of downgrading to `screen-256color`. Linux is unaffected — its
ncurses already ships a correct entry.

## Submodules

- `config/nvim` → [`tomfordweb/neotom`](https://github.com/tomfordweb/neotom) — Neovim config (has its own CLAUDE.md)
- `config/waybar/custom/nvidia-smi` → waybar GPU module
- `docs` → [`tomfordweb/wiki`](https://github.com/tomfordweb/wiki) — personal documentation

Changes to these directories must be committed in their own repos, not this one.

## Styling (Sass)

Waybar and Wofi styles are written in SCSS and compiled to CSS. To watch and compile:

```bash
./install/rice.sh
```

This runs `sass --watch` targeting:
- `config/waybar/theme.scss` → `config/waybar/style.css`
- `config/wofi/theme.scss` → `config/wofi/style.css`

Shared variables live in `rice/rice.scss` (imported with `-I ./rice`). Never edit the `.css` files directly — they are generated output.

## Rice vs Pro mode

`bin/rice-mode` switches the desktop between two looks. Default (and the
assumed-correct state) is **rice**: shuffling wallpapers every 300s, glass
blur, neon accents. **pro** is for screen sharing: one pinned static image,
flat opaque waybar/eww, blur + shadows + window transparency off.

```bash
rice-mode set-image ~/Pictures/desk.jpg   # one-time, per machine
rice-mode toggle                          # or SUPER+SHIFT+P, or the waybar chip
rice-mode get                             # rice|pro
```

State lives in `$XDG_STATE_HOME/rice/mode`; the static image is a machine-local
symlink at `$XDG_CONFIG_HOME/rice/static-wallpaper` (never in the repo).
Moving parts: `config/waybar/theme-pro.scss` → `style-pro.css` (waybar is
restarted with `-s` on toggle), the `flat` class eww picks up from its
`rice-mode` poll, `hyprctl keyword` decoration overrides, and
`hyprwallpapers_loop` skipping its tick while mode = pro. The rice-side
`hyprctl keyword` values in `rice-mode` mirror `decoration{}` in
`hyprland.conf` — change both together.

## Hyprland

`config/hypr/hyprland.conf` sources a hostname-specific config at startup:

```
config/hypr/configs/<hostname>.conf
```

The gitignored symlink `config/hypr/custom-by-hostname.conf` is maintained by `bin/hypr-host-config` (run from `exec-once`): relative symlink to `configs/<hostname>.conf`, or an empty placeholder on hosts without one; it reloads Hyprland once when the file changed (first launch on a new machine logs a one-time "globbing found no match" before the script self-heals). Per-machine configs (currently just `minerva.conf` — the desktop's monitor layout) live in `config/hypr/configs/`. `env.conf` is also gitignored (holds machine-local env vars).

Additionally, `hyprland.conf` sources `~/.config/hypr-local/*.conf` for machine-local overrides — deliberately OUTSIDE `~/.config/hypr`, which is a symlink into the repo on home-manager hosts. NixOS VMs drop a `$mainMod = ALT` override there; a missing dir is silently skipped.

## Waybar Development

```bash
GTK_DEBUG=interactive waybar   # interactive GTK inspector
sass --watch config/waybar/theme.scss config/waybar/style.css
```

Custom modules are in `config/waybar/custom/`: `docker-status` and the `nvidia-smi` submodule (plain `nvidia-smi` CSV queries + `jq` — no xml2json). Requires "Big Blue nerd plus" Nerd Font.

## NixOS

All provisioning lives in `nixos/` (flake: `vm`, `laptop`, `minerva`,
`minerva-live` outputs). `nixos/README.md` is the operating manual: install
walkthroughs (LUKS on both real hosts), rebuild cheatsheet, module map,
troubleshooting. Nvim's LSPs/formatters/tree-sitter come from
`nixos/home/neovim.nix` (wrapped nvim), NOT Mason. Host segmentation:
`modules/ai.nix` (ollama-cuda, beads) is minerva-only; `modules/laptop.nix`
(brightnessctl, power daemons) is t480-only. tmux plugins init with
`<C-a I>` inside tmux (tpm is cloned by home-manager activation).


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:7510c1e2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
