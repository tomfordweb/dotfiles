{ ... }:

# ------------------------------------------------------------------
# VM host — minimal hardware, no LUKS. Built with
#   nixos-rebuild build-vm --flake .#vm
# Exists for fast Hyprland/home-manager iteration.
# ------------------------------------------------------------------

{
  imports = [ ./hardware.nix ];
}
