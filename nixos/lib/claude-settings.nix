# ------------------------------------------------------------------
# Claude Code settings, split by who owns them.
# ------------------------------------------------------------------
# managed: policy nix owns outright (hooks, statusLine, plugins, permission
#   rules). Installed read-only at /etc/claude-code/managed-settings.json by
#   modules/claude-code.nix. Claude never writes there, so a /nix/store path
#   is fine.
# seed: preferences Claude rewrites at runtime (model, theme, effort, voice).
#   Written to ~/.claude/settings.json once by home/ai-tools.nix, only when
#   that file is missing, and never touched again.
#
# Permission lists and hooks merge across scopes, so a rule or hook added at
# user/project level adds to these instead of replacing them.

let
  aiTools = ../../ai-tools;
  readPermissionList = name:
    builtins.fromJSON (builtins.readFile (aiTools + "/permissions/${name}.json"));
in
rec {
  allowedCommands = readPermissionList "allowed-commands";
  askCommands = readPermissionList "ask-commands";
  allowedMcpTools = readPermissionList "allowed-mcp-tools";
  askMcpTools = readPermissionList "ask-mcp-tools";

  # `"tool": "*"` gates a WHOLE server. Claude spells that as the bare
  # `mcp__<server>` (no tool suffix, no glob); a literal `mcp__server__*`
  # matches nothing and would silently grant the server instead of gating it.
  claudeMcpToolName = tool:
    if tool.tool == "*" then "mcp__${tool.server}" else "mcp__${tool.server}__${tool.tool}";

  managed = (builtins.fromJSON (builtins.readFile (aiTools + "/settings.json"))) // {
    permissions = {
      allow = (map (command: "Bash(${command}:*)") allowedCommands)
        ++ (map claudeMcpToolName allowedMcpTools);
      ask = (map (command: "Bash(${command}:*)") askCommands)
        ++ (map claudeMcpToolName askMcpTools);
    };
  };

  seed = builtins.fromJSON (builtins.readFile (aiTools + "/settings.seed.json"));
}
