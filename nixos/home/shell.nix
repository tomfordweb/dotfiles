{ pkgs, config, ... }:

# ------------------------------------------------------------------
# Shell — zsh + oh-my-zsh, starship prompt, direnv.
# ------------------------------------------------------------------
# System-level zsh registration (etc/shells, login shell) lives in
# modules/core.nix; this is the per-user experience. Mirrors the
# hand-maintained ~/.zshrc this replaces: autosuggestions,
# fast-syntax-highlighting, pnpm aliases, thefuck.

{
  home.packages = with pkgs; [ starship ];

  # oh-my-zsh handles plugins; the theme is left blank so starship
  # drives the prompt instead. starship reads ~/.config/starship.toml,
  # which dotfiles.nix symlinks to the repo's config/starship.toml.
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;   # zsh-autosuggestions
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "docker" "fzf" ];
      theme = "";        # blank → starship provides the prompt
    };
    shellAliases = {
      npx = "pnpm dlx";
      nx = "pnpm nx";
    };
    # initContent is the current option (replaced initExtra on unstable).
    initContent = ''
      eval "$(starship init zsh)"

      # Machine-local env — NEVER in the repo or the nix store.
      # Secrets shouldn't live here either: the 1Password app+CLI
      # integration (modules/core.nix) makes `op read op://...` work
      # with no token in the environment; for headless use, scope a
      # service-account token to the command (`op run ... --`), don't
      # export it shell-wide.
      [ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"
    '';
  };

  # AI agent env + pnpm global-install home
  home.sessionVariables = {
    MAX_THINKING_TOKENS = "10000";
    ECC_CONTEXT_MONITOR_COST_WARNINGS = "off";
    PNPM_HOME = "${config.home.homeDirectory}/.local/share/pnpm";
  };

  # rustup-installed cargo binaries + pnpm global installs
  home.sessionPath = [
    "${config.home.homeDirectory}/.cargo/bin"
    "${config.home.homeDirectory}/.local/share/pnpm"
  ];

  # thefuck was removed from nixpkgs; pay-respects is the drop-in
  # successor (non-nix hosts can keep thefuck — its config dir is
  # still symlinked by dotfiles.nix).
  programs.pay-respects.enable = true;

  # direnv + nix-direnv — per-project dev environments (`use flake`)
  # and per-directory node switching.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Git identity lives in the repo's config/git/config (symlinked to
  # ~/.config/git by dotfiles.nix) — no programs.git here, it would
  # shadow/duplicate it.
}
