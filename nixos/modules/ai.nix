{ config, pkgs, ... }:

# ------------------------------------------------------------------
# AI tooling — the big-GPU host (minerva) only.
# ------------------------------------------------------------------
# Claude Code / opencode / codex CLIs are pnpm globals declared in
# home/pnpm-globals.nix (they update faster than nixpkgs; `pnpm up -g`
# updates them without a rebuild, nix-ld runs their native binaries).

let
  modelBackup = pkgs.writeShellApplication {
    name = "backup-llm-models";
    runtimeInputs = with pkgs; [ coreutils rsync util-linux ];
    text = builtins.readFile ../../bin/backup-llm-models;
  };
in
{
  # Downloads belong on the root btrfs pool, outside the Nix store.
  # Tom maintains the files; inference services only need read access.
  systemd.tmpfiles.rules = [
    "d /var/lib/llama-models 0755 tom users - -"
  ];

  systemd.services.backup-llm-models = {
    description = "Back up completed local models to the storage drive";
    environment.HOME = config.users.users.tom.home;
    unitConfig = {
      ConditionPathIsMountPoint = "/mnt/storage";
      OnFailure = "backup-notify-failure@%n.service";
      OnSuccess = "backup-notify-recovered@%n.service";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "tom";
      ExecStart = "${modelBackup}/bin/backup-llm-models";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };
  systemd.timers.backup-llm-models = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "03:30";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

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
    # bubblewrap provides bwrap for cocdex sandboxing.
    bubblewrap
    python3Packages.huggingface-hub
    llama-cpp
  ] ++ [ modelBackup ];
}
