{ config, lib, ... }:

# ------------------------------------------------------------------
# LUKS full-disk encryption — real installs (t480 now, minerva at its
# LUKS reinstall). NOT imported by the VM output; the VM is
# unencrypted for iteration speed and because it doesn't matter.
# ------------------------------------------------------------------
# The cryptroot DEVICE (LUKS partition UUID) is declared by the host's
# generated hardware.nix — nixos-generate-config detects it at install
# time. This module only adds the tuning options on top: preLVM
# ordering and TRIM passthrough.
#
# The `name` ("cryptroot") is the /dev/mapper name the encrypted device
# gets after unlock — the host hardware.nix references
# /dev/mapper/cryptroot as the root fs device.
# ------------------------------------------------------------------

{
  boot.initrd.luks.devices."cryptroot" = {
    preLVM = true;
    allowDiscards = true;   # TRIM support on the NVMe
  };
}
