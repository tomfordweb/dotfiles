{ pkgs, ... }:

# ------------------------------------------------------------------
# minerva — host-specific secret-reference generation.
# ------------------------------------------------------------------
# One place that generates every "special" secret file this host needs.
# Wired into minerva only via flake.nix `homeModules` (NOT the shared dev
# core), so host-specific op:// item paths never leak onto other machines.
# Add new secret-reference blocks below as you need them (deploy env refs,
# service tokens, etc.).
#
# Hard rule: NO real secrets here or in any file this generates. A same-user
# process (poisoned npm postinstall, rogue editor/MCP extension) can read any
# file you can read and any process's /proc/<pid>/environ — so we write only
# op:// *references* (a pointer, not the secret) and resolve the real value on
# demand through the 1Password desktop app (biometric-gated), holding it in a
# child process's env for one command's lifetime. This is the concrete form of
# the philosophy in shell.nix ("… don't export it shell-wide").

{
  # ---- AI API keys -------------------------------------------------
  # ~/.config/ai/keys.env — op:// REFERENCES ONLY. Fix the item paths to your
  # real 1Password items; references are safe in the repo / nix store.
  xdg.configFile."ai/keys.env".text = ''
    OPENAI_API_KEY=op://Personal/OpenAI/API_KEY
  '';

  # `ai-env <cmd> [args...]` → op run resolves every ref in keys.env via the
  # 1Password desktop app and injects them into <cmd>'s env for its lifetime.
  #   ai-env printenv OPENAI_API_KEY   # one biometric prompt, key only in child
  #
  # MUST use the desktop-integrated `op` — the setuid wrapper at
  # /run/wrappers/bin/op that `programs._1password.enable` (core.nix) installs.
  # The 1Password desktop app authorizes CLI connections from THAT binary only;
  # the plain nixpkgs `_1password-cli` op is a different binary the app rejects
  # with "error initializing client: connecting to desktop app: connection
  # reset". So invoke bare `op` (resolves to the wrapper on the login PATH), not
  # `${pkgs._1password-cli}/bin/op`.
  home.packages = [
    (pkgs.writeShellScriptBin "ai-env" ''
      exec op run --env-file="$HOME/.config/ai/keys.env" -- "$@"
    '')
  ];

  # ---- add more host secret-reference blocks below -----------------
  # e.g. another op:// env file + a `writeShellScriptBin` wrapper, same shape.
}
