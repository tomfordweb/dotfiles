{ config, lib, pkgs, modulesPath, ... }:

# ------------------------------------------------------------------
# PLACEHOLDER — regenerated at real install time.
# ------------------------------------------------------------------
# During the actual NixOS install (after booting the installer ISO
# and partitioning), you'll run:
#
#     nixos-generate-config --root /mnt
#
# That produces /mnt/etc/nixos/hardware-configuration.nix with the
# real kernel modules, disk UUIDs, and filesystem entries for THIS
# machine. Copy that file OVER this one (keeping the filename
# `hardware-laptop.nix`) before running `nixos-install`.
#
# The values below are placeholders that DO reflect what we know
# about the machine (Intel i5-8250U, UHD 620, NVMe) so the flake
# still evaluates for `nix flake check`.
# ------------------------------------------------------------------

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # These UUIDs are FAKE. Replaced by nixos-generate-config.
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "btrfs";
    options = [ "subvol=@" "compress=zstd" "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  # Intel-specific CPU tweaks
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;

  # Intel graphics
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver     # newer VA-API driver
      intel-vaapi-driver     # legacy (renamed from vaapiIntel)
      libva-vdpau-driver     # renamed from vaapiVdpau
      libvdpau-va-gl
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
