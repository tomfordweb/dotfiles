{ pkgs, ... }:

# ------------------------------------------------------------------
# Dev core — identical on every machine. The "my code-writing
# environment is the same on all ports" module.
# ------------------------------------------------------------------

let
  # TeX Live — was `apt install texlive-luatex texlive-xetex
  # texlive-fonts-extra` on non-nix hosts. scheme-medium is the
  # working-LaTeX base (already pulls luatex+xetex); the extra
  # collections mirror the three apt packages explicitly.
  tex = pkgs.texlive.combine {
    inherit (pkgs.texlive)
      scheme-medium
      collection-luatex
      collection-xetex
      collection-fontsextra
      ;
  };
in
{
  home.packages = with pkgs; [
    tex

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
