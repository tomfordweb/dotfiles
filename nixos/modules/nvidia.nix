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

    # NOTE 2 — driver PINNED to 595.45.04 (>= 570, the first Blackwell branch).
    # Previously `nvidiaPackages.beta`, a MOVING label that jumps to a new
    # version on every `nix flake update`. Hard-pinned here (hashes lifted
    # from nixpkgs' `beta` attr; verified green on kernel 6.12) so an
    # unrelated flake update can't silently swap in an untested driver and
    # black-screen the desktop. There is no semver-range pin in nix — this is
    # the exact-version equivalent; the driver moves ONLY when you edit below.
    # To BUMP: change `version`, run `nixos-rebuild build` (it prints the
    # correct `sha256-…` on hash mismatch), paste the new hashes, then switch.
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version            = "595.45.04";
      sha256_64bit       = "sha256-zUllSSRsuio7dSkcbBTuxF+dN12d6jEPE0WgGvVOj14=";
      sha256_aarch64     = "sha256-jl6lQWsgF6ya22sAhYPpERJ9r+wjnWzbGnINDpUMzsk=";
      openSha256         = "sha256-uqNfImwTKhK8gncUdP1TPp0D6Gog4MSeIJMZQiJWDoE=";
      settingsSha256     = "sha256-Y45pryyM+6ZTJyRaRF3LMKaiIWxB5gF5gGEEcQVr9nA=";
      persistencedSha256 = "sha256-5FoeUaRRMBIPEWGy4Uo0Aho39KXmjzQsuAD9m/XkNpA=";
    };
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
