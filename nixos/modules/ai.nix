{ pkgs, ... }:

# ------------------------------------------------------------------
# AI tooling — the big-GPU host (minerva) only.
# ------------------------------------------------------------------
# Claude Code / opencode / codex CLIs are pnpm globals declared in
# home/pnpm-globals.nix (they update faster than nixpkgs; `pnpm up -g`
# updates them without a rebuild, nix-ld runs their native binaries).

{
  # ollama with CUDA (was ops/local.ollama.yml: tarball + user unit)
  # Models live at the default /var/lib/private/ollama/models (root btrfs
  # pool). A copy on the code drive (/mnt/code-btr/ollama-models) is kept
  # only as a reinstall backup, not the live path.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    # Default 4096-token context makes ollama SILENTLY truncate longer
    # prompts (produced garbage and hallucinations in outputs). Custom harness
    # context guard assumes this matches (HARNESS_CONTEXT_TOKENS=16384).
    # (Declared here so it survives rebuilds, not a systemd user drop-in.)
    environmentVariables.OLLAMA_CONTEXT_LENGTH = "16384";
  };

  # beads (bd) — graph-based issue tracker driving the agent workflow.
  # llama-cpp — local GGUF inference (llama-cli/llama-server), replacing the
  # previous hand-built ~/llama.cpp. Plain build (CPU/Vulkan); for the
  # Blackwell dGPU swap to `(llama-cpp.override { cudaSupport = true; })`
  # (large recompile).
  environment.systemPackages = with pkgs; [
    beads
    llama-cpp
  ];
}
