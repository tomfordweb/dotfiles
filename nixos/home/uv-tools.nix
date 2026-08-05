{ pkgs, lib, config, ... }:

# ------------------------------------------------------------------
# uv tool installs — nix owns the LIST, uv owns the VERSIONS.
# ------------------------------------------------------------------
# Same deal as pnpm-globals.nix, for Python CLIs that have no nixpkgs
# attribute. graphify ships as the PyPI package `graphifyy`; packaging it
# as a buildPythonApplication would mean packaging every tree-sitter
# grammar it depends on, for a tool that already ships working wheels.
#
# The extras matter, not just the package: without [sql], graphify parses
# no .sql files and reports them as "contributed nothing to the graph
# because a dependency is missing: tree_sitter_sql not installed". Recording
# the extra here is the point — a uv receipt on one machine is not a
# declaration.
#
# Binaries land in ~/.local/bin (on PATH via shell.nix). Existing installs
# are never touched by activation; update everything with:
#
#   uv-tools-update

let
  # name = uv tool name (also the stamp filename)
  # spec = argument to `uv tool install` (package plus extras)
  # bins = entrypoints uv drops in ~/.local/bin — the presence check.
  #        All must exist, or the tool is (re)installed: a tool that gained
  #        an entrypoint upstream is otherwise never repaired.
  tools = [
    { name = "graphifyy"; spec = "graphifyy[sql]"; bins = [ "graphify" "graphify-mcp" ]; }
  ];

  uvBinDir = "${config.home.homeDirectory}/.local/bin";
  stampDir = "${config.home.homeDirectory}/.local/state/uv-tools";
  uvEnv = ''
    export PATH="${pkgs.uv}/bin:${uvBinDir}:$PATH"
    mkdir -p '${stampDir}'
  '';

  missingCheck = t:
    lib.concatMapStringsSep " || " (b: ''[ ! -e "${uvBinDir}/${b}" ]'') t.bins;

  # A bin-presence check alone is not enough: graphify was already installed
  # here WITHOUT [sql], so nothing was missing and nothing would ever be
  # repaired. The stamp records the spec that produced the current install, so
  # editing the spec above (adding an extra) reinstalls on the next activation.
  # --force because uv otherwise reports the tool as already present.
  installOne = t: ''
    if ${missingCheck t} || [ "$(cat '${stampDir}/${t.name}' 2>/dev/null)" != '${t.spec}' ]; then
      if $DRY_RUN_CMD uv tool install --force '${t.spec}'; then
        $DRY_RUN_CMD sh -c "printf '%s' '${t.spec}' > '${stampDir}/${t.name}'"
      else
        echo "WARNING: uv tool install ${t.spec} failed — install it by hand" >&2
      fi
    fi
  '';

  updateOne = t: ''
    uv tool install --force --upgrade '${t.spec}'
  '';

  updateScript = pkgs.writeShellScriptBin "uv-tools-update" ''
    # Update the uv tools declared in nixos/home/uv-tools.nix.
    set -eu
    ${uvEnv}
    ${lib.concatMapStrings updateOne tools}
  '';
in
{
  home.packages = [ pkgs.uv updateScript ];

  home.activation.uvTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${uvEnv}
    ${lib.concatMapStrings installOne tools}
  '';
}
