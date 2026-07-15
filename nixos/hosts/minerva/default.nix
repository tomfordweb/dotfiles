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
    # ollama-cuda is a huge uncached compile. It (and hyprland) hit random
    # cc1plus segfaults during the 2026-07-14 USB-installer build — NOT bad
    # RAM: 3 clean memtest86+ passes cleared it, and the delta was the
    # installer env (BIOS microcode 0x110 vs the installed 0x121; swapless
    # RAM-rootfs installer vs 31G zram here). Builds clean on the installed
    # system. NOTE: ai.nix also provides beads (bd).
    ../../modules/ai.nix      # ollama-cuda, beads — big-GPU host only
    ../../modules/webcam.nix    # EMEET SmartCam S600 tooling + OBS virtual cam
    ../../modules/whisper-dictate.nix  # whisper.cpp voice dictation (F13 toggle)
    ../../modules/root-snapshots.nix   # hourly btrbk snapshots of @ + @home
    # INSTALL DAY: uncomment once the disk is LUKS-partitioned and
    # nixos-generate-config has written the cryptroot device into
    # hardware.nix — the module fails eval without a device (see
    # README "minerva install").
    # ../../modules/luks.nix
  ];

  # ---- Memtest86+ in the boot menu ----------------------------------
  # Added 2026-07-14 after random cc1plus segfaults during the USB-installer
  # reinstall (two hyprland, one ollama ggml-cuda) that built clean on t480.
  # Root cause was installer-env, not hardware: 3 clean memtest86+ passes
  # cleared the RAM, and the installed system (newer microcode 0x121, 31G
  # zram swap) builds the same drvs fine. Tester kept a reboot away anyway.
  boot.loader.systemd-boot.memtest86.enable = true;

  # ---- Ethernet: Killer E5000 5GbE (2026-07-14) --------------------
  # The onboard NIC (PCI 10ec:5000, "Killer E5000") is a rebadged
  # Realtek RTL8126A and the in-kernel r8169 driver drives it fine — but
  # r8169's PCI id-table only auto-matches the plain RTL8126 (10ec:8126),
  # NOT the Killer's 10ec:5000, so nothing bound and no interface was
  # created. Force-load r8169 and feed it the extra id via new_id at
  # boot; enp130s0 then comes up and NetworkManager handles DHCP.
  # Drop this once nixpkgs' kernel carries 10ec:5000 in the id-table.
  boot.kernelModules = [ "r8169" ];
  systemd.services.killer-e5000-bind = {
    description = "Bind r8169 to the Killer E5000 NIC (PCI 10ec:5000)";
    wantedBy = [ "network-pre.target" ];
    before = [ "network-pre.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # new_id rescans and binds all matching unbound devices; a repeat
      # write (id already registered) returns EEXIST, hence `|| true`.
      ExecStart = "${pkgs.bash}/bin/sh -c 'echo 10ec 5000 > /sys/bus/pci/drivers/r8169/new_id || true'";
    };
  };

  # ---- Root snapshots: plain btrfs pool, no LUKS mapper -------------
  # The post-migration root is a whole-drive btrfs labelled "nixos"
  # (docs/nixos/minerva-btrfs-migration.md); override the module's
  # cryptroot default.
  tomfordweb.root-snapshots.device = "/dev/disk/by-label/nixos";

  # ---- OpenRGB: one daemon for all the RGB bullshit -----------------
  # MSI Mystic Light (Z890 GAMING PLUS WIFI, USB 0db0:0076), Logitech
  # Yeti Orb, GPU/RAM zones over i2c. motherboard="intel" loads
  # i2c-dev + i2c-i801 so SMBus zones are reachable. The Keychron V0
  # Ultra is QMK — OpenRGB only sees it with OpenRGB-QMK firmware;
  # stock firmware stays on VIA. Verify: openrgb --list-devices.
  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb-with-all-plugins;
    motherboard = "intel";
  };

  # ---- Swap: zram, no swap partition -------------------------------
  # 64 GB RAM, zram0. Compressed
  # in-RAM swap; no disk partition to manage.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # ---- storage drive: DEAD (2026-07-14) ------------------------------
  # The WD 4TB (btrfs label "storage") dropped off the SATA bus under
  # write load mid-backup (DID_BAD_TARGET, btrfs forced readonly) and no
  # longer answers SMART INQUIRY. Replacement ordered. Re-enable this
  # mount AND the two backup units below once the new drive is
  # partitioned btrfs + labelled "storage".
  # fileSystems."/mnt/storage" = {
  #   device = "/dev/disk/by-label/storage";
  #   fsType = "btrfs";
  #   options = [ "noatime" "compress=zstd" "nofail" ];
  # };

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
    # bambu-studio 02.x is unfree in nixpkgs → never cached, always a huge
    # local compile. Briefly disabled 2026-07-14 during the installer-env
    # segfault episode; RAM since cleared (3x memtest), builds fine here.
    pkgs.bambu-studio    # 3D-print slicer (desktop-only)
  ];

  # ---- Daily offsite/local backups (was ops/local.backup-strategy.yml)
  # NixOS has no /etc/cron.daily; run the ops scripts from the code
  # drive via systemd timers instead. Scripts stay in ops (single source
  # of truth); ConditionPathExists keeps boots clean before the code
  # drive is mounted/cloned. Both write to /mnt/storage. Machine-local SSH
  # target details live in /etc/nixos-secrets/ops-droplet.env:
  #   OPS_DROPLET_SSH_HOST=<local ssh alias>
  # DISABLED with the dead storage drive (both write to /mnt/storage) —
  # uncomment together with the mount above when the replacement lands.
  # systemd.services.download-droplet-backups = {
  #   description = "Sync production droplet backups to /mnt/storage";
  #   path = with pkgs; [ bash coreutils findutils rsync openssh getent ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     EnvironmentFile = "-/etc/nixos-secrets/ops-droplet.env";
  #     ExecStart = "${pkgs.bash}/bin/bash ${homeDir}/code/tomfordweb/ops/files/downloadBackups";
  #   };
  #   unitConfig.ConditionPathExists = "${homeDir}/code/tomfordweb/ops/files/downloadBackups";
  # };
  # systemd.timers.download-droplet-backups = {
  #   wantedBy = [ "timers.target" ];
  #   timerConfig = {
  #     OnCalendar = "daily";
  #     Persistent = true;
  #   };
  # };

  # systemd.services.backup-local-state = {
  #   description = "Back up beads DBs + Claude config to /mnt/storage";
  #   path = with pkgs; [ bash coreutils findutils rsync gnutar gzip jq libnotify getent ]
  #     ++ [ "/run/wrappers" ];  # su (for the desktop notification)
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = "${pkgs.bash}/bin/bash ${homeDir}/code/tomfordweb/ops/files/backupLocalState";
  #   };
  #   unitConfig.ConditionPathExists = "${homeDir}/code/tomfordweb/ops/files/backupLocalState";
  # };
  # systemd.timers.backup-local-state = {
  #   wantedBy = [ "timers.target" ];
  #   timerConfig = {
  #     OnCalendar = "daily";
  #     Persistent = true;
  #   };
  # };
}
