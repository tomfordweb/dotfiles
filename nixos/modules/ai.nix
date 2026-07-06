{ pkgs, ... }:

# ------------------------------------------------------------------
# AI tooling — the big-GPU host (minerva) only.
# ------------------------------------------------------------------
# Claude Code / opencode / codex CLIs are managed out-of-band by
# ops/local.ai.yml (they update faster than nixpkgs) — not here.

{
  # ollama with CUDA (was ops/local.ollama.yml: tarball + user unit)
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  # beads (bd) — graph-based issue tracker driving the agent workflow
  environment.systemPackages = with pkgs; [
    beads
  ];
}
