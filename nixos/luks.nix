{ config, lib, ... }:

# ------------------------------------------------------------------
# LUKS full-disk encryption — laptop only.
# ------------------------------------------------------------------
# NOT imported by the VM output; the VM is unencrypted for iteration
# speed and because it doesn't matter.
#
# At real install time you'll:
#   1. Partition NVMe with an EFI partition + a big LUKS partition.
#   2. `cryptsetup luksFormat /dev/nvme0n1p2` then `luksOpen` it as
#      `cryptroot`.
#   3. Format the mapped device as btrfs, mount it, etc.
#   4. Find the LUKS partition UUID with `blkid /dev/nvme0n1p2`.
#   5. Paste that UUID into the placeholder below.
#
# The `name` here ("cryptroot") is the /dev/mapper name that the
# encrypted device gets exposed as after unlock — hardware-laptop.nix
# will reference /dev/mapper/cryptroot as the root fs device.
# ------------------------------------------------------------------

{
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-LUKS-PARTITION-UUID";
    preLVM = true;
    allowDiscards = true;   # TRIM support on the NVMe
  };
}
