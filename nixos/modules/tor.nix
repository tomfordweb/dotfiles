{ pkgs, ... }:

# ------------------------------------------------------------------
# Tor client — imported by ALL hosts (shared module list in flake.nix).
# ------------------------------------------------------------------
# Opt-in anonymity: a local Tor daemon exposing a SOCKS5 proxy at
# 127.0.0.1:9050. Nothing is routed through Tor automatically — point
# individual apps at the proxy, or wrap CLI tools with torsocks.
# Tor Browser (home.nix) ships its own bundled tor and doesn't need
# this daemon, but the daemon lets any other app opt in.
#
# Deliberately NOT a transparent proxy / relay / exit — that breaks
# Steam, Tailscale, and system updates, and adds DNS-leak surface.
#
# Verify: torsocks curl -s https://check.torproject.org/api/ip
#   → {"IsTor":true,...}

{
  services.tor = {
    enable = true;
    client.enable = true;   # SOCKS5 on 127.0.0.1:9050
  };

  environment.systemPackages = [ pkgs.torsocks ];
}
