{ config, lib, pkgs, modulesPath, ... }:

# ------------------------------------------------------------------
# PLACEHOLDER — regenerated at real install time.
# ------------------------------------------------------------------
# Same deal as hardware-t480.nix: after booting the installer ISO and
# partitioning minerva, run
#
#     nixos-generate-config --root /mnt
#
# and copy the generated hardware-configuration.nix OVER this file
# (keeping the name `hardware-minerva.nix`). That fills in the real
# kernel modules, disk UUIDs, and filesystem entries.
#
# The values below are placeholders that reflect what we KNOW about
# minerva today (from Pop!_OS): Intel Arrow Lake (Core Ultra 7 265K),
# NVMe root, ASUS board with a Blackwell dGPU. They let the flake
# evaluate for `nix flake check`.
#
# Current Pop!_OS disk layout (for reference — install decides final):
#   nvme0n1 (WD_BLACK SN850X 2TB): p1 / (ext4), p2 /boot/efi (vfat), p3 /home (ext4)
#   nvme1n1 (Crucial T500 1TB):    btrfs label "code"  → handled by code-drive.nix
#   sda     (WD 4TB):              btrfs label "storage" (data; add a mount later if wanted)
# ------------------------------------------------------------------

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # These UUIDs are FAKE. Replaced by nixos-generate-config at install.
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  # Intel CPU microcode + redistributable firmware (needed for the
  # Arrow Lake iGPU + wifi/etc).
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;

  # Intel Arrow Lake iGPU (VA-API / QuickSync). The discrete NVIDIA
  # stack is added separately by nvidia.nix.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver     # modern VA-API driver (Xe / Arc-class iGPU)
      libvdpau-va-gl
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
