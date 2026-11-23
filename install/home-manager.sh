#!/usr/bin/env bash
# ----------------------------------------------------------------------
# Standalone home-manager for NON-NIXOS hosts (headless work Ubuntu).
# ----------------------------------------------------------------------
# Applies nixos/flake.nix#homeConfigurations.work: the dev-core
# ~/.config symlinks from nixos/home/dotfiles.nix (desktop set off),
# plus PATH (repo bin/, ~/.local/bin) and EDITOR. No packages.
# Alternative to install/bootstrap.sh --minimal; use one, not both.
#
# Run on the host as your normal user (not root, not in a container):
#   ~/code/tomfordweb/dotfiles/install/home-manager.sh
# Idempotent. Existing files in the way are renamed to *.hm-backup.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NIX_FLAGS=(--extra-experimental-features "nix-command flakes")

if [[ -f /.dockerenv ]]; then
  echo "This looks like a container. Run this on the host instead." >&2
  exit 1
fi
if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user, not root (the Nix installer sudos itself)." >&2
  exit 1
fi
if [[ "$REPO" != "$HOME/code/tomfordweb/dotfiles" ]]; then
  echo "Repo must live at ~/code/tomfordweb/dotfiles (symlinks bake that path in)." >&2
  exit 1
fi

# 1. Nix ----------------------------------------------------------------
if ! command -v nix >/dev/null 2>&1; then
  if [[ ! -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    echo "==> Installing Nix (multi-user; will prompt for sudo)"
    sh <(curl -fsSL https://nixos.org/nix/install) --daemon --yes
  fi
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
echo "==> $(nix --version)"

if [[ "${XDG_CONFIG_HOME:-}" == *dotfiles/config* ]]; then
  echo "!!  XDG_CONFIG_HOME points at the repo ($XDG_CONFIG_HOME)."
  echo "    Remove that line (and the old dotfiles/bin PATH line) from your"
  echo "    shell rc afterwards; configs are now linked into ~/.config."
fi

# 2. Build + activate ------------------------------------------------------
# path: so Nix reads the working tree as-is (a git flake would ignore
# uncommitted changes). Builds outside the repo so no ./result lands there.
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
echo "==> Building homeConfigurations.work"
nix "${NIX_FLAGS[@]}" build --out-link "$OUT/result" \
  "path:$REPO/nixos#homeConfigurations.work.activationPackage"
echo "==> Activating"
HOME_MANAGER_BACKUP_EXT=hm-backup "$OUT/result/activate"

# 3. Load HM session vars (PATH, EDITOR) in bash login + interactive shells ----
MARK="# >>> home-manager session vars >>>"
BLOCK="$MARK
for f in \"\$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh\" \\
         \"\$HOME/.local/state/nix/profile/etc/profile.d/hm-session-vars.sh\"; do
  if [ -e \"\$f\" ]; then . \"\$f\"; break; fi
done
# <<< home-manager session vars <<<"
for rc in "$HOME/.profile" "$HOME/.bashrc"; do
  if ! grep -qF "$MARK" "$rc" 2>/dev/null; then
    printf '\n%s\n' "$BLOCK" >> "$rc"
    echo "==> Added session-vars block to $rc"
  fi
done

echo
echo "Done. Open a new shell. Files moved aside (if any):"
find "$HOME/.config" -maxdepth 2 -name '*.hm-backup' 2>/dev/null || true
echo "Later: edit nixos/ then re-run this script (or: home-manager switch"
echo "--flake path:$REPO/nixos#work)."
