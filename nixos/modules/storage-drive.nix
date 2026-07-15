{ config, lib, pkgs, ... }:

# ------------------------------------------------------------------
# 4TB storage drive (cold archive) with daily btrbk snapshots.
# ------------------------------------------------------------------
# Replacement for the WD 4TB that died 2026-07-14 (dropped off the
# SATA bus mid-backup). Now a Fanxiang S101 4TB SATA SSD — DRAM-less
# QLC, fine for cold storage, never for hot workloads (docker/ollama
# stay on the NVMe root pool).
#
# Layout — one btrfs, subvolumes instead of partitions:
#   @storage    /mnt/storage        important data (droplet-backups/,
#               local-backups/, 3d/, files/) — snapshotted daily
#   @media      /mnt/storage/media  graveyard; separate subvol so it is
#               automatically EXCLUDED from @storage snapshots
#   @snapshots  btrbk snapshot home
#
# The backup scripts (ops/files/downloadBackups, backupLocalState)
# write to /mnt/storage/{droplet,local}-backups — unchanged paths.
#
# Preconditions (manual, once):
#   sudo parted /dev/sdX -- mklabel gpt mkpart storage 1MiB 100%
#   sudo mkfs.btrfs -L storage /dev/sdX1
# First boot auto-creates the subvolumes (oneshot below).
#
# nofail everywhere: the machine must boot with the drive missing.

let
  storageLabel = "storage";
  storageUser  = "tom";
  storageMount = "/mnt/storage";
  btrTop       = "/mnt/storage-btr";
  btrTopUnit   = "mnt-storage\\x2dbtr.mount"; # systemd escapes '-' as \x2d
  # zstd:3 (code drive uses :1): archive workload, favor ratio over speed.
  commonOpts   = [ "noatime" "compress=zstd:3" "ssd" "discard=async" "space_cache=v2" "nofail" ];
in
{
  # ---- Mounts ------------------------------------------------------
  # Top of the filesystem (subvolid=5) is where btrbk lives + where we
  # create subvolumes. Kept out of the way at /mnt/storage-btr.
  fileSystems.${btrTop} = {
    device = "/dev/disk/by-label/${storageLabel}";
    fsType = "btrfs";
    options = [ "subvolid=5" "noatime" "nofail" ];
  };

  fileSystems.${storageMount} = {
    device = "/dev/disk/by-label/${storageLabel}";
    fsType = "btrfs";
    options = commonOpts ++ [ "subvol=@storage" ];
  };

  fileSystems."${storageMount}/media" = {
    device = "/dev/disk/by-label/${storageLabel}";
    fsType = "btrfs";
    options = commonOpts ++ [ "subvol=@media" ];
  };

  # ---- First-boot subvolume bootstrap ------------------------------
  # NixOS declarative mounts don't create subvolumes. Idempotent.
  systemd.services.storage-drive-subvolumes = {
    description = "Create @storage + @media + @snapshots subvolumes on the storage drive";
    wantedBy = [ "multi-user.target" ];
    after = [ btrTopUnit ];
    requires = [ btrTopUnit ];
    unitConfig.ConditionPathIsMountPoint = btrTop;
    before = [ "mnt-storage.mount" "mnt-storage-media.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for sv in @storage @media @snapshots; do
        if [ ! -e "${btrTop}/$sv" ]; then
          ${pkgs.btrfs-progs}/bin/btrfs subvolume create "${btrTop}/$sv"
        fi
      done
      ${pkgs.coreutils}/bin/chown ${storageUser}:users "${btrTop}/@storage" "${btrTop}/@media"
    '';
  };

  # ---- btrbk daily snapshots of @storage only -----------------------
  # @media is a separate subvol and never snapshotted. Tiered retention
  # paced for an archive: 7 dailies, 8 weeklies, 6 monthlies.
  services.btrbk = {
    instances.storage = {
      onCalendar = "daily";
      settings = {
        transaction_log       = "/var/log/btrbk.log";
        snapshot_preserve_min = "2d";
        snapshot_preserve     = "7d 8w 6m";
        volume.${btrTop} = {
          snapshot_dir = "@snapshots";
          subvolume."@storage" = { };
        };
      };
    };
  };
}
