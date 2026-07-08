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

  # NB: the T480 fingerprint reader is NOT set up here. Its Synaptics
  # 06cb:009a sensor has no mainline libfprint driver, so it needs the
  # reverse-engineered python-validity stack — wired up in
  # hosts/t480/default.nix, which force-disables services.fprintd.
}
