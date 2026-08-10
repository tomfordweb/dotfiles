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
    yq
    bat
    fzf
    nix-index
    nix-search-cli
    openssl 
    dig

    # Git ops
    lazygit
    gh
    glab
    gitleaks
    beads
    mergiraf # AST-aware merge driver; wired in config/git/config + attributes

    # Language toolchains
    (python3.withPackages (ps: with ps; [
      pyyaml
      openpyxl
    ]))
    rustup
    cmake
    nodejs_22  # pin per-project via flake + nix-direnv when it matters
    pnpm
    bun

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
