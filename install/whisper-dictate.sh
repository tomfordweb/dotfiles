#!/usr/bin/env bash
# install/whisper-dictate.sh — set up whisper.cpp push-to-talk voice dictation
# on a non-nix host (Ubuntu/Debian). Idempotent.
#
# Architecture (see bin/whisper-toggle, bin/whisper-ptt-daemon):
#   * whisper.cpp built from source -> whisper-cli (+ whisper-stream, SDL2)
#   * base.en ggml model in ~/.cache/whisper
#   * whisper-ptt-daemon: a --user service reading evdev; HOLD a macropad key
#     to record, RELEASE to transcribe + type (wtype) into the focused window
#   * a udev rule (uaccess) grants the daemon read access to the macropad
#
# Why a daemon and not a compositor keybind: push-to-talk needs a key-RELEASE
# event. COSMIC custom shortcuts only fire on press, so we read evdev directly.
# On Hyprland you can skip the daemon and use bind/bindr (see hyprland.conf).
# On NixOS use nixos/modules/whisper-dictate.nix for the packages.
#
# Macropad: map two keys to F13 and F14 (Keychron Launcher: "Any" -> KC_F13 /
# KC_F14, Layer 0). Both are bound to record-then-transcribe push-to-talk.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$HOME/.local/share/whisper.cpp"
BIN_DIR="$HOME/.local/bin"
MODEL_DIR="$HOME/.cache/whisper"
MODEL="$MODEL_DIR/ggml-base.en.bin"

echo "==> apt deps"
sudo apt-get update -qq
sudo apt-get install -y wtype libnotify-bin wl-clipboard curl cmake build-essential \
  git pipx libsdl2-dev python3-evdev acl

echo "==> build whisper.cpp -> $SRC_DIR (whisper-cli + whisper-stream)"
if [ -d "$SRC_DIR/.git" ]; then
  git -C "$SRC_DIR" pull --ff-only
else
  git clone --depth 1 https://github.com/ggerganov/whisper.cpp "$SRC_DIR"
fi
cmake -S "$SRC_DIR" -B "$SRC_DIR/build" -DCMAKE_BUILD_TYPE=Release -DWHISPER_SDL2=ON >/dev/null
cmake --build "$SRC_DIR/build" -j --target whisper-cli whisper-stream

mkdir -p "$BIN_DIR"
ln -sf "$SRC_DIR/build/bin/whisper-cli"    "$BIN_DIR/whisper-cli"
ln -sf "$SRC_DIR/build/bin/whisper-stream" "$BIN_DIR/whisper-stream"
echo "    linked whisper-cli + whisper-stream into $BIN_DIR"

echo "==> fetch base.en model -> $MODEL"
mkdir -p "$MODEL_DIR"
if [ -f "$MODEL" ]; then
  echo "    already present"
else
  # HF migrated whisper.cpp to Xet storage; the plain resolve/ URL now 403s
  # for curl/wget (signed CDN redirect). The hf CLI speaks Xet, so fetch
  # through pipx. HF_TOKEN optional (higher rate limits).
  pipx run --spec 'huggingface_hub[cli,hf_xet]' \
    hf download ggerganov/whisper.cpp ggml-base.en.bin --local-dir "$MODEL_DIR"
fi

echo "==> udev rule (uaccess) for macropad evdev access"
sudo cp "$REPO/install/udev/99-whisper-ptt.rules" /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
echo "    installed — replug the macropad (or reboot) if access is still denied"

echo "==> whisper-ptt-daemon --user service"
U="$HOME/.config/systemd/user"
mkdir -p "$U"
cat > "$U/whisper-ptt.service" <<EOF
[Unit]
Description=whisper push-to-talk evdev listener
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Environment=PATH=$HOME/.local/bin:$REPO/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$REPO/bin/whisper-ptt-daemon
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now whisper-ptt.service
echo "    enabled: $(systemctl --user is-active whisper-ptt.service)"

echo
echo "Done. Map two macropad keys to F13 + F14 (Keychron Launcher -> Any ->"
echo "KC_F13 / KC_F14, Layer 0). Then HOLD a key, speak, RELEASE -> it types."
echo "Manual test:  whisper-toggle start  (speak)  whisper-toggle stop"
