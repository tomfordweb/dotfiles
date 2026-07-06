{ config, pkgs, lib, ... }:

# ------------------------------------------------------------------
# NVIDIA — minerva only (Blackwell, RTX 50-series, PCI 10de:2c05).
# ------------------------------------------------------------------
# Imported by the `minerva` host in flake.nix. The T480 is Intel-only
# and never sees this file.
#
# Blackwell is bleeding edge, which flips the usual NVIDIA-on-NixOS
# advice in two important ways (see the two big notes below).
# ------------------------------------------------------------------

{
  # ----------------------------------------------------------------
  # Recent kernel — Arrow Lake (Core Ultra 7 265K) is very new silicon
  # and wants a fresh kernel for iGPU + platform support. The NVIDIA
  # module is rebuilt against whatever kernel this pins.
  # ----------------------------------------------------------------
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ----------------------------------------------------------------
  # Use the NVIDIA driver. On a desktop the dGPU is the primary output,
  # so no PRIME/Optimus offload dance (that's a laptop concern).
  # ----------------------------------------------------------------
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # NOTE 1 — MANDATORY for Blackwell.
    # Blackwell (RTX 50-series) has NO closed-source kernel module.
    # The open kernel module is the only one that drives it. Do NOT
    # set this to false "to be safe" like you would on old Pascal cards
    # — false = black screen here.
    open = true;

    modesetting.enable = true;
    nvidiaSettings = true;
    powerManagement.enable = true;      # cleaner suspend/resume

    # NOTE 2 — driver must be >= 570 (first branch with Blackwell support).
    # `beta` tracks the freshest branch; by now `production` may also be
    # >= 570. VERIFY at build (`nix flake check` / nixos-rebuild build),
    # then PIN the exact version here once it builds green. If nixpkgs'
    # packaged driver ever predates your card, override explicitly:
    #   package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    #     version = "XXX.XX"; sha256_64bit = "..."; ...
    #   };
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  # Kernel mode-setting from early boot — required for a good Wayland
  # experience and to avoid console tearing/flicker.
  boot.kernelParams = [ "nvidia_drm.modeset=1" ];

  # ----------------------------------------------------------------
  # Phase 2 (Hyprland/Wayland) — NVIDIA-specific env vars.
  # Left commented so Phase 1 (getting it to BOOT + a working TTY/GNOME)
  # isn't complicated by iGPU/dGPU render routing. Uncomment when wiring
  # Hyprland; GBM_BACKEND in particular can confuse the Intel iGPU if set
  # system-wide before you actually want NVIDIA driving the compositor.
  # ----------------------------------------------------------------
  # environment.sessionVariables = {
  #   LIBVA_DRIVER_NAME = "nvidia";
  #   GBM_BACKEND = "nvidia-drm";
  #   __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  #   NVD_BACKEND = "direct";
  # };
}
