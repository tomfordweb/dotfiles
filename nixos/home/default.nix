{ ... }:

# ------------------------------------------------------------------
# Home Manager entry point for `tom` — the shared dev core.
# ------------------------------------------------------------------
# Imported by every host (flake.nix mkHost). Host-specific extras are
# appended via mkHost's `homeModules` arg (e.g. gui-apps.nix).
# The rule: everything here must make sense on EVERY machine —
# desktop, laptop, VM.

{
  imports = [
    ./dotfiles.nix   # symlinks ~/.config/* into this repo (live-editable)
    ./ssh.nix        # SSH client local include hooks
    ./shell.nix      # zsh + oh-my-zsh + starship + direnv
    ./dev.nix        # terminals, language toolchains, CLIs
    ./neovim.nix     # nvim + all its runtime deps (LSPs, formatters, tree-sitter)
    ./tmux.nix       # tmux + tpm bootstrap
    ./ai-tools.nix   # Claude/codex config symlinks + shared MCP servers (ex ops/local.ai.yml)
  ];

  home.username = "tom";
  home.homeDirectory = "/home/tom";

  # Pin the Home Manager state version separately from system
  # stateVersion. Same rule: don't change it after first activation.
  home.stateVersion = "25.05";
}
