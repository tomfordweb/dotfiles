{ modulesPath, lib, ... }:

{
  # qemu-guest profile enables virtio kernel modules and other bits
  # needed to run smoothly inside QEMU. This is all the "hardware"
  # config the VM needs.
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  # nixos-rebuild build-vm generates the disk image at boot and
  # attaches it as /dev/vda. This root fs entry is only a hint —
  # the VM wrapper overrides it. But nixosSystem still wants
  # something declared for the config to evaluate.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Give the VM a bit more OpenGL love so Hyprland is at least
  # renderable. Software rendering is still slow, but this at
  # least makes it work.
  hardware.graphics.enable = true;

  # The dotfiles 9p share for VM runs lives in configuration.nix
  # (vmVariant) so ALL hosts' `.build.vm` variants get it, not just
  # this one.
}
