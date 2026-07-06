{ config, pkgs, inputs, ... }:

{
  # ------------------------------------------------------------------
  # Hyprland (Wayland tiling compositor)
  # ------------------------------------------------------------------
  # programs.hyprland pulls in the compositor plus a session file so
  # your login manager can offer "Hyprland" as a session.
  programs.hyprland = {
    enable = true;
    # Use the Hyprland flake's package for the freshest version.
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  # XDG desktop portals: needed for screenshots, screen sharing,
  # file pickers, etc. hyprland-portal handles Hyprland-specific bits.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Fonts. Nerd Fonts give you icons for waybar, etc.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];

  # ------------------------------------------------------------------
  # Login manager — greetd + tuigreet
  # ------------------------------------------------------------------
  # A tiny TTY-based greeter that launches Hyprland on login.
  # Simpler than SDDM/GDM and works well for tiling setups.
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # ------------------------------------------------------------------
  # System-wide Wayland utilities
  # ------------------------------------------------------------------
  # These live at system level so any user can invoke them and
  # they're available before Home Manager has run.
  environment.systemPackages = with pkgs; [
    waybar          # status bar (your dotfiles already have a config)
    wofi            # app launcher (your dotfiles already have a config)
    foot            # lightweight Wayland terminal (fallback)
    grim            # screenshot
    slurp           # region selection for grim
    wl-clipboard    # wl-copy / wl-paste
    brightnessctl   # laptop brightness keys
    playerctl       # media keys
    mako            # notification daemon
    polkit_gnome    # graphical polkit auth prompts
  ];

  # Polkit is required for anything that needs privilege elevation
  # from a GUI (e.g. mounting disks in a file manager).
  security.polkit.enable = true;
}
