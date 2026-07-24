{ pkgs, lib, config, ... }:

# ------------------------------------------------------------------
# AI tool wiring — Claude Code / opencode / codex config + shared MCP
# servers. Full port of ops/local.ai.yml into home-manager: `ops` no
# longer carries ANY AI-agent configuration.
# ------------------------------------------------------------------
# Canonical content now lives INSIDE this repo at ./ai-tools/ (public —
# generic ideas only, no tomfordweb-specific facts) plus a vendored
# ./ai-tools/vendor/caveman submodule (public upstream). The one piece of
# genuinely private, tomfordweb-specific content (deploy conventions,
# secrets scheme, DB naming, etc.) lives in the private `wiki` repo,
# checked out as the `docs` submodule of this repo (`dotfiles/docs`) —
# never in this public repo's own tracked files.
#
# This module (re)creates the symlinks/config Claude/opencode/codex
# actually read, renders opencode.jsonc, registers MCP servers with
# claude/codex, and wires the blanket + per-project tomfordweb rules
# import into other repos under ~/code — all driven from content that
# ships with THIS checkout, no external `ops` dependency.

let
  home = config.home.homeDirectory;
  dotfiles = "${home}/code/tomfordweb/dotfiles";
  aiTools = "${dotfiles}/ai-tools";
  wikiRules = "${dotfiles}/docs/ai/tomfordweb.md";
  mcpHome = "${home}/.local/share/tomfordweb-mcp";
  xdgConfigHome = "${home}/.config";
  opencodeLive = "${xdgConfigHome}/opencode";

  # Mirrors the old ops `ai_mcp_servers` registry. npm-backed servers launch
  # `node <mcpHome>/node_modules/<entry>` (no npx — ~10x faster per-launch);
  # sidemux is PATH-resolved so the sidemux repo's own flake+direnv shim can
  # shadow it with a local build without any config change here.
  npmServers = [
    {
      name = "playwright";
      entry = "@playwright/mcp/cli.js";
      # $CHROME resolved by the activation script below (chromium-<rev> is
      # not knowable at eval time, only after the store path is realized).
      args = [ "--executable-path" "$CHROME" ];
    }
    { name = "context7"; entry = "@upstash/context7-mcp/dist/index.js"; args = [ ]; }
  ];
  sidemux = { name = "sidemux"; command = "sidemux"; env = { SIDEMUX_SESSION = "smux"; }; };

  mcpPackageJson = pkgs.writeText "tomfordweb-mcp-package.json" (builtins.toJSON {
    private = true;
    dependencies = {
      # COUPLED to pkgs.playwright-driver below: this mcp version resolves a
      # playwright-core that expects a specific chromium rev, and the nixpkgs
      # playwright-driver must ship that SAME rev. Bump the two together.
      "@playwright/mcp" = "0.0.77";
      "@upstash/context7-mcp" = "3.2.2";
    };
  });

  opencodeModels = {
    "qwen2.5:72b".name = "Qwen2.5 72B";
    "qwen2.5:14b-instruct-q5_K_M".name = "Qwen2.5 14B";
    "qwen2.5-coder:32b".name = "Qwen2.5 Coder 32B";
    "qwen2.5-coder:14b-instruct-q5_K_M".name = "Qwen2.5 Coder 14B";
    "llama3.3:latest".name = "Llama 3.3";
    "deepseek-r1:32b".name = "DeepSeek-R1 32B";
  };
  ollamaHost = "127.0.0.1:11434";

  # ------------------------------------------------------------------
  # CLI tooling the agents lean on constantly (beads, graphify, workmux,
  # forge CLIs). Declared ONCE here and rendered into each tool's own
  # permission dialect below, so "bd ready stopped prompting in Claude but
  # still prompts in opencode" can't happen.
  #
  #   allowedCommands — safe to run unattended. Reads, plus the beads
  #     mutations the agent workflow is made of (create/update/close): being
  #     asked to confirm every `bd update --claim` defeats the tracker.
  #   askCommands     — destructive or publishing; always confirm. Listed
  #     explicitly because a plain prefix like "bd" would otherwise swallow
  #     `bd delete`.
  #
  # Claude Code reads its own copy from ai-tools/settings.json (its schema is
  # "Bash(cmd:*)" strings and that file is hand-maintained); keep the three
  # in sync when editing.
  # ------------------------------------------------------------------
  allowedCommands = [
    # beads — reads
    "bd prime" "bd ready" "bd list" "bd show" "bd search" "bd query" "bd count"
    "bd blocked" "bd stats" "bd status" "bd info" "bd context" "bd version"
    "bd graph" "bd diff" "bd history" "bd children" "bd comments" "bd epic"
    "bd stale" "bd orphans" "bd lint" "bd preflight" "bd types" "bd statuses"
    "bd memories" "bd recall" "bd config get" "bd config list" "bd config show"
    "bd worktree list" "bd worktree info"
    "bd dolt show" "bd dolt status" "bd dolt remote list" "bd dolt pull"
    # beads — the routine workflow mutations
    "bd create" "bd update" "bd close" "bd reopen" "bd note" "bd comment"
    "bd label" "bd tag" "bd priority" "bd assign" "bd dep" "bd defer"
    "bd undefer" "bd todo" "bd q" "bd remember" "bd export"
    # graphify — query the knowledge graph, never mutate installs
    "graphify path" "graphify explain" "graphify diagnose"
    # workmux — inspect only; add/rm/merge stay interactive
    "workmux ls" "workmux list" "workmux status" "workmux path"
    "workmux capture" "workmux docs" "workmux changelog"
    # forge CLIs — read paths
    "gh pr view" "gh pr list" "gh pr diff" "gh pr checks"
    "gh issue view" "gh issue list" "gh run view" "gh run list" "gh repo view"
    "glab mr view" "glab mr list" "glab mr diff"
    "glab issue view" "glab issue list" "glab ci status"
    # local helpers
    "wtport" "ai-tools-check"
  ];
  askCommands = [
    "bd delete" "bd rename" "bd init" "bd dolt push"
    "graphify install" "graphify uninstall"
    "workmux rm" "workmux merge"
    # Node installs execute arbitrary lifecycle scripts (preinstall/postinstall)
    # off the network, so they are a supply-chain step, not a read. Same reason
    # `pnpm rebuild`/`approve-builds` and the one-off runners (dlx/npx/bunx) are
    # here: each one can run a package's own code the first time it is fetched.
    # Short aliases are listed alongside the long forms because these match on
    # literal argv tokens: `pnpm i` is not covered by a `pnpm install` rule.
    "pnpm install" "pnpm i" "pnpm add" "pnpm update" "pnpm up" "pnpm dlx"
    "pnpm rebuild" "pnpm approve-builds"
    "npm install" "npm i" "npm ci" "npm update" "npm rebuild" "npx"
    "yarn install" "yarn add" "yarn upgrade" "yarn dlx"
    "bun install" "bun i" "bun add" "bun x" "bunx"
  ];

  # Note: sidemux is an MCP server, not a CLI — driving it means calling
  # `mcp__sidemux__<tool>`, which neither dialect rendered here can express
  # (codex's execpolicy covers exec only, opencode's permission.bash matches
  # command strings). Its allow/ask split therefore lives only in
  # ai-tools/settings.json: run/read/wait/status/list_panes/send_keys allowed,
  # kill/close_all ask.

  # opencode: { "bd ready *": "allow", … }. Wildcard match, last matching rule
  # wins — and nix serialises attrsets alphabetically, which is exactly the
  # order we need: "bd dolt pull" sorts before "bd dolt push" only by accident,
  # but a prefix always sorts before its own extensions (space < any letter),
  # so "bd delete" lands after "bd" and overrides it.
  # Two patterns per command on purpose: opencode matches the whole command
  # string, so "bd ready *" covers `bd ready --json` but NOT a bare `bd ready`.
  opencodePermissions = lib.listToAttrs (
    (lib.concatMap (c: [ (lib.nameValuePair c "allow") (lib.nameValuePair "${c} *" "allow") ]) allowedCommands)
    ++ (lib.concatMap (c: [ (lib.nameValuePair c "ask") (lib.nameValuePair "${c} *" "ask") ]) askCommands)
  );

  # codex: a rules file of prefix_rule() calls. Codex applies the MOST
  # RESTRICTIVE match, so an "allow" prefix can't accidentally widen a
  # "prompt" one — no ordering games needed here.
  codexRules = pkgs.writeText "tomfordweb.rules" (
    ''
      # Generated by dotfiles/nixos/home/ai-tools.nix — do not edit by hand.
      # Auto-approval for the CLI tooling every tomfordweb session uses.
      # Check a command against these rules with:
      #   codex execpolicy check --pretty --rules ~/.codex/rules/tomfordweb.rules -- bd ready

    ''
    + lib.concatMapStrings
      (c: "prefix_rule(pattern = [${lib.concatMapStringsSep ", " (w: "\"${w}\"") (lib.splitString " " c)}], decision = \"allow\")\n")
      allowedCommands
    + "\n"
    + lib.concatMapStrings
      (c: "prefix_rule(pattern = [${lib.concatMapStringsSep ", " (w: "\"${w}\"") (lib.splitString " " c)}], decision = \"prompt\")\n")
      askCommands
  );

  # opencode.jsonc — mirrors ops/templates/opencode.jsonc.j2's shape. Built
  # by nix (structure/typos are eval-time checked) but the playwright
  # chromium path can only be resolved at activation time (bash glob against
  # the realized store path, same reason as $CHROME above) — so this is a
  # TEMPLATE with a placeholder, substituted by the activation script below,
  # not a `home.file` served straight from the nix store.
  opencodeJsonTemplate = pkgs.writeText "opencode.jsonc.tmpl" (builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    shell = "/bin/zsh";
    mcp =
      (lib.listToAttrs (map
        (s: lib.nameValuePair s.name {
          type = "local";
          command = [ "node" "${mcpHome}/node_modules/${s.entry}" ] ++ s.args;
        })
        npmServers))
      // {
        "${sidemux.name}" = {
          type = "local";
          command = [ sidemux.command ];
          environment = sidemux.env;
        };
      };
    provider.ollama = {
      npm = "@ai-sdk/openai-compatible";
      name = "Ollama";
      options.baseURL = "http://${ollamaHost}/v1";
      models = opencodeModels;
    };
    # No "*" catch-all: unlisted commands keep opencode's own default rather
    # than being forced to "ask" by our config.
    permission.bash = opencodePermissions;
    plugin = [
      "./plugins/caveman/plugin.js"
      "./plugins/claude-compat.ts"
      "./plugins/workmux-status.ts"
      "./plugins/voice-capture.ts"
    ];
  });
in
{
  # sox — audio recording backend for Claude Code's /voice mode.
  home.packages = with pkgs; [ sox ];

  home.file.".local/share/tomfordweb-mcp/package.json" = {
    force = true;
    source = mcpPackageJson;
  };

  home.sessionVariables = {
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  programs.zsh.initContent = lib.mkAfter ''
    export PLAYWRIGHT_CHROMIUM_EXECUTABLE="$(echo "$PLAYWRIGHT_BROWSERS_PATH"/chromium-*/chrome-linux64/chrome)"

    # Pinned/vendored AI tooling staleness. The banner is CACHE-ONLY (no network,
    # no git) so it costs nothing at login; the refresh that populates that cache
    # is detached and rate-limited to once a day. AI_TOOLS_CHECK=0 disables both.
    if [[ -o interactive ]] && [ "''${AI_TOOLS_CHECK:-1}" != "0" ]; then
      ai-tools-check 2>/dev/null
      (ai-tools-check --refresh >/dev/null 2>&1 &) 2>/dev/null
    fi
  '';

  # ------------------------------------------------------------------
  # Voice/preference profile — fully automatic, nothing to run by hand.
  # Live capture happens in the per-tool hooks (claude settings.json, codex
  # hooks.json, opencode voice-capture plugin); this timer backfills anything
  # the hooks missed, rebuilds the derived profiles, and lands them in the
  # PRIVATE wiki submodule. First run does the full historical backfill.
  # ------------------------------------------------------------------
  systemd.user.services.voice-profile = {
    Unit.Description = "Rebuild writing-voice + preference profiles from agent transcripts";
    Service = {
      Type = "oneshot";
      Nice = 10;
      Environment = [ "PATH=${lib.makeBinPath [ pkgs.git pkgs.python3 pkgs.coreutils ]}:${dotfiles}/bin" ];
      # VOICE_PROFILE_ROLE=capture-only on hosts without a local model: they
      # still collect turns, but consume profiles that arrive via the submodule.
      ExecStart = pkgs.writeShellScript "voice-profile-run" ''
        set -uo pipefail
        cd "${dotfiles}" || exit 0
        voice-corpus || exit 0
        [ "''${VOICE_PROFILE_ROLE:-full}" = "capture-only" ] && exit 0
        voice-profile || exit 0

        # Auth to land the data: commit + push ONLY the voice files, ONLY inside
        # the private wiki submodule. This is a deliberate, narrow carve-out from
        # the standing "no push without explicit approval" rule (same shape as
        # the beads-chore exception) — any other changed path aborts the push.
        [ "''${VOICE_CORPUS_AUTOPUSH:-1}" = "1" ] || exit 0
        cd "${dotfiles}/docs" || exit 0
        git add -- ai/voice ai/writing-voice-observed.md ai/preferences-observed.md 2>/dev/null
        git diff --cached --quiet && exit 0
        if [ -n "$(git diff --cached --name-only | grep -v '^ai/\(voice/\|writing-voice-observed\|preferences-observed\)' || true)" ]; then
          echo "refusing: staged changes outside ai/voice" >&2
          git reset >/dev/null 2>&1
          exit 1
        fi
        git commit -q -m "chore(voice): refresh corpus + derived profiles" || exit 0
        git push -q || echo "voice profile: push failed (left committed locally)" >&2
      '';
    };
  };

  systemd.user.timers.voice-profile = {
    Unit.Description = "Daily writing-voice profile refresh";
    Timer = {
      OnCalendar = "daily";
      # First boot after install: run the historical backfill without waiting a day.
      OnStartupSec = "10m";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  home.activation.tomfordwebAiWiring = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    aiTools="${aiTools}"
    claude="$HOME/.claude"
    CHROME=$(echo "${pkgs.playwright-driver.browsers}"/chromium-*/chrome-linux64/chrome)

    if [ -d "$aiTools" ]; then
      $DRY_RUN_CMD mkdir -p "$claude/skills" "$claude/agents"

      # ---- Claude: skills, cavecrew agents, settings.json, CLAUDE.md, hooks
      for d in "$aiTools"/skills/*/ "$aiTools"/vendor/caveman/skills/*/; do
        [ -e "$d" ] || continue
        $DRY_RUN_CMD ln -sfn "''${d%/}" "$claude/skills/$(basename "$d")"
      done
      for a in "$aiTools"/vendor/caveman/agents/*.md; do
        [ -e "$a" ] || continue
        $DRY_RUN_CMD ln -sfn "$a" "$claude/agents/$(basename "$a")"
      done
      $DRY_RUN_CMD ln -sfn "$aiTools/settings.json" "$claude/settings.json"
      $DRY_RUN_CMD ln -sfn "$aiTools/CLAUDE.md" "$claude/CLAUDE.md"

      # ---- codex: skills + always-on global instructions.
      # codex reads $CODEX_HOME/skills, so the same skill set Claude gets is
      # symlinked in (opencode gets them through its own skills/ dir, which is
      # already a symlink to $aiTools/opencode/skills).
      if [ -d "$HOME/.codex" ]; then
        $DRY_RUN_CMD mkdir -p "$HOME/.codex/skills"
        for d in "$aiTools"/skills/*/ "$aiTools"/vendor/caveman/skills/*/; do
          [ -e "$d" ] || continue
          $DRY_RUN_CMD ln -sfn "''${d%/}" "$HOME/.codex/skills/$(basename "$d")"
        done

        # exec-policy rules — auto-approval for the shared CLI tooling.
        # config.toml is deliberately NOT touched: codex rewrites it itself
        # (trust hashes, project entries), so rules/ is the part we can own.
        $DRY_RUN_CMD mkdir -p "$HOME/.codex/rules"
        $DRY_RUN_CMD ln -sfn "${codexRules}" "$HOME/.codex/rules/tomfordweb.rules"
      fi

      # ---- Shared always-on ruleset for opencode + codex.
      # Claude gets AGENTS.shared.md via an @import at the top of CLAUDE.md, but
      # opencode and codex load their instruction file as RAW TEXT and do not
      # resolve @imports (same reason caveman-overlay/AGENTS.md exists at all).
      # So their slot is a RENDERED concatenation, not a symlink: caveman rules
      # first, then the shared rules. Edits to either source therefore need a
      # `nixos-rebuild switch` to take effect for those two tools — unlike the
      # live symlinks everywhere else in this module.
      renderShared() {
        cat "$aiTools/caveman-overlay/AGENTS.md" "$aiTools/AGENTS.shared.md" > "$1.tmp" \
          && mv "$1.tmp" "$1"
      }
      if [ -d "$HOME/.codex" ]; then
        [ -L "$HOME/.codex/AGENTS.md" ] && $DRY_RUN_CMD rm -f "$HOME/.codex/AGENTS.md"
        $DRY_RUN_CMD renderShared "$HOME/.codex/AGENTS.md"

        # codex: voice capture on every prompt (claude gets this through
        # settings.json, opencode through its plugin). Idempotent — only added
        # when absent. codex re-trusts changed hooks on next launch.
        if [ -f "$HOME/.codex/hooks.json" ] && ! grep -q voice-capture "$HOME/.codex/hooks.json"; then
          $DRY_RUN_CMD ${pkgs.python3}/bin/python3 - "$HOME/.codex/hooks.json" <<'PYEOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
hooks = d.setdefault("hooks", {}).setdefault("UserPromptSubmit", [])
hooks.append({"hooks": [{
    "command": "VOICE_CAPTURE_SOURCE=codex ${dotfiles}/bin/voice-capture",
    "type": "command",
}]})
json.dump(d, open(p, "w"), indent=2)
PYEOF
        fi
      fi

      # ---- Shared MCP servers — one-time npm install of the pinned deps
      if [ ! -d "${mcpHome}/node_modules" ]; then
        $DRY_RUN_CMD ${pkgs.nodejs_22}/bin/npm install \
          --prefix "${mcpHome}" --no-audit --no-fund --omit=dev
      fi

      # ---- Register MCP servers with claude + codex (idempotent — both
      # CLIs no-op on "already exists"; tolerate nonzero exit either way)
      ${lib.concatMapStrings (s: ''
        $DRY_RUN_CMD claude mcp add --scope user "${s.name}" -- node "${mcpHome}/node_modules/${s.entry}" ${lib.concatStringsSep " " s.args} || true
        if [ -d "$HOME/.codex" ]; then
          $DRY_RUN_CMD codex mcp add "${s.name}" -- node "${mcpHome}/node_modules/${s.entry}" ${lib.concatStringsSep " " s.args} || true
        fi
      '') npmServers}
      $DRY_RUN_CMD claude mcp add --scope user "${sidemux.name}" ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "-e ${k}=${v}") sidemux.env)} -- ${sidemux.command} || true
      if [ -d "$HOME/.codex" ]; then
        $DRY_RUN_CMD codex mcp add "${sidemux.name}" ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "--env ${k}=${v}") sidemux.env)} -- ${sidemux.command} || true
      fi

      # ---- opencode: static assets + rendered opencode.jsonc
      $DRY_RUN_CMD mkdir -p "${opencodeLive}"
      for entry in plugins skills agents commands; do
        target="${opencodeLive}/$entry"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
          $DRY_RUN_CMD rm -rf "$target"
        fi
        $DRY_RUN_CMD ln -sfn "$aiTools/opencode/$entry" "$target"
      done
      # AGENTS.md is rendered (see renderShared above), not symlinked.
      [ -L "${opencodeLive}/AGENTS.md" ] && $DRY_RUN_CMD rm -f "${opencodeLive}/AGENTS.md"
      $DRY_RUN_CMD renderShared "${opencodeLive}/AGENTS.md"
      $DRY_RUN_CMD cp "$aiTools/opencode/package.json" "${opencodeLive}/package.json"
      $DRY_RUN_CMD cp "$aiTools/opencode/package-lock.json" "${opencodeLive}/package-lock.json"
      if [ ! -d "${opencodeLive}/node_modules" ]; then
        $DRY_RUN_CMD ${pkgs.nodejs_22}/bin/npm install --prefix "${opencodeLive}" --no-audit --no-fund
      fi
      $DRY_RUN_CMD sed "s|\$CHROME|$CHROME|" "${opencodeJsonTemplate}" > "${opencodeLive}/opencode.jsonc"

      # ---- Blanket parent CLAUDE.md + per-project wiring — both need the
      # private wiki rules file to exist (it's in a separate, private repo
      # checked out as a submodule of this one; skip cleanly if absent, e.g.
      # a fresh machine before that submodule is initialized).
      if [ -f "${wikiRules}" ]; then
      $DRY_RUN_CMD mkdir -p "${home}/code/tomfordweb"
      parentClaude="${home}/code/tomfordweb/CLAUDE.md"
      marker_begin="<!-- ANSIBLE MANAGED: tomfordweb shared claude rules -->"
      marker_end="<!-- /ANSIBLE MANAGED: tomfordweb shared claude rules -->"
      block="$marker_begin
# tomfordweb — shared Claude rules (parent)

Applies to every project under \`~/code/tomfordweb/\` (Claude loads CLAUDE.md
up the directory tree). Canonical source is the private \`wiki\` repo,
checked out as \`dotfiles/docs\`. Managed by dotfiles/nixos/home/ai-tools.nix —
edit there, not here.

@${wikiRules}
$marker_end"
      if [ -f "$parentClaude" ] && grep -qF "$marker_begin" "$parentClaude"; then
        $DRY_RUN_CMD ${pkgs.gawk}/bin/awk -v b="$marker_begin" -v e="$marker_end" -v block="$block" '
          $0==b {print block; skip=1; next}
          $0==e {skip=0; next}
          !skip {print}
        ' "$parentClaude" > "$parentClaude.tmp" && $DRY_RUN_CMD mv "$parentClaude.tmp" "$parentClaude"
      else
        $DRY_RUN_CMD printf '%s\n' "$block" >> "$parentClaude"
      fi

      # ---- Per-project wiring for tomfordweb repos opened standalone
      # OUTSIDE ~/code/tomfordweb (e.g. a separate top-level checkout) — the
      # blanket parent CLAUDE.md above already covers everything nested
      # under ~/code/tomfordweb, so this only needs to reach the rest.
      # No repo names are hardcoded: scan for real git repo roots (a `.git`
      # DIRECTORY — submodules mount as a `.git` FILE, so this filter
      # already skips them) whose origin remote is under the tomfordweb org.
        $DRY_RUN_CMD find "${home}/code" \
          -path "${home}/code/tomfordweb" -prune -o \
          -name node_modules -prune -o \
          -name .git -type d -print 2>/dev/null | while read -r gitdir; do
          repo="$(dirname "$gitdir")"
          remote="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
          case "$remote" in
            *github.com*tomfordweb/*|*github.com:tomfordweb/*)
              rel="$(realpath --relative-to="$repo" "${wikiRules}")"
              $DRY_RUN_CMD ln -sfn "$rel" "$repo/CLAUDE.tomfordweb.md"
              if [ -f "$repo/CLAUDE.md" ] && ! grep -qF '@CLAUDE.tomfordweb.md' "$repo/CLAUDE.md"; then
                $DRY_RUN_CMD sed -i '0,/^#/{/^#/a\
@CLAUDE.tomfordweb.md
                }' "$repo/CLAUDE.md"
              fi
              ;;
          esac
        done
      fi
    fi
  '';
}
