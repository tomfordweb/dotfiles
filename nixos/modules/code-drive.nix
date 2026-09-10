{ config, lib, pkgs, ... }:

# ------------------------------------------------------------------
# ~/code btrfs drive with hourly btrbk snapshots.
# ------------------------------------------------------------------
# Mirrors the setup that ansible does on minerva
# (ops/local.code-drive.yml, ops/files/btrbk-code.conf).
#
# Preconditions (do these manually before first boot):
#   1. A btrfs filesystem labeled "code" exists on some block device.
#      Create with: mkfs.btrfs -L code /dev/nvmeXnY
#   2. First boot will auto-create @code and @snapshots subvolumes
#      via the code-drive-subvolumes oneshot below.
#
# All fileSystems entries use nofail so the machine still boots if the
# drive is missing (e.g. testing on the T480 without the Crucial T500
# plugged in).

let
  codeLabel   = "code";
  codeUser    = "tom";
  codeMount   = "/home/${codeUser}/code";
  andromedaRoot = "${codeMount}/tomfordweb/andromeda";
  andromedaWorktrees = "${andromedaRoot}/.worktrees";
  andromedaClaudeWorktrees = "${andromedaRoot}/.claude/worktrees";
  andromedaWorktreesMount = "home-tom-code-tomfordweb-andromeda-.worktrees.mount";
  andromedaClaudeWorktreesMount = "home-tom-code-tomfordweb-andromeda-.claude-worktrees.mount";
  btrTop      = "/mnt/code-btr";
  btrTopUnit  = "mnt-code\\x2dbtr.mount"; # systemd escapes '-' as \x2d
  commonOpts  = [ "noatime" "compress=zstd:1" "ssd" "discard=async" "space_cache=v2" "nofail" ];
in
{
  # ---- Mounts ------------------------------------------------------
  # Top of the filesystem (subvolid=5) is where btrbk lives + where we
  # create subvolumes. Kept out of the way at /mnt/code-btr.
  fileSystems.${btrTop} = {
    device = "/dev/disk/by-label/${codeLabel}";
    fsType = "btrfs";
    options = [ "subvolid=5" "noatime" "nofail" ];
  };

  # ~/code is the @code subvol.
  fileSystems.${codeMount} = {
    device = "/dev/disk/by-label/${codeLabel}";
    fsType = "btrfs";
    options = commonOpts ++ [ "subvol=@code" ];
  };

  # Worktrees are disposable. Keep them in sibling subvolumes so snapshots of
  # @code retain the canonical checkout but not every worktree's dependencies,
  # caches, and build outputs. Btrfs does not recurse into nested subvolumes.
  #
  # Migration order matters: move existing worktrees into these subvolumes
  # before activating this configuration, otherwise the mounts hide them.
  fileSystems.${andromedaWorktrees} = {
    device = "/dev/disk/by-label/${codeLabel}";
    fsType = "btrfs";
    options = commonOpts ++ [ "subvol=@andromeda-worktrees" ];
  };

  fileSystems.${andromedaClaudeWorktrees} = {
    device = "/dev/disk/by-label/${codeLabel}";
    fsType = "btrfs";
    options = commonOpts ++ [ "subvol=@andromeda-claude-worktrees" ];
  };

  # ---- First-boot subvolume bootstrap ------------------------------
  # NixOS declarative mounts don't create subvolumes. This oneshot
  # runs after the top mount is up and creates @code + @snapshots
  # if they're missing. Idempotent.
  systemd.services.code-drive-subvolumes = {
    description = "Create @code + @snapshots subvolumes on the code drive";
    wantedBy = [ "multi-user.target" ];
    after = [ btrTopUnit ];
    requires = [ btrTopUnit ];
    unitConfig.ConditionPathIsMountPoint = btrTop;
    # The child mounts require this service. Without that ordering a first boot
    # races the mount units against subvolume creation and fails on the missing
    # subvolumes.
    before = [
      "home-${codeUser}-code.mount"
      andromedaWorktreesMount
      andromedaClaudeWorktreesMount
    ];
    requiredBy = [ andromedaWorktreesMount andromedaClaudeWorktreesMount ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for sv in @code @snapshots @andromeda-worktrees @andromeda-claude-worktrees; do
        if [ ! -e "${btrTop}/$sv" ]; then
          ${pkgs.btrfs-progs}/bin/btrfs subvolume create "${btrTop}/$sv"
        fi
      done
      # ~/code and disposable-worktree subvolumes are writable by ${codeUser}.
      ${pkgs.coreutils}/bin/chown ${codeUser}:users \
        "${btrTop}/@code" \
        "${btrTop}/@andromeda-worktrees" \
        "${btrTop}/@andromeda-claude-worktrees"
    '';
  };

  # ---- btrbk hourly snapshots (matches ops/files/btrbk-code.conf) --
  # Tiered retention: 24h hourly, 14d daily, 8w weekly. CoW means
  # each snapshot only stores deltas.
  services.btrbk = {
    instances.code = {
      onCalendar = "hourly";
      settings = {
        transaction_log     = "/var/log/btrbk.log";
        snapshot_preserve_min = "2h";
        snapshot_preserve   = "24h 14d 8w";
        volume.${btrTop} = {
          snapshot_dir = "@snapshots";
          subvolume."@code" = { };
        };
      };
    };
  };
}
