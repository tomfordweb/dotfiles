{ config, lib, pkgs, modulesPath, ... }:

# ------------------------------------------------------------------
# PLACEHOLDER — regenerated at install time.
# ------------------------------------------------------------------
# After booting the installer ISO and partitioning, run
#
#     nixos-generate-config --root /mnt
#
# and copy the generated hardware-configuration.nix OVER this file.
# Reformatting `/` changes its UUID; the ESP and /home UUIDs persist
# as long as those partitions are reused (do NOT format /home — user
# data).
#
# Disk map:
#   nvme0n1 (WD_BLACK SN850X 2TB):
#     p1 /         ext4  fb708e51-3b4d-4a7b-abb8-5eb4645bf038 (reformat → new UUID)
#     p2 /boot/efi vfat  A137-BB42                            (reuse ESP → UUID keeps)
#     p3 /home     ext4  fa19d155-ac19-4efc-82a8-bc11188c9158 (KEEP — user data; don't format)
#   nvme1n1 (Crucial T500 1TB): btrfs label "code"    → modules/code-drive.nix
#   sda     (WD 4TB):           btrfs label "storage" → hosts/minerva/default.nix
# Swap: zram only (hosts/minerva/default.nix), no swap partition.
# ------------------------------------------------------------------

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # `/` gets a new UUID at install (reformat); /boot and /home persist.
  # Replaced by nixos-generate-config anyway.
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/fb708e51-3b4d-4a7b-abb8-5eb4645bf038";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A137-BB42";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # Preserved user-data partition — never formatted across installs.
  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/fa19d155-ac19-4efc-82a8-bc11188c9158";
    fsType = "ext4";
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
