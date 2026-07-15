{ pkgs, lib, config, ... }:

# ------------------------------------------------------------------
# pnpm global packages — nix owns the LIST, pnpm owns the VERSIONS.
# ------------------------------------------------------------------
# Fast-moving CLIs (AI agents, formatters) can't live in nixpkgs: the
# flake pin lags months behind and every bump costs a rebuild. Instead
# this activation installs any missing package with `pnpm add -g` —
# declarative membership, floating versions. Update everything with:
#
#   pnpm-globals-update
#
# (generated below from the same list — NOT `pnpm up -g`: pnpm only
# honors build-script approvals for globals via --allow-build at
# add-time, so a plain `up -g` reinstalls claude/opencode WITHOUT their
# postinstall and breaks their native binaries.)
#
# No rebuild needed to update. Binaries land in $PNPM_HOME/bin
# (~/.local/share/pnpm/bin, on PATH via shell.nix); the prebuilt native
# binaries inside the packages run thanks to nix-ld (core.nix).
#
# Existing installs are never touched by activation — a failed single
# install warns instead of aborting the whole activation.

let
  # spec   = argument to `pnpm add -g`
  # name   = package name, passed to --allow-build (pnpm v10+ blocks
  #          postinstall/prepare scripts by default; claude, opencode and
  #          sidemux all need theirs)
  # bin    = the shim dropped in $PNPM_HOME/bin — the presence check
  #          (the node_modules layout under global/<version>/ is hashed
  #          and version-dependent; bins aren't)
  # latest = include in pnpm-globals-update as spec@latest (false for
  #          git/link specs, which re-resolve from their source instead)
  globals = [
    { spec = "@anthropic-ai/claude-code"; name = "@anthropic-ai/claude-code"; bin = "claude";    latest = true; }
    { spec = "opencode-ai";               name = "opencode-ai";               bin = "opencode";  latest = true; }
    { spec = "@openai/codex";             name = "@openai/codex";             bin = "codex";     latest = true; }
    { spec = "prettier";                  name = "prettier";                  bin = "prettier";  latest = true; }
    { spec = "@fsouza/prettierd";         name = "@fsouza/prettierd";         bin = "prettierd"; latest = true; }
    # fresh installs need sidemux's prepare-script fix pushed to GitHub
    # (branch dashboard-fixes); on minerva it's already a link: install to
    # the local checkout, so it updates by rebuilding the checkout.
    { spec = "tomfordweb/sidemux";        name = "sidemux";                   bin = "sidemux";   latest = false; }
  ];
  pnpmHome = "${config.home.homeDirectory}/.local/share/pnpm";
  pnpmEnv = ''
    export PNPM_HOME="${pnpmHome}"
    # pnpm refuses global installs unless its bin dir is on PATH; node on
    # PATH for packages with install scripts.
    export PATH="$PNPM_HOME/bin:${pkgs.pnpm}/bin:${pkgs.nodejs_22}/bin:$PATH"
  '';
  installOne = g: ''
    if [ ! -e "$PNPM_HOME/bin/${g.bin}" ]; then
      $DRY_RUN_CMD pnpm add -g --allow-build='${g.name}' '${g.spec}' \
        || echo "WARNING: pnpm add -g ${g.spec} failed — install it by hand" >&2
    fi
  '';
  # resolve the version via `pnpm view` (always hits the registry) — a bare
  # `@latest` resolves through pnpm's metadata cache and can silently keep
  # an old version.
  updateOne = g: ''
    v=$(pnpm view '${g.name}' version)
    pnpm add -g --allow-build='${g.name}' '${g.spec}@'"$v"
  '';
  updateScript = pkgs.writeShellScriptBin "pnpm-globals-update" ''
    # Update the pnpm globals declared in nixos/home/pnpm-globals.nix.
    set -eu
    ${pnpmEnv}
    ${lib.concatMapStrings updateOne (builtins.filter (g: g.latest) globals)}
  '';
in
{
  home.packages = [ updateScript ];

  home.activation.pnpmGlobals = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pnpmEnv}
    ${lib.concatMapStrings installOne globals}
  '';
}
