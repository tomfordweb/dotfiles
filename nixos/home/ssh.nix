{ ... }:

# ------------------------------------------------------------------
# SSH client extension point. Machine-specific host aliases stay outside Git
# because they can include private tailnet IPs, usernames, and local key paths.
# ------------------------------------------------------------------

{
  programs.ssh = {
    enable = true;
    extraConfig = ''
      Include ~/.ssh/config.local
      Include ~/.ssh/conf.d/*
    '';
  };
}
