{ ... }:

# ------------------------------------------------------------------
# Claude Code managed settings (system scope).
# ------------------------------------------------------------------
# The nix-owned half of Claude's config lives here, at the highest-precedence
# scope Claude reads. ~/.claude/settings.json stays a plain writable file for
# Claude's own runtime preferences; see lib/claude-settings.nix for the split.

let
  claudeSettings = import ../lib/claude-settings.nix;
  # Live images and fresh installs may not have the checkout yet. Check at
  # command time so cloning it enables integrations without another rebuild.
  guardCommand = hook:
    if (hook.type or "") == "command" then hook // {
      command = ''if [ -d "/home/tom/code/tomfordweb/dotfiles" ]; then ${hook.command}; fi'';
    } else hook;
  managed = claudeSettings.managed // {
    hooks = builtins.mapAttrs (_: matchers: map (matcher: matcher // {
      hooks = map guardCommand matcher.hooks;
    }) matchers) claudeSettings.managed.hooks;
    statusLine = guardCommand claudeSettings.managed.statusLine;
  };
in
{
  environment.etc."claude-code/managed-settings.json".text =
    builtins.toJSON managed;
}
