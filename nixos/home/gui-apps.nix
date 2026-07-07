{ pkgs, ... }:

# ------------------------------------------------------------------
# GUI / desktop apps — appended per host via mkHost homeModules.
# ------------------------------------------------------------------
# Not part of the dev core so a future headless host can skip it.

{
  home.packages = with pkgs; [
    # Browsers
    firefox
    chromium

    # Media / comms
    spotify
    discord

    # Dev GUIs
    dbeaver-bin

    # Desktop utils
    pavucontrol
    networkmanagerapplet
    yazi       # $fileManager in hyprland.conf (runs in ghostty)

    # Anonymity — pairs with the system tor daemon (modules/tor.nix)
    tor-browser
  ];
}
