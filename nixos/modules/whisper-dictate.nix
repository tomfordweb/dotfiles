{ pkgs, ... }:

# ------------------------------------------------------------------
# whisper.cpp push-to-toggle dictation — minerva (big GPU) only.
# ------------------------------------------------------------------
# System-wide voice typing. A macropad key (mapped to F13) fires
# `bin/whisper-toggle` via a Hyprland bind (see config/hypr/hyprland.conf):
#   press once  -> start recording mic (pw-record, 16k mono wav)
#   press again -> stop, transcribe with whisper.cpp, wtype the text
#                  into the focused window.
#
# NOTE: ghostty CANNOT run shell on keypress (no exec action), so the
# toggle lives in Hyprland, not ghostty. Works in any app, not just the
# terminal.
#
# The base.en ggml model is fetched to ~/.cache/whisper on first run.
# pw-record comes from pipewire (already enabled system-wide).

{
  environment.systemPackages = with pkgs; [
    openai-whisper-cpp   # whisper-cli binary
    wtype                # type transcribed text into focused wlroots window
    libnotify            # notify-send status toasts (mako renders them)
    curl                 # first-run model download
  ];

  # ---- Live streaming (bin/whisper-stream-toggle) ------------------
  # The live VAD dictation path needs the `whisper-stream` binary, which is
  # the SDL2 example — nixpkgs' openai-whisper-cpp does NOT build it. When
  # backfilling this host, override to build the examples with SDL2, e.g.
  #   (openai-whisper-cpp.overrideAttrs (o: {
  #     buildInputs = (o.buildInputs or []) ++ [ SDL2 ];
  #     cmakeFlags  = (o.cmakeFlags or []) ++ [ "-DWHISPER_SDL2=ON" ];
  #   }))
  # The record-then-transcribe path (whisper-toggle) needs only whisper-cli
  # above, so it works without this.

  # ---- CUDA build (optional) ---------------------------------------
  # base.en on CPU transcribes a short clip in well under a second on
  # this box, so CPU is the default. To offload to the Blackwell dGPU,
  # swap the package above for:
  #   (openai-whisper-cpp.override { cudaSupport = true; })
  # (large recompile; only worth it for large-v3 / long recordings).
}
