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

  # Fingerprint reader (T480: Synaptics 06cb:009a, native libfprint driver).
  # Enabling fprintd flips on fprintAuth for every PAM service by default,
  # so SDDM login, hyprlock unlock, and sudo all accept a finger. The LUKS
  # boot passphrase is unaffected — it runs before fprintd exists.
  # Enroll after a rebuild with:  fprintd-enroll
  services.fprintd.enable = true;
}
