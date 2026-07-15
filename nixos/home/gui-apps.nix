{ pkgs, ... }:

# ------------------------------------------------------------------
# GUI / desktop apps — appended per host via mkHost homeModules.
# ------------------------------------------------------------------
# Not part of the dev core so a future headless host can skip it.

{
  # DBeaver -> droplet MySQL SSH tunnel (ex ops/local.dbeaver.yml).
  # 127.0.0.1:13306 -> droplet 127.0.0.1:3306 (MySQL is bound to the
  # droplet's localhost/docker bridges only). Auth is headless via the
  # 1Password SSH agent; the `droplet` host alias + user come from the
  # machine-local ~/.ssh/config.local (Included by ssh.nix). DBeaver
  # connections point at 127.0.0.1:13306 (data-sources.json is left to
  # DBeaver / a manual op-read on first connect — passwords never stored).
  systemd.user.services.dbeaver-droplet-tunnel = {
    Unit = {
      Description = "SSH tunnel to droplet MySQL for DBeaver (127.0.0.1:13306 -> droplet 127.0.0.1:3306)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      # 1Password SSH agent must be unlocked; socket path is the app default.
      Environment = "SSH_AUTH_SOCK=%h/.1password/agent.sock";
      ExecStart = "${pkgs.openssh}/bin/ssh -N"
        + " -o ExitOnForwardFailure=yes"
        + " -o ServerAliveInterval=30 -o ServerAliveCountMax=3"
        + " -o StrictHostKeyChecking=accept-new"
        + " -L 127.0.0.1:13306:127.0.0.1:3306 droplet";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Cursor theme — Bibata Modern Ice (white, rounded edges). home.pointerCursor
  # installs the theme package, sets the GTK cursor, and exports XCURSOR_THEME/
  # SIZE via hm-session-vars. Hyprland's OWN cursor is additionally pinned with
  # `env = XCURSOR_THEME,Bibata-Modern-Ice` in config/hypr/hyprland.conf, because
  # session vars don't reliably reach the compositor when it's launched from a
  # tty/greeter. Size 24 matches the XCURSOR_SIZE/HYPRCURSOR_SIZE env there.
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
  };

  home.packages = with pkgs; [
    # Browsers
    firefox
    chromium

    # Media / comms
    spotify
    discord
    slack

    # Dev GUIs
    dbeaver-bin

    # Desktop utils
    pavucontrol
    networkmanagerapplet
    yazi       # $fileManager in hyprland.conf (runs in ghostty)

    # Anonymity — pairs with the system tor daemon (modules/tor.nix)
    tor-browser
  ];
}
