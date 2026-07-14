{ config, pkgs, lib, ... }:

let
  # Single source for tom's home dir — no /home/tom hardcoding below.
  homeDir = config.users.users.tom.home;
in

# ------------------------------------------------------------------
# minerva-only system config that must SURVIVE a reinstall.
# ------------------------------------------------------------------
# hardware-minerva.nix gets clobbered by nixos-generate-config at
# install time, so anything hand-written for this host lives here
# instead: swap strategy, extra data drives, desktop-only apps.
# (nvidia.nix is the same idea for the GPU stack.)

{
  imports = [
    ./hardware.nix              # placeholder until nixos-generate-config at install
    ../../modules/nvidia.nix    # Blackwell dGPU: open module + recent kernel
    ../../modules/code-drive.nix
    ../../modules/ai.nix        # ollama-cuda, beads — big-GPU host only
    ../../modules/webcam.nix    # EMEET SmartCam S600 tooling + OBS virtual cam
    ../../modules/whisper-dictate.nix  # whisper.cpp voice dictation (F13 toggle)
    # INSTALL DAY: uncomment once the disk is LUKS-partitioned and
    # nixos-generate-config has written the cryptroot device into
    # hardware.nix — the module fails eval without a device (see
    # README "minerva install").
    # ../../modules/luks.nix
  ];

  # ---- Swap: zram, no swap partition -------------------------------
  # 64 GB RAM, zram0. Compressed
  # in-RAM swap; no disk partition to manage.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # ---- storage drive (WD 4TB, btrfs label "storage") ---------------
  # Bulk data drive, survives reinstalls. nofail so a missing/dead
  # drive never blocks boot.
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-label/storage";
    fsType = "btrfs";
    options = [ "noatime" "compress=zstd" "nofail" ];
  };

  # ---- Steam --------------------------------------------------------
  # programs.steam (not home.packages) because it needs the 32-bit
  # graphics stack and system-level driver plumbing.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
  };
  hardware.graphics.enable32Bit = true;

  # ---- OpenTabletDriver — input device config/firmware via its GUI.
  hardware.opentabletdriver.enable = true;

  # ---- ollama + beads live in modules/ai.nix ------------------------

  # ---- SMB share on the GL.iNet router (was ops/local.smb_mount.yml) -
  # Credentials must NOT live in the nix store. One-time post-install:
  #   sudo mkdir -p /etc/nixos-secrets
  #   printf 'username=dubious\npassword=%s\n' \
  #     "$(op read 'op://tomfordweb/Dubious Samba/password')" \
  #     | sudo tee /etc/nixos-secrets/dubious-smb >/dev/null
  #   sudo chmod 600 /etc/nixos-secrets/dubious-smb
  fileSystems."/mnt/dubious-smb" = {
    device = "//192.168.8.1/dubious";
    fsType = "cifs";
    options = [
      "credentials=/etc/nixos-secrets/dubious-smb"
      "uid=1000"
      "gid=1000"
      "nofail"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=300"
    ];
  };
  environment.systemPackages = [
    pkgs.cifs-utils
    pkgs.bambu-studio    # 3D-print slicer (desktop-only)
  ];

  # ---- Daily offsite/local backups (was ops/local.backup-strategy.yml)
  # NixOS has no /etc/cron.daily; run the ops scripts from the code
  # drive via systemd timers instead. Scripts stay in ops (single source
  # of truth); ConditionPathExists keeps boots clean before the code
  # drive is mounted/cloned. Both write to /mnt/storage. Machine-local SSH
  # target details live in /etc/nixos-secrets/ops-droplet.env:
  #   OPS_DROPLET_SSH_HOST=<local ssh alias>
  systemd.services.download-droplet-backups = {
    description = "Sync production droplet backups to /mnt/storage";
    path = with pkgs; [ bash coreutils findutils rsync openssh getent ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "-/etc/nixos-secrets/ops-droplet.env";
      ExecStart = "${pkgs.bash}/bin/bash ${homeDir}/code/tomfordweb/ops/files/downloadBackups";
    };
    unitConfig.ConditionPathExists = "${homeDir}/code/tomfordweb/ops/files/downloadBackups";
  };
  systemd.timers.download-droplet-backups = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  systemd.services.backup-local-state = {
    description = "Back up beads DBs + Claude config to /mnt/storage";
    path = with pkgs; [ bash coreutils findutils rsync gnutar gzip jq libnotify getent ]
      ++ [ "/run/wrappers" ];  # su (for the desktop notification)
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${homeDir}/code/tomfordweb/ops/files/backupLocalState";
    };
    unitConfig.ConditionPathExists = "${homeDir}/code/tomfordweb/ops/files/backupLocalState";
  };
  systemd.timers.backup-local-state = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
