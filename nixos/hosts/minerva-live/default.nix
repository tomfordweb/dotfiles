{ lib, modulesPath, ... }:

# ------------------------------------------------------------------
# Live-USB test image of the minerva system. Boots from USB, runs
# from RAM, touches NO disks — for verifying NVIDIA/Hyprland/the
# monitor layout on real hardware before installing to disk.
#   nix build .#nixosConfigurations.minerva-live.config.system.build.isoImage
#   sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
# Deliberately excludes minerva's hardware.nix (the ISO brings its
# own filesystems) and hosts/minerva/default.nix (steam/ollama/
# mounts/backups — bulk + touches real drives) and code-drive.nix.
# ------------------------------------------------------------------

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    ../../modules/nvidia.nix
  ];

  # ISO installer profile enables wpa_supplicant; we run
  # NetworkManager (modules/core.nix) — can't have both.
  networking.wireless.enable = lib.mkForce false;
  # Live session needs a login at SDDM; harmless, RAM-only.
  users.users.tom.initialPassword = "nixos";
  security.sudo.wheelNeedsPassword = lib.mkForce false;
  # zstd squashfs: much faster image build than the xz default.
  isoImage.squashfsCompression = "zstd";
}
