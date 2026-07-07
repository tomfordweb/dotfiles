{ pkgs, lib, ... }:

# ------------------------------------------------------------------
# Neovim + every runtime dependency, declaratively.
# ------------------------------------------------------------------
# The config itself is the neotom submodule (config/nvim, symlinked to
# ~/.config/nvim by dotfiles.nix). This module guarantees everything
# that config shells out to exists on nvim's PATH — no Mason downloads,
# no `npm i -g`, no missing tree-sitter CLI.
#
# NOT programs.neovim: that HM module generates its own
# .config/nvim/init.lua, which collides with the whole-dir repo
# symlink. Instead nvim is wrapped so the deps ride ITS PATH only —
# they don't pollute the interactive shell (the ones you also call by
# hand live in dev.nix).

let
  nvimRuntimeDeps = with pkgs; [
    # treesitter: CLI + toolchain for :TSInstall grammar builds
    tree-sitter
    gcc
    gnumake
    nodejs_22

    # conform.nvim formatters
    prettierd
    shfmt
    stylua
    black

    # LSP servers (the full set lsp.lua configures)
    typescript-language-server        # ts_ls
    angular-language-server           # angularls
    pyright
    python3Packages.python-lsp-server # pylsp
    lua-language-server               # lua_ls
    intelephense                      # PHP (unfree — allowUnfree is on)
    ansible-language-server           # ansiblels
    bash-language-server              # bashls
    marksman                          # markdown
    hyprls                            # hyprland.conf
    docker-compose-language-service
    docker-language-server
    emmet-ls                          # emmet_ls
    vscode-langservers-extracted      # jsonls, eslint, html, css
    oxlint
    gitlab-ci-ls
    graphql-language-service-cli      # graphql
    nixd                              # nix LSP — for editing this repo

    # telescope / pickers
    ripgrep
    fd
  ];

  neovim-with-deps = pkgs.symlinkJoin {
    name = "neovim-with-deps";
    paths = [ pkgs.neovim ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/nvim \
        --prefix PATH : ${lib.makeBinPath nvimRuntimeDeps}
    '';
  };
in
{
  home.packages = [ neovim-with-deps ];

  # EDITOR is set in dotfiles.nix (kept there for parity with the
  # non-nix bootstrap docs).
}
