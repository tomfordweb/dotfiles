{
  # A flake is the modern entry point for a Nix project. Inputs are external
  # dependencies pinned in flake.lock; outputs are what this flake produces
  # (NixOS system configurations, packages, dev shells, etc.).
  description = "tom's NixOS config — VM for iteration, laptop for real install";

  inputs = {
    # nixos-unstable tracks the rolling release. Hyprland moves fast and
    # generally wants unstable. Switch to nixos-25.05 (or whatever the latest
    # stable branch is) if you'd rather trade freshness for stability.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home Manager: declarative user-level config (dotfiles, per-user packages).
    # Wired as a NixOS module below so `nixos-rebuild switch` updates both.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hyprland's own flake provides a newer compositor than nixpkgs sometimes
    # ships. The programs.hyprland module handles most of the wiring.
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs, home-manager, hyprland, ... }@inputs:
    let
      system = "x86_64-linux";

      # A helper that builds a nixosSystem. Anything you'd want to vary
      # per host (hostName, extra modules) goes into `extraModules` /
      # `hostName` args.
      mkHost = { hostName, extraModules ? [] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs hostName; };
          modules = [
            ./configuration.nix
            ./hyprland.nix

            # Home Manager as a NixOS module so `nixos-rebuild switch`
            # also rebuilds user env in one shot.
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.tom = import ./home.nix;
            }

            # Per-host hostname
            { networking.hostName = hostName; }
          ] ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        # The VM output: minimal hardware, no LUKS. This is what
        # `nixos-rebuild build-vm --flake .#vm` builds.
        vm = mkHost {
          hostName = "nixos-vm";
          extraModules = [ ./hardware-vm.nix ];
        };

        # The laptop output: real hardware config + LUKS.
        # Not usable until hardware-laptop.nix is replaced by the
        # nixos-generate-config output during real install.
        laptop = mkHost {
          hostName = "nixos-laptop";
          extraModules = [
            ./hardware-t480.nix
            ./luks.nix
            ./code-drive.nix
          ];
        };

        # The desktop output: Intel Arrow Lake (Core Ultra 7 265K) +
        # a Blackwell NVIDIA dGPU. nvidia.nix carries the mandatory
        # open-module + recent-kernel bits. Shares the "code" btrfs
        # drive with the ansible-managed setup. No LUKS (minerva runs
        # unencrypted today). hardware-minerva.nix is a placeholder until
        # nixos-generate-config runs at real install.
        minerva = mkHost {
          hostName = "minerva";
          extraModules = [
            ./hardware-minerva.nix
            ./nvidia.nix
            ./code-drive.nix
          ];
        };
      };
    };
}
