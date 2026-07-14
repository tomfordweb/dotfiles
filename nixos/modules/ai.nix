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
    # Models live on the code NVMe (Crucial T500, plenty of room, NVMe-fast
    # cold loads), NOT the default /var/lib/ollama on the small root. Plain
    # dir at the btrfs top (subvolid=5) so btrbk — which only snapshots
    # @code — ignores it. Populated pre-migration by
    # install/minerva-premigration-backup.sh; chown ollama:ollama on first boot.
    models = "/mnt/code-btr/ollama-models";
    # Default 4096-token context makes ollama SILENTLY truncate longer
    # prompts (produced garbage bevvi taxonomy drafts). The bevvi harness
    # context guard assumes this matches (HARNESS_CONTEXT_TOKENS=16384).
    environmentVariables.OLLAMA_CONTEXT_LENGTH = "16384";
  };

  # beads (bd) — graph-based issue tracker driving the agent workflow
  environment.systemPackages = with pkgs; [
    beads
  ];
}
