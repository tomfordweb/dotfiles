{ config, pkgs, lib, hostName, ... }:

{
  # ------------------------------------------------------------------
  # Locale, time, keyboard
  # ------------------------------------------------------------------
  time.timeZone = "America/Detroit";
  i18n.defaultLocale = "en_US.UTF-8";

  # ------------------------------------------------------------------
  # Keyboard — Caps → Ctrl system-wide (TTY, X11, and any Wayland
  # compositor that respects xkb defaults). Hyprland sets the same
  # option in hyprland.conf.
  # ------------------------------------------------------------------
  services.xserver.xkb = {
    layout = "us";
    options = "ctrl:nocaps";
  };
  console.useXkbConfig = true;

  # ------------------------------------------------------------------
  # Bootloader (UEFI + systemd-boot)
  # ------------------------------------------------------------------
  # systemd-boot is the simplest UEFI bootloader. NixOS manages the
  # generations menu automatically.
  boot.loader.systemd-boot.enable = true;
  # Cap the generations menu so the ESP doesn't fill up over time.
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # ------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------
  # NetworkManager: nmcli / GUI applet friendly.
  networking.networkmanager.enable = true;

  # ------------------------------------------------------------------
  # Bluetooth
  # ------------------------------------------------------------------
  # bluetoothd + power the adapter at boot. Without this bluetoothctl
  # reports "no controller" even though the hci device exists.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  # Blueman: tray applet + GUI pairing manager for Hyprland/waybar.
  services.blueman.enable = true;

  # ------------------------------------------------------------------
  # Users
  # ------------------------------------------------------------------
  users.users.tom = {
    isNormalUser = true;
    description = "tom";
    # Pinned to 1000 so the minerva reinstall's migrated /home (from Pop
    # user `tomford`, also uid 1000) keeps valid ownership with no chown.
    uid = 1000;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
    shell = pkgs.zsh;
  };
  # NOTE: real installs ship with NO password for tom — after
  # `nixos-install` (which sets a root password), boot, switch to a TTY,
  # log in as root and run `passwd tom`. The insecure conveniences
  # (initialPassword, passwordless sudo, ssh password auth) are gated to
  # the VM variant only — see the vmVariant block at the bottom.

  # ------------------------------------------------------------------
  # Audio (PipeWire, replaces PulseAudio)
  # ------------------------------------------------------------------
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ------------------------------------------------------------------
  # SSH — key-only on real hosts; the VM variant re-enables password
  # auth (see vmVariant block below).
  # ------------------------------------------------------------------
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # ------------------------------------------------------------------
  # Base system packages (available to all users)
  # ------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    file
    tree
    htop
    pciutils
    usbutils
    unzip
    gcc            # nvim treesitter parser compiles + Mason builds
    gnumake        # same
    docker-compose # ops/local.wordpress_setup.yml dev workflow
  ];

  # Allow unfree packages (Spotify, etc. — you'll want it).
  nixpkgs.config.allowUnfree = true;

  # ------------------------------------------------------------------
  # Shell — zsh system-wide (replaces bash/oh-my-bash).
  # ------------------------------------------------------------------
  # Enabling here registers zsh in /etc/shells and sets up completion,
  # which is required before it can be a user's login shell. Per-user
  # zsh config (oh-my-zsh, starship) lives in home.nix.
  programs.zsh.enable = true;

  # ------------------------------------------------------------------
  # Docker
  # ------------------------------------------------------------------
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    # overlay2 (what Pop already ran) rather than the btrfs storage driver,
    # even though /var/lib/docker is a btrfs subvol on minerva — avoids the
    # btrfs-driver subvolume sprawl/quirks. Named volumes (the critical dev
    # data) are plain dirs under volumes/ and are unaffected by this choice.
    storageDriver = "overlay2";
  };

  # ------------------------------------------------------------------
  # Tailscale — all hosts are in the tailnet.
  # `tailscale up` once per machine to authenticate.
  # ------------------------------------------------------------------
  services.tailscale.enable = true;

  # ------------------------------------------------------------------
  # Misc services
  # ------------------------------------------------------------------
  services.flatpak.enable = true;   # GUI apps outside nixpkgs (slack, etc.)
                                    # one-time: flatpak remote-add flathub (see README)
  services.fwupd.enable = true;     # firmware updates (fwupdmgr)
  services.printing.enable = true;  # CUPS
  # upower / power-profiles-daemon are laptop concerns — modules/laptop.nix

  # Run non-nix dynamically-linked binaries (downloaded CLIs, Mason
  # one-offs, etc.) without patching.
  programs.nix-ld.enable = true;

  # ------------------------------------------------------------------
  # 1Password (desktop + CLI). GUI needs polkit integration for
  # system auth prompts; declaring the owner group grants that.
  # ------------------------------------------------------------------
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "tom" ];
  };

  # ------------------------------------------------------------------
  # VM variant (any host built with `.config.system.build.vm`)
  # ------------------------------------------------------------------
  # Mount the host dotfiles into the guest at the guest user's path so
  # the home-manager dotfile symlinks (~/.config/hypr → repo) resolve
  # and Hyprland picks up the live setup instead of autogenerating a
  # default one. Lives here (not hosts/vm) so minerva/laptop VM builds
  # get it too.
  # vmVariant only affects the VM wrapper — real installs ignore it.
  #
  # `source` is expanded by the shell inside the generated run-*-vm
  # script, so $HOME resolves to whoever launches the VM. The guest
  # user is always `tom`, but the host launching the VM may not be
  # yet (minerva pre-migration) — a hardcoded /home/tom source would
  # silently share a nonexistent dir and the guest falls back to
  # default Hyprland config.
  virtualisation.vmVariant.virtualisation.sharedDirectories.dotfiles = {
    source = "$HOME/code/tomfordweb/dotfiles";
    target = "/home/tom/code/tomfordweb/dotfiles";
  };

  # VM-only insecure conveniences. Real installs get none of these:
  # no initial password (set via root after nixos-install), sudo asks
  # for a password, ssh is key-only.
  virtualisation.vmVariant.users.users.tom.initialPassword = "nixos";
  virtualisation.vmVariant.security.sudo.wheelNeedsPassword = false;
  virtualisation.vmVariant.services.openssh.settings.PasswordAuthentication = lib.mkForce true;

  # QEMU: host WM swallows Super, so switch Hyprland's mod to Alt inside
  # VMs only. hyprland.conf sources ~/.config/hypr-local/*.conf (outside
  # the shared repo AND outside the ~/.config/hypr symlink into it);
  # tmpfiles drops the override there each VM boot. Real installs never
  # get this file, so Super stays the mod.
  virtualisation.vmVariant.systemd.tmpfiles.rules = [
    "d /home/tom/.config 0755 tom users -"
    "d /home/tom/.config/hypr-local 0755 tom users -"
    "C+ /home/tom/.config/hypr-local/qemu-mainmod.conf 0644 tom users - ${pkgs.writeText "qemu-mainmod.conf" ''
      $mainMod = ALT
    ''}"
  ];

  # ------------------------------------------------------------------
  # Enable flakes for the installed system too
  # ------------------------------------------------------------------
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "tom" ];
  };
  # Weekly garbage collection so old generations don't eat the disk.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # ------------------------------------------------------------------
  # State version
  # ------------------------------------------------------------------
  # This pins the release that determines default values for stateful
  # data (databases, etc.). Do NOT change this on an existing install —
  # it's a compatibility marker, not "which NixOS you want to run".
  system.stateVersion = "25.05";
}
