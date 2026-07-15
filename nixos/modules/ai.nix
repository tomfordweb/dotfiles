{ pkgs, ... }:

# ------------------------------------------------------------------
# AI tooling — the big-GPU host (minerva) only.
# ------------------------------------------------------------------
# Claude Code / opencode / codex CLIs are managed out-of-band by
# ops/local.ai.yml (they update faster than nixpkgs) — not here.

{
  # ollama with CUDA (was ops/local.ollama.yml: tarball + user unit)
  # Models live at the default /var/lib/private/ollama/models (root btrfs
  # pool) — the pre-migration copy on the code drive (/mnt/code-btr/
  # ollama-models, made by install/minerva-premigration-backup.sh) is kept
  # only as a reinstall backup, not the live path.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    # Default 4096-token context makes ollama SILENTLY truncate longer
    # prompts (produced garbage bevvi taxonomy drafts). The bevvi harness
    # context guard assumes this matches (HARNESS_CONTEXT_TOKENS=16384).
    # (Was the Pop-era systemd user drop-in; declared here so it survives.)
    environmentVariables.OLLAMA_CONTEXT_LENGTH = "16384";
  };

  # beads (bd) — graph-based issue tracker driving the agent workflow.
  # llama-cpp — local GGUF inference (llama-cli/llama-server), replacing the
  # pre-migration hand-built ~/llama.cpp. Plain build (CPU/Vulkan); for the
  # Blackwell dGPU swap to `(llama-cpp.override { cudaSupport = true; })`
  # (large recompile).
  environment.systemPackages = with pkgs; [
    beads
    llama-cpp
  ];
}
