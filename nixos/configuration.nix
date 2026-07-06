{ config, pkgs, lib, hostName, ... }:

{
  # ------------------------------------------------------------------
  # Locale, time, keyboard
  # ------------------------------------------------------------------
  time.timeZone = "America/New_York";      # change if needed
  i18n.defaultLocale = "en_US.UTF-8";

  # ------------------------------------------------------------------
  # Keyboard — Caps → Ctrl system-wide (TTY, X11, and any Wayland
  # compositor that respects xkb defaults). Hyprland sets the same
  # option in hyprland.conf so behavior matches on Arch too.
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
  boot.loader.efi.canTouchEfiVariables = true;

  # ------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------
  # NetworkManager mirrors what Ubuntu does (nmcli / GUI applet friendly).
  networking.networkmanager.enable = true;

  # ------------------------------------------------------------------
  # Users
  # ------------------------------------------------------------------
  users.users.tom = {
    isNormalUser = true;
    description = "tom";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
    shell = pkgs.bash;
    # INSECURE — only for VM testing convenience. First real login on the
    # laptop, log in via TTY and run `passwd` to set a real password,
    # then remove this line and rebuild.
    initialPassword = "nixos";
  };

  # Allow wheel-group users to sudo without password prompts in the VM.
  # Tighten this on the laptop if you'd rather type your password.
  security.sudo.wheelNeedsPassword = false;

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
  # SSH — handy for pushing changes to the VM later
  # ------------------------------------------------------------------
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # ------------------------------------------------------------------
  # Base system packages (available to all users)
  # ------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    file
    tree
    htop
    pciutils
    usbutils
    unzip
  ];

  # Allow unfree packages (Spotify, etc. — you'll want it).
  nixpkgs.config.allowUnfree = true;

  # ------------------------------------------------------------------
  # Docker
  # ------------------------------------------------------------------
  virtualisation.docker.enable = true;

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
  # Enable flakes for the installed system too
  # ------------------------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ------------------------------------------------------------------
  # State version
  # ------------------------------------------------------------------
  # This pins the release that determines default values for stateful
  # data (databases, etc.). Do NOT change this on an existing install —
  # it's a compatibility marker, not "which NixOS you want to run".
  system.stateVersion = "25.05";
}
