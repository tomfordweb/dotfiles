#!/usr/bin/env sh
# macOS ships an ancient ncurses (5.7, 2009) whose tmux-256color terminfo entry
# is missing/outdated. Inside tmux, nvim then misreads key and bracketed-paste
# capabilities -> pasting injects stray control chars and registers break.
#
# Fix: compile a modern tmux-256color (+ screen-256color) entry into the user
# terminfo db (~/.terminfo). No sudo. Idempotent -- safe to re-run.
#
# After running, restart the tmux server so nvim picks up the new entry:
#     tmux kill-server
set -eu

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL https://invisible-island.net/datafiles/current/terminfo.src.gz \
  -o "$tmp/terminfo.src.gz"
gunzip "$tmp/terminfo.src.gz"
/usr/bin/tic -x -o "$HOME/.terminfo" "$tmp/terminfo.src"

echo "Installed tmux-256color terminfo into ~/.terminfo"
echo "Verify:  infocmp -x tmux-256color | head -1"
echo "Then restart tmux:  tmux kill-server"
