{ config, pkgs, lib, ... }:

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
}
