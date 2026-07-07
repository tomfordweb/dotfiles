# dotfiles

Personal dotfiles and NixOS configuration.

`config/` is the source of truth for app configs. `~/.config/<app>` is
symlinked into it, so edits apply immediately on every machine. `bin/`
goes on `$PATH`. How the symlinks get created depends on the machine:

- **NixOS hosts** (minerva, t480): home-manager — see [`nixos/README.md`](nixos/README.md)
- **Non-nix Linux** (work): `install/bootstrap.sh`
- **mac**: `install/bootstrap.sh --minimal` plus the terminfo fix below

## Repo map

```
bin/          portable scripts (hypr-host-config, devserver, wtport, ...)
config/       app configs — hypr, waybar, wofi, tmux, ghostty, nvim*, git, ...
docs/         personal wiki (submodule)
install/      bootstrap.sh (non-nix), macos-terminfo.sh, rice.sh, docker/
nixos/        flake: NixOS hosts + home-manager (see nixos/README.md)
rice/         shared SCSS palette for waybar/wofi themes
```

`*` submodules: `config/nvim` → [neotom](https://github.com/tomfordweb/neotom),
`config/waybar/custom/nvidia-smi`, `docs` → wiki. Changes to those are
committed in their own repos.

## Setup — NixOS hosts

See [`nixos/README.md`](nixos/README.md). Everything (packages, symlinks,
PATH, shell) comes from `nixos-rebuild switch`.

## Setup — non-nix hosts (work, mac)

```bash
git clone git@github.com:tomfordweb/dotfiles.git ~/code/tomfordweb/dotfiles
cd ~/code/tomfordweb/dotfiles && git submodule update --init

sh install/bootstrap.sh            # Linux desktop (incl. hypr/waybar/wofi)
sh install/bootstrap.sh --minimal  # work box / mac: dev core only

# then add to your shell rc:
export PATH="$HOME/code/tomfordweb/dotfiles/bin:$PATH"
```

The script refuses to clobber real files — if it prints `SKIP`, move the
existing `~/.config/<app>` aside and re-run. It is idempotent.

Tools the configs expect (install via apt/brew): git, tmux, neovim,
ghostty, lazygit, ripgrep, fd, fzf, jq, starship. On NixOS these are
declared in `nixos/home/`.

### mac extras

macOS ships an ancient ncurses whose `tmux-256color` terminfo is broken
(paste garbage, dead registers in nvim inside tmux). Once per mac:

```bash
sh install/macos-terminfo.sh
tmux kill-server
```

## Claude

```bash
ln -s ~/code/tomfordweb/dotfiles/claude/settings.json ~/.claude/settings.json
ln -s ~/code/tomfordweb/dotfiles/claude/skills ~/.claude/skills
```

## Ricing

Waybar/wofi styles are SCSS, compiled to CSS (never edit the `.css`
directly):

```bash
./install/rice.sh    # sass --watch for waybar + wofi themes
```

Shared palette lives in `rice/rice.scss`.
