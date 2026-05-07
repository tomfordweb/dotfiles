# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal dotfiles for an Arch Linux / Hyprland desktop environment. The repo is structured so that `$XDG_CONFIG_HOME` points directly at `config/`, making all subdirectories there live config locations. `bin/` is added to `$PATH`.

## Setup

```bash
git clone git@github.com:tomfordweb/dotfiles.git ~/code/tomfordweb/dotfiles
cd dotfiles && git submodule update --init
```

Add to `~/.bashrc`:
```bash
export XDG_CONFIG_HOME="$HOME/code/tomfordweb/dotfiles/config"
export PATH="$HOME/code/tomfordweb/dotfiles/bin:$PATH"
```

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

## Hyprland

`config/hypr/hyprland.conf` sources a hostname-specific config at startup:

```
config/hypr/configs/<hostname>.conf
```

The symlink `config/hypr/custom-by-hostname.conf` is created at login and is gitignored. Per-machine configs (e.g. `charlie.conf`, `romi.conf`) live in `config/hypr/configs/`. `env.conf` is also gitignored (holds machine-local env vars).

## Waybar Development

```bash
GTK_DEBUG=interactive waybar   # interactive GTK inspector
sass --watch config/waybar/theme.scss config/waybar/style.css
```

Custom modules are in `config/waybar/custom/`: `docker-status`, `gpu-status`, `pacman-status`, and the `nvidia-smi` submodule. Requires "Big Blue nerd plus" Nerd Font and `gpsd`.

## Arch Installation

`install/arch.setup.sh` — full desktop package install (waybar, docker, ghostty, tmux, nvim via Ansible, etc.)
`install_nvim.playbook.yml` — Ansible playbook to build/install Neovim from source.

After running the setup script, initialize tmux plugins with `<C-a I>` inside a tmux session.
