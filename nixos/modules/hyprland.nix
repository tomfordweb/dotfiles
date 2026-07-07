{ config, pkgs, inputs, ... }:

let
  # SDDM launches this instead of Hyprland directly. Home Manager's
  # session vars (sessionPath → dotfiles/bin, EDITOR, npm prefix) only
  # land in hm-session-vars.sh, which login shells source — display
  # managers don't run one, so without this Hyprland and everything it
  # spawns would miss PATH/EDITOR. (Config location no longer depends
  # on it — ~/.config/hypr is a home-manager symlink into the repo.)
  hyprland-session = pkgs.writeShellScript "hyprland-session" ''
    hm_vars="/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
    if [ -f "$hm_vars" ]; then
      . "$hm_vars"
    fi
    exec Hyprland
  '';

  # Wayland session entry exposing the wrapper to SDDM's session picker.
  # passthru.providedSessions is how sessionPackages discovers the name.
  hyprland-hm-session = pkgs.writeTextFile {
    name = "hyprland-hm-session";
    destination = "/share/wayland-sessions/hyprland-hm.desktop";
    text = ''
      [Desktop Entry]
      Name=Hyprland
      Comment=Hyprland with home-manager session vars
      Exec=${hyprland-session}
      Type=Application
    '';
    derivationArgs.passthru.providedSessions = [ "hyprland-hm" ];
  };
in
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
    nerd-fonts.jetbrains-mono     # waybar/wofi/eww/hyprlock: JetBrainsMono Nerd Font
    nerd-fonts.fira-code
    nerd-fonts.monaspace          # ghostty: MonaspiceNe Nerd Font Mono
    nerd-fonts.bigblue-terminal
    font-awesome                  # waybar/wofi css fallback: FontAwesome
  ];

  # ------------------------------------------------------------------
  # Login manager — SDDM (Wayland mode)
  # ------------------------------------------------------------------
  # Graphical login. The custom "hyprland-hm" session (registered via
  # sessionPackages) launches the env wrapper above instead of bare
  # Hyprland so home-manager session vars reach the compositor.
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
    };
    sessionPackages = [ hyprland-hm-session ];
    defaultSession = "hyprland-hm";
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
    playerctl       # media keys
    mako            # notification daemon (dotfiles: exec-once = mako)
    polkit_gnome    # graphical polkit auth prompts
    hypridle        # idle daemon (dotfiles: exec-once = hypridle)
    awww            # wallpaper daemon, ex-swww (dotfiles: exec-once = awww-daemon)
    hyprpolkitagent # dotfiles: systemctl --user start hyprpolkitagent
    cava            # ambient desktop visualizer (cava-bg windowrule)
    eww             # widgets: ghost calendar + control center
    brightnessctl   # eww control-center brightness slider (inert on desktops)
  ];

  # Lock screen. MUST be the NixOS module (not a bare package) so
  # security.pam.services.hyprlock is registered — otherwise unlock
  # always fails.
  programs.hyprlock.enable = true;

  # Polkit is required for anything that needs privilege elevation
  # from a GUI (e.g. mounting disks in a file manager).
  security.polkit.enable = true;
}
