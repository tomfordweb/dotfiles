{ ... }:

# ------------------------------------------------------------------
# Claude Code managed settings (system scope).
# ------------------------------------------------------------------
# The nix-owned half of Claude's config lives here, at the highest-precedence
# scope Claude reads. ~/.claude/settings.json stays a plain writable file for
# Claude's own runtime preferences; see lib/claude-settings.nix for the split.

let
  claudeSettings = import ../lib/claude-settings.nix;
in
{
  environment.etc."claude-code/managed-settings.json".text =
    builtins.toJSON claudeSettings.managed;
}
