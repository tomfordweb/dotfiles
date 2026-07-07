{ pkgs, lib, ... }:

# ------------------------------------------------------------------
# tmux + plugin manager bootstrap.
# ------------------------------------------------------------------
# tmux.conf lives in the repo (config/tmux, symlinked by dotfiles.nix)
# and runs ~/.tmux/plugins/tpm/tpm. Clone tpm declaratively on
# activation; plugins themselves are still installed inside tmux
# with <prefix> I.

{
  home.packages = with pkgs; [ tmux ];

  home.activation.cloneTpm = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
      run ${pkgs.git}/bin/git clone --depth 1 \
        https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
  '';
}
