{ config, pkgs, lib, ... }:

{
  # ------------------------------------------------------------------
  # Home Manager user config for `tom`.
  # ------------------------------------------------------------------
  # This module is imported from flake.nix. It manages user-scoped
  # packages, dotfiles, and env vars — the counterpart to
  # configuration.nix for system-level stuff.

  home.username = "tom";
  home.homeDirectory = "/home/tom";

  # Pin the Home Manager state version separately from system
  # stateVersion. Same rule: don't change it after first activation.
  home.stateVersion = "25.05";

  # ------------------------------------------------------------------
  # Reuse the existing dotfiles repo as XDG_CONFIG_HOME.
  # ------------------------------------------------------------------
  # Your dotfiles repo at ~/code/tomfordweb/dotfiles already ships
  # `config/hypr/`, `config/waybar/`, `config/wofi/`, etc. Point XDG at it
  # so Hyprland and friends pick up the same config on NixOS.
  #
  # The repo also does per-host Hyprland via
  # `config/hypr/configs/<hostname>.conf` — add one for `nixos-vm` and
  # `nixos-laptop` later so per-machine tweaks (monitors, scaling)
  # live alongside your other hosts.
  home.sessionVariables = {
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/code/tomfordweb/dotfiles/config";
    EDITOR = "nvim";
  };

  # Also make PATH include the dotfiles bin dir like your Ubuntu setup.
  home.sessionPath = [
    "${config.home.homeDirectory}/code/tomfordweb/dotfiles/bin"
  ];

  # ------------------------------------------------------------------
  # User packages (installed only for tom)
  # ------------------------------------------------------------------
  home.packages = with pkgs; [
    # Terminals / shells
    ghostty
    tmux

    # Editors
    neovim

    # Dev tooling
    ripgrep
    fd
    jq
    bat
    fzf
    lazygit
    starship

    # Media / apps
    firefox
    spotify
    dbeaver-bin

    # Dev tooling (parity with minerva)
    gh
    glab
    gitleaks
    ansible
    rustup
    cmake

    # GUI apps (parity with minerva)
    discord
    chromium
  ];

  # ------------------------------------------------------------------
  # Git identity
  # ------------------------------------------------------------------
  programs.git = {
    enable = true;
    settings.user.name = "Tom Ford";
    settings.user.email = "tomfordweb@gmail.com";
  };

  # ------------------------------------------------------------------
  # Shell — zsh + oh-my-zsh (replaces bash/oh-my-bash).
  # ------------------------------------------------------------------
  # oh-my-zsh handles plugins; the theme is left blank so starship
  # drives the prompt instead. starship reads its config from
  # $XDG_CONFIG_HOME/starship.toml — which is your repo's
  # config/starship.toml, since XDG_CONFIG_HOME points there (above).
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "docker" "fzf" ];
      theme = "";        # blank → starship provides the prompt
    };
    shellAliases = { };  # add as you go
    # initContent is the current option (replaced initExtra on unstable).
    initContent = ''
      eval "$(starship init zsh)"
    '';
  };
}
