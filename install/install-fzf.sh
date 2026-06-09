#!/usr/bin/env bash
set -euo pipefail

ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

VERSION=$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest \
  | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')

DEST="${HOME}/.local/bin"
mkdir -p "$DEST"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${VERSION}/fzf-${VERSION}-linux_${ARCH}.tar.gz" \
  | tar -xz -C "$TMP"

install -m755 "$TMP/fzf" "$DEST/fzf"
echo "fzf $("$DEST/fzf" --version) installed to $DEST/fzf"
