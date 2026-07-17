{ config, pkgs, lib, inputs, ... }:

# ------------------------------------------------------------------
# T480-only system config that must SURVIVE a reinstall.
# ------------------------------------------------------------------
# hardware-t480.nix is nixos-generate-config output and gets clobbered
# at install time — hand-written laptop config lives here instead
# (same pattern as minerva.nix for the desktop).

{
  imports = [
    ./hardware.nix              # nixos-generate-config output (T480 install)
    ../../modules/luks.nix      # cryptroot tuning; device UUID in hardware.nix
    ../../modules/laptop.nix    # brightnessctl, upower, power-profiles-daemon
    ../../modules/root-snapshots.nix # hourly btrbk snapshots of @ + @home

    # Fingerprint driver for the Synaptics 06cb:009a sensor (see below).
    inputs.nixos-06cb-009a-fingerprint-sensor.nixosModules."06cb-009a-fingerprint-sensor"
  ];

  # Intel iGPU acceleration (VA-API). The generated hardware config
  # doesn't carry this, and without it video decode falls back to CPU.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver   # iHD — Broadwell+ (the T480's UHD 620)
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # ------------------------------------------------------------------
  # Fingerprint reader — Synaptics 06cb:009a "Prometheus" sensor.
  # ------------------------------------------------------------------
  # Mainline libfprint has no driver for this sensor (fprintd logs
  # "No driver found for USB device 06CB:009A"), so we use the
  # reverse-engineered python-validity backend behind open-fprintd, a
  # drop-in replacement that speaks the same net.reactivated.Fprint
  # D-Bus API. The module force-disables services.fprintd.
  #
  # One-time bring-up after the first rebuild (downloads the sensor
  # firmware blob, which is not redistributable so can't be baked in):
  #   sudo systemctl stop python3-validity
  #   sudo validity-sensors-firmware
  #   sudo systemctl start python3-validity
  #   fprintd-enroll                 # then touch the sensor a few times
  #   fprintd-verify                 # sanity check
  #
  # The LUKS boot passphrase is unaffected — it runs before any of this
  # exists — so disk unlock at boot still needs the password.
  services."06cb-009a-fingerprint-sensor" = {
    enable = true;
    backend = "python-validity";
  };

  # pam_fprintd talks to open-fprintd over D-Bus, but NixOS only wires
  # fingerprint into PAM when services.fprintd is enabled (it isn't here),
  # so opt the relevant stacks in by hand. sudo tries the finger first and
  # falls back to the password, so nothing is lost if the reader misbehaves.
  #
  # NOT enabled for login (TTY/getty), hyprlock, or sddm. TTY login never
  # worked reliably with the finger, so it stays password-only. hyprlock and
  # sddm are GUI prompts with their own password text field, so a pam_fprintd
  # entry means "type password AND scan finger", not "or". hyprlock instead
  # does fingerprint natively over the fprintd D-Bus API (see auth{fingerprint}
  # in config/hypr/hyprlock.conf), which runs concurrently with its password
  # field = true finger-or-password. sddm's Qt greeter has no such native path,
  # so boot login stays password-only.
  security.pam.services = {
    sudo.fprintAuth = true;       # sudo prompts (CLI, no competing text field)
  };
}
