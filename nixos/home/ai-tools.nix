{ pkgs, lib, config, ... }:

# ------------------------------------------------------------------
# AI tool wiring — Claude Code / codex config + shared MCP servers.
# ------------------------------------------------------------------
# Port of ops/local.ai.yml's local wiring into home-manager so it is
# nix-managed and reproducible (previously ansible-only).
#
# The canonical sources live in the OPS repo, checked out at
# ~/code/tomfordweb/ops (with its vendor/caveman submodule). This module
# only (re)creates the symlinks Claude/codex actually read + installs the
# pinned MCP npm servers — it does NOT vendor the content. If the ops repo
# is absent (e.g. a fresh VM), the activation guard skips everything.
#
# DEFERRED (still ops/local.ai.yml, not ported here): the blanket parent
# ~/code/tomfordweb/CLAUDE.md + per-project CLAUDE.tomfordweb.md wiring
# (those mutate OTHER repos, not this machine's config), opencode.jsonc
# rendering, and `claude/codex mcp add` registration (runtime ~/.claude.json
# state — the executable paths are re-registered on first use).

let
  home = config.home.homeDirectory;
  ops = "${home}/code/tomfordweb/ops";
  mcpHome = "${home}/.local/share/tomfordweb-mcp";
in
{
  # Pinned MCP server manifest (mirrors ops `ai_mcp_servers`). The activation
  # script npm-installs these into node_modules beside this file. All AI tools
  # launch `node ${mcpHome}/node_modules/<entry>` — no per-launch npx.
  # force: npm install rewrites package.json in place (identical content,
  # reformatted), turning the symlink into a plain file — without force every
  # later activation dies on the clobber check.
  home.file.".local/share/tomfordweb-mcp/package.json" = {
    force = true;
    text = builtins.toJSON {
      private = true;
      dependencies = {
        "@playwright/mcp" = "0.0.77";
        "@upstash/context7-mcp" = "3.2.2";
      };
    };
  };

  home.activation.tomfordwebAiWiring = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ops="${ops}"
    claude="$HOME/.claude"
    if [ -d "$ops/claude.tomfordweb" ]; then
      $DRY_RUN_CMD mkdir -p "$claude/skills" "$claude/agents"

      # SKILLS — global activation (~/.claude/skills is the only always-loaded
      # location). Canonical tomfordweb skills + the pinned caveman submodule.
      for d in "$ops"/claude.tomfordweb/skills/*/ "$ops"/vendor/caveman/skills/*/; do
        [ -e "$d" ] || continue
        $DRY_RUN_CMD ln -sfn "''${d%/}" "$claude/skills/$(basename "$d")"
      done

      # AGENTS — cavecrew subagents from the caveman submodule.
      for a in "$ops"/vendor/caveman/agents/*.md; do
        [ -e "$a" ] || continue
        $DRY_RUN_CMD ln -sfn "$a" "$claude/agents/$(basename "$a")"
      done

      # Top-level Claude config adopted into ops (settings.json is co-written by
      # Claude — version-controlling it is intentional).
      $DRY_RUN_CMD ln -sfn "$ops/claude.tomfordweb/settings.json" "$claude/settings.json"
      $DRY_RUN_CMD ln -sfn "$ops/claude.tomfordweb/CLAUDE.global.md" "$claude/CLAUDE.md"

      # codex global instructions (caveman always-on) — only if codex is set up.
      if [ -d "$HOME/.codex" ]; then
        $DRY_RUN_CMD ln -sfn "$ops/caveman.overlay/AGENTS.md" "$HOME/.codex/AGENTS.md"
      fi

      # Shared MCP servers — install the pinned npm deps once (idempotent).
      if [ ! -d "${mcpHome}/node_modules" ]; then
        $DRY_RUN_CMD ${pkgs.nodejs_22}/bin/npm install \
          --prefix "${mcpHome}" --no-audit --no-fund --omit=dev
      fi
    fi
  '';
}
