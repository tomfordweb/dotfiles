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
  boot.kernelPackages = pkgs.linuxPackages_6_12.extend (_: previous: {
    # The module's install target runs depmod in its private output, creating
    # indexes that conflict with the kernel's. NixOS indexes the combined tree.
    v4l2loopback = previous.v4l2loopback.overrideAttrs (old: {
      makeFlags = (old.makeFlags or []) ++ [ "DEPMOD=true" ];
    });
  });

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

    # NOTE 2 — driver PINNED to 615.78.08 (nixpkgs `latest`/new_feature as of
    # 2026-11-07; bumped from 595.45.04 after Bodycam segfaulted inside
    # libnvidia-glcore.so.595.45.04, dotfiles-i5y).
    # Previously `nvidiaPackages.beta`, a MOVING label that jumps to a new
    # version on every `nix flake update`. Hard-pinned here (hashes lifted
    # from nixpkgs' `beta` attr; verified green on kernel 6.12) so an
    # unrelated flake update can't silently swap in an untested driver and
    # black-screen the desktop. There is no semver-range pin in nix — this is
    # the exact-version equivalent; the driver moves ONLY when you edit below.
    # To BUMP: change `version`, run `nixos-rebuild build` (it prints the
    # correct `sha256-…` on hash mismatch), paste the new hashes, then switch.
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version            = "615.78.08";
      sha256_64bit       = "sha256-Pj9t3cLudnoIGFMAr3vjyyhuznZpjS3eNSRZl4LQf/4=";
      sha256_aarch64     = "sha256-UHYBE1AYHoGgMfD9AS/jX+S+N8eCDWUft6qolK9Eejc=";
      openSha256         = "sha256-HBINiOjL0ZJLIAJeNIBYHBnwgUXtNwPPtnFpAI1YwF4=";
      settingsSha256     = "sha256-inDRpG02sdDgHmlqgu/DsgK8OFdOt1fZIYyXdhlGC/c=";
      persistencedSha256 = "sha256-RzeR6Ldct6MUxjnXRyThdh5Y3jjMehTVg85MtwuWNX4=";
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
