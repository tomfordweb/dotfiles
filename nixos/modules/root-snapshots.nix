{ config, lib, pkgs, ... }:

# ------------------------------------------------------------------
# Local btrfs snapshots of the root disk (btrbk).
# ------------------------------------------------------------------
# Same tool + tiered-retention pattern as modules/code-drive.nix, but
# aimed at the LUKS/btrfs root filesystem (cryptroot). Takes read-only
# snapshots of @ (/) and @home into an @snapshots subvolume on the SAME
# disk.
#
# These are SNAPSHOTS, not backups: they undo bad rebuilds, botched
# config edits, and accidental deletes, but do NOT survive disk failure
# or theft (same physical SSD). Add an off-device btrbk send target if
# that ever matters.
#
# @nix (reproducible from the flake) and @log are deliberately NOT
# snapshotted — @nix is huge and rebuildable, @log is noise.
#
# Recovery from a botched @ (boot the NixOS installer USB, unlock the
# LUKS device, then mount the top of the filesystem at /mnt):
#   cryptsetup open /dev/disk/by-uuid/<cryptroot-uuid> cryptroot
#   mount -o subvolid=5 /dev/mapper/cryptroot /mnt
#   mv /mnt/@ /mnt/@.broken
#   btrfs subvolume snapshot /mnt/@snapshots/@.YYYYMMDDThhmm /mnt/@
#   umount /mnt && reboot          # delete @.broken once happy
# (@home recovers the same way. `btrfs subvolume list /` shows the
#  timestamped snapshots.)

let
  btrTop     = "/mnt/root-btr";
  btrTopUnit = "mnt-root\\x2dbtr.mount"; # systemd escapes '-' as \x2d
in
{
  # ---- Mount the top of the cryptroot filesystem -------------------
  # subvolid=5 (the real root of the btrfs) is where btrbk creates
  # snapshots and reaches @ / @home. cryptroot is already unlocked by
  # the initrd LUKS stage, so this just needs the mapper node. Kept out
  # of the way at /mnt/root-btr.
  fileSystems.${btrTop} = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvolid=5" "noatime" "nofail" ];
  };

  # ---- First-boot subvolume bootstrap ------------------------------
  # NixOS declarative mounts don't create subvolumes. Create @snapshots
  # once the top mount is up if it's missing. Idempotent.
  systemd.services.root-snapshots-subvol = {
    description = "Create @snapshots subvolume on the root btrfs";
    wantedBy = [ "multi-user.target" ];
    after = [ btrTopUnit ];
    requires = [ btrTopUnit ];
    unitConfig.ConditionPathIsMountPoint = btrTop;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -e "${btrTop}/@snapshots" ]; then
        ${pkgs.btrfs-progs}/bin/btrfs subvolume create "${btrTop}/@snapshots"
      fi
    '';
  };

  # ---- btrbk hourly snapshots --------------------------------------
  # Tiered retention: 48h hourly, 14d daily, 8w weekly. CoW means each
  # snapshot only stores deltas, so this stays cheap.
  services.btrbk = {
    instances.root = {
      onCalendar = "hourly";
      settings = {
        transaction_log      = "/var/log/btrbk-root.log";
        snapshot_preserve_min = "2h";
        snapshot_preserve    = "48h 14d 8w";
        volume.${btrTop} = {
          snapshot_dir = "@snapshots";
          subvolume."@"     = { };
          subvolume."@home" = { };
        };
      };
    };
  };
}
