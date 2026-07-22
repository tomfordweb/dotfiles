{ pkgs, lib, ... }:

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
    nix-index
    nix-search-cli

    # Git ops
    lazygit
    gh
    glab
    gitleaks
    beads

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

    # PDF text extraction
    (lib.getAttr "poppler-utils" pkgs)

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
