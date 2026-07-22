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
        # COUPLED to pkgs.playwright-driver below: this mcp version resolves a
        # playwright-core that expects a specific chromium rev, and the nixpkgs
        # playwright-driver must ship that SAME rev (currently both -> 1228).
        # Bump the two together; a mismatch = "browser executable doesn't exist".
        "@playwright/mcp" = "0.0.77";
        "@upstash/context7-mcp" = "3.2.2";
      };
    };
  };

  # Playwright browser comes from nixpkgs (immutable /nix/store path), NOT from
  # `npx playwright install` into ~/.cache/ms-playwright/chromium-<n>. That cache
  # dir is mutable and its version suffix bumps on every install, which forced a
  # brittle hand-chased `--executable-path` pin (with a stale /home/tomford user)
  # baked into committed MCP configs. SKIP_DOWNLOAD stops any stray npx download.
  #
  # @playwright/mcp defaults to the `chrome` CHANNEL (system Google Chrome, which
  # isn't installed) — so it still needs an explicit --executable-path pointing at
  # the bundled chromium. PLAYWRIGHT_CHROMIUM_EXECUTABLE (set in the zsh init below)
  # is that full path; committed MCP configs reference it as an env var, so they
  # carry NO version suffix and NO /nix/store hash — both resolve per-machine here.
  home.sessionVariables = {
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  # Resolve the versioned chromium dir at login. The chromium-<rev> suffix tracks
  # the nixpkgs playwright-driver bump; globbing it here means a nixpkgs upgrade
  # needs no edit to any committed config. Glob `chromium-*` matches chromium-<rev>
  # but NOT chromium_headless_shell-<rev> (hyphen vs underscore) — single match.
  # mkAfter: runs after hm-session-vars.sh has exported PLAYWRIGHT_BROWSERS_PATH.
  programs.zsh.initContent = lib.mkAfter ''
    export PLAYWRIGHT_CHROMIUM_EXECUTABLE="$(echo "$PLAYWRIGHT_BROWSERS_PATH"/chromium-*/chrome-linux64/chrome)"
  '';

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
