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
  # Kernel — pin the 6.12 LTS series.
  # ----------------------------------------------------------------
  # Arrow Lake (Core Ultra 7 265K) needs a reasonably fresh kernel
  # (iGPU/platform support landed ~6.11), and 6.12 LTS covers it.
  # Do NOT use `linuxPackages_latest`: at time of writing that's 7.1.2,
  # which DROPPED `linux/of_gpio.h` — the NVIDIA driver source still
  # #includes it, so the kernel module fails to compile:
  #   fatal error: linux/of_gpio.h: No such file or directory
  # 6.12 LTS is the sweet spot: new enough for Arrow Lake, old enough
  # for the NVIDIA driver to build. Bump deliberately once a driver
  # release supports a newer kernel.
  boot.kernelPackages = pkgs.linuxPackages_6_12;

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
  # Wayland/Hyprland — NVIDIA-specific env vars.
  # SDDM launches Hyprland directly on minerva (no TTY/GNOME fallback
  # session exists), and a pure-dGPU desktop commonly black-screens
  # without GBM_BACKEND. If the compositor still fails, escape to a TTY
  # with Ctrl+Alt+F2 and roll back.
  # ----------------------------------------------------------------
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };
}
