{ config, ... }:

# ------------------------------------------------------------------
# Dotfiles integration — per-app symlinks into the repo.
# ------------------------------------------------------------------
# Replaces the old XDG_CONFIG_HOME-at-the-repo trick. Real ~/.config
# stays the config home (so app-generated state lands there, NOT in
# the repo); only hand-managed configs are symlinked back into the
# repo via mkOutOfStoreSymlink — which keeps them live-editable:
# edit a file in the repo, the app sees it immediately, no rebuild.
#
# CONTRACT: the repo must live at ~/code/tomfordweb/dotfiles on every
# nix host (mkOutOfStoreSymlink embeds the absolute path).
#
# Non-nix hosts (work, mac) create the same links with
# install/bootstrap.sh — keep its list in sync with this one.

let
  dotfiles = "${config.home.homeDirectory}/code/tomfordweb/dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  xdg.configFile = {
    "hypr".source          = link "config/hypr";
    "waybar".source        = link "config/waybar";
    "wofi".source          = link "config/wofi";
    "tmux".source          = link "config/tmux";
    "ghostty".source       = link "config/ghostty";
    "nvim".source          = link "config/nvim";
    "lazygit".source       = link "config/lazygit";
    "gh".source            = link "config/gh";
    "git".source           = link "config/git";
    "starship.toml".source = link "config/starship.toml";
    "workmux".source       = link "config/workmux";
    "glab-cli".source      = link "config/glab-cli";
    "thefuck".source       = link "config/thefuck";
    # Single file, not the whole dir — WirePlumber writes state under
    # ~/.config/wireplumber too, which must stay real (not repo-linked).
    # Forces the Yeti Orb to a COSMIC-visible profile + priority over the
    # S600 cam mic (see the .conf header).
    "wireplumber/wireplumber.conf.d/50-yeti-orb.conf".source =
      link "config/wireplumber/wireplumber.conf.d/50-yeti-orb.conf";
    # Deliberately NOT linked: browsers, dconf, pulse, gnome*, htop,
    # pnpm, and other app-generated state — that junk belongs in real
    # ~/.config, not the repo.
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.sessionPath = [
    "${dotfiles}/bin"                          # repo scripts
    "${config.home.homeDirectory}/.local/bin"  # workmux + prebuilt personal binaries
  ];
}
