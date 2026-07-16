#!/bin/sh
# ----------------------------------------------------------------------
# Dotfiles bootstrap for NON-NIX hosts (work Ubuntu/Debian, mac).
# ----------------------------------------------------------------------
# Creates the same per-app symlinks that home-manager creates on NixOS
# hosts (nixos/home/dotfiles.nix — KEEP THE LIST IN SYNC), pointing
# ~/.config/<app> at this repo. Idempotent; refuses to clobber real
# files/dirs — move those aside yourself, then re-run.
#
#   sh install/bootstrap.sh            # full set (Linux + Hyprland)
#   sh install/bootstrap.sh --minimal  # dev core only (work / mac)
#
# After running, add to your shell rc (and see install/macos-terminfo.sh
# on mac for the tmux terminfo fix):
#   export PATH="<repo>/bin:$PATH"

set -eu

REPO="$(cd "$(dirname "$0")/.." && pwd)"

# Dev core — safe everywhere, including mac and headless work boxes.
MINIMAL="tmux ghostty nvim lazygit gh git starship.toml workmux glab-cli thefuck"
# Wayland/Hyprland desktop extras — Linux ricing hosts only.
DESKTOP="hypr waybar wofi mako eww"

entries="$MINIMAL $DESKTOP"
[ "${1:-}" = "--minimal" ] && entries="$MINIMAL"

mkdir -p "$HOME/.config"

for entry in $entries; do
  src="$REPO/config/$entry"
  target="$HOME/.config/$entry"
  if [ ! -e "$src" ]; then
    echo "SKIP  $entry (missing in repo)"
    continue
  fi
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "SKIP  $target exists and is not a symlink — move it aside and re-run"
    continue
  fi
  ln -sfn "$src" "$target"
  echo "LINK  $target -> $src"
done

echo
echo "Done. Add to your shell rc:"
echo "  export PATH=\"$REPO/bin:\$PATH\""
