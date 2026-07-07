{ pkgs, ... }:

# ------------------------------------------------------------------
# Laptop-only bits (imported by hosts/t480, never by desktops).
# ------------------------------------------------------------------

{
  environment.systemPackages = with pkgs; [
    brightnessctl   # brightness keys (bound in hyprland.conf)
  ];

  # waybar battery + power-profiles-daemon modules
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
}
