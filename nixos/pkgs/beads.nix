{ beads, fetchFromGitHub }:

# beads (bd) pinned ahead of nixpkgs.
#
# Why this exists: bd is the issue tracker every agent session in this setup
# talks to, so its version needs to be declared in this repo rather than being
# whatever nixpkgs happens to carry (1.0.3 at the time of writing) or whatever
# a hand-run installer dropped in ~/.local/bin. Two bd binaries on $PATH is a
# real failure mode — bd itself warns about it and upstream's troubleshooting
# guide lists it first, because two versions disagree about the DB schema.
#
# Bumping: set version + the two hashes, then `nixos-rebuild switch`. Get them
# by putting in the wrong hash and reading the "got:" line from the failure,
# or `nix flake prefetch --json github:gastownhall/beads/v<version>` for src.
# bin/ai-tools-check tells you when upstream has moved (registry entry in
# ai-tools/vendored.json).

beads.overrideAttrs (old: rec {
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "gastownhall";
    repo = "beads";
    tag = "v${version}";
    hash = "sha256-+dFV//0N8ZDw9BHOJOoWZ+BvLmJKlnGtONHIYPRhfBE=";
  };

  vendorHash = "sha256-WWEwGpCwMPD7jaz02zN745RQQqYTQttehbcT3J9hayM=";

  # Upstream's suite assumes a writable HOME, network, and a real git identity;
  # nixpkgs already skips one test for a version-gap assertion that this bump
  # invalidates anyway. The install check (`bd version`) still runs and is the
  # thing that actually matters here.
  doCheck = false;
})
