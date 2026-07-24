{
  # A flake is the modern entry point for a Nix project. Inputs are external
  # dependencies pinned in flake.lock; outputs are what this flake produces
  # (NixOS system configurations, packages, dev shells, etc.).
  description = "tom's NixOS config — minerva desktop, t480 laptop, iteration VM";

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
    # follows=nixpkgs keeps ONE nixpkgs evaluation (smaller closure, no ABI
    # split between compositor and system) at the cost of possible cachix
    # misses / local Hyprland builds. If that hurts, drop this input and use
    # nixpkgs' pkgs.hyprland instead.
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Reverse-engineered driver stack for the T480's Synaptics 06cb:009a
    # fingerprint sensor — mainline libfprint has no driver for it. Exposes a
    # NixOS module (imported only by hosts/t480) that runs open-fprintd +
    # python-validity. Deliberately NOT following our nixpkgs: the driver +
    # firmware packages are built against the branch's pinned nixos-25.05,
    # which is what upstream tests, so forcing them onto our unstable nixpkgs
    # risks Python/build breakage. open-fprintd/fprintd still come from our
    # system pkgs, so PAM integration tracks the rest of the system.
    nixos-06cb-009a-fingerprint-sensor.url = "github:ahbnr/nixos-06cb-009a-fingerprint-sensor?ref=25.05";
  };

  outputs = { self, nixpkgs, home-manager, hyprland, ... }@inputs:
    let
      system = "x86_64-linux";

      # Package overrides applied to every host. Keep these few and
      # justified — each one is a package nixpkgs no longer gets to update
      # for us. See the file for why beads is pinned here.
      overlays = [
        (final: prev: {
          # beads = prev.beads (the nixpkgs one), NOT final.beads — the
          # override takes the un-overridden package as its base, and
          # resolving it through `final` would recurse forever.
          beads = final.callPackage ./pkgs/beads.nix { beads = prev.beads; };
        })
      ];

      # A helper that builds a nixosSystem. Anything you'd want to vary
      # per host goes into `extraModules` (system-level) /
      # `homeModules` (home-manager, appended to the shared dev core).
      mkHost = { hostName, extraModules ? [], homeModules ? [] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs hostName; };
          modules = [
            ./modules/core.nix
            ./modules/hyprland.nix
            ./modules/tor.nix

            # Home Manager as a NixOS module so `nixos-rebuild switch`
            # also rebuilds user env in one shot.
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.tom.imports = [ ./home ] ++ homeModules;
            }

            # Per-host hostname + shared package overrides
            {
              networking.hostName = hostName;
              nixpkgs.overlays = overlays;
            }
          ] ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        # The VM output: minimal hardware, no LUKS. This is what
        # `nixos-rebuild build-vm --flake .#vm` builds.
        vm = mkHost {
          hostName = "nixos-vm";
          extraModules = [ ./hosts/vm ];
          homeModules = [ ./home/gui-apps.nix ];
        };

        # The T480 laptop: real hardware config (nixos-generate-config
        # output from the install) + LUKS + laptop extras.
        t480 = mkHost {
          hostName = "t480";
          extraModules = [ ./hosts/t480 ];
          homeModules = [ ./home/gui-apps.nix ];
        };

        # The desktop output: Intel Arrow Lake (Core Ultra 7 265K) +
        # a Blackwell NVIDIA dGPU. modules/nvidia.nix carries the
        # mandatory open-module + recent-kernel bits; modules/ai.nix
        # the GPU AI stack. LUKS at install — hosts/minerva/hardware.nix
        # is a placeholder until nixos-generate-config runs then.
        minerva = mkHost {
          hostName = "minerva";
          extraModules = [ ./hosts/minerva ];
          homeModules = [ ./home/gui-apps.nix ];
        };

        # Live-USB test image of the minerva system (details in
        # hosts/minerva-live/default.nix).
        minerva-live = mkHost {
          hostName = "minerva-live";
          extraModules = [ ./hosts/minerva-live ];
        };
      };
    };
}
