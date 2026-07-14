{ pkgs, ... }:

# ------------------------------------------------------------------
# Dev core — identical on every machine. The "my code-writing
# environment is the same on all ports" module.
# ------------------------------------------------------------------

{
  home.packages = with pkgs; [
    # Terminal
    ghostty

    # Editor lives in neovim.nix (with all its runtime deps)

    # Search / nav / everyday CLIs
    ripgrep
    fd
    jq
    bat
    fzf

    # Git ops
    lazygit
    gh
    glab
    gitleaks

    # Language toolchains
    python3    # bin/claude-killdevservers, tmux-which-key (pyyaml)
    rustup
    cmake
    nodejs_22  # pin per-project via flake + nix-direnv when it matters
    pnpm

    # Infra
    ansible

    # Ricing
    dart-sass  # install/rice.sh — waybar/wofi SCSS compile

    # LaTeX — medium base (latex + latexmk + xetex/luatex engines),
    # plus the extra font collection.
    (texliveMedium.withPackages (ps: with ps; [
      collection-luatex
      collection-xetex
      collection-fontsextra
    ]))
  ];
}
