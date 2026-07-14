#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One-shot pre-NixOS-migration backup for minerva. Idempotent + non-destructive.
#
# The NixOS reinstall reformats ONLY the root partition. This script preserves
# the things that either don't survive (docker dev-DB volumes on /) or that we
# want an extra off-disk copy of, BEFORE the wipe:
#
#   1. ollama models  -> COPIED to the code NVMe (/mnt/code-btr/ollama-models),
#      which survives the reinstall AND is where modules/ai.nix points ollama.
#      Source at ~/.ollama is left untouched.
#   2. running MySQL dev containers -> dumped to /mnt/storage (volumes on / die).
#   3. ~/code/tomfordweb/andromeda  -> compressed to /mnt/storage (safety copy;
#      excludes the 32G of regenerable node_modules/dist, KEEPS .git + beads).
#   4. beads DBs -> pushed to their git remotes (refs/dolt/data).
#
# Nothing is deleted. Safe to re-run (rsync converges; dated archive names).
# ---------------------------------------------------------------------------
set -euo pipefail

OLLAMA_SRC="$HOME/.ollama/models"
OLLAMA_DST="/mnt/code-btr/ollama-models"        # code NVMe (survives reinstall)
ANDROMEDA="$HOME/code/tomfordweb/andromeda"
# Dump target. Default was the WD 4TB storage drive; it died 2026-07-14, so
# override to the code NVMe until the replacement lands:
#   STORAGE_DST=/mnt/code-btr/minerva-premigration ./minerva-premigration-backup.sh
STORAGE="${STORAGE_DST:-/mnt/storage/minerva-premigration}"
STAMP="$(date +%F)"

log(){ printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }
warn(){ printf '\033[1;33mWARN:\033[0m %s\n' "$*"; }

# ---- preflight: mounts present; dest dirs creatable -----------------------
# The mount ROOTS are root-owned (btrfs subvolid=5 top / the storage drive),
# so we check writability of the actual dest dirs, not the mounts themselves.
# Only require the mounts the chosen targets actually live under.
for m in /mnt/code-btr /mnt/storage; do
  case "$OLLAMA_DST $STORAGE" in *"$m"*)
    mountpoint -q "$m" || { echo "FATAL: $m not mounted"; exit 1; } ;;
  esac
done
# /mnt/code-btr is root:root — the ollama dest needs a one-time sudo setup:
if ! mkdir -p "$OLLAMA_DST" 2>/dev/null; then
  echo "FATAL: cannot create $OLLAMA_DST (mount root is root-owned)."
  echo "Run this once, then re-run this script:"
  echo "  sudo mkdir -p $OLLAMA_DST && sudo chown -R $(id -un):$(id -gn) $OLLAMA_DST"
  exit 1
fi
if ! mkdir -p "$STORAGE/mysql" "$STORAGE/andromeda" 2>/dev/null; then
  echo "FATAL: cannot write under $STORAGE (root-owned mount top?)."
  echo "Run this once, then re-run this script:"
  echo "  sudo mkdir -p $STORAGE && sudo chown -R $(id -un):$(id -gn) $STORAGE"
  exit 1
fi

# ---- 1. ollama models: COPY to code NVMe (source stays put) ---------------
if [ -d "$OLLAMA_SRC" ]; then
  log "ollama models -> $OLLAMA_DST  (copy; source $OLLAMA_SRC untouched)"
  rsync -aHAX --info=progress2 --delete "$OLLAMA_SRC/" "$OLLAMA_DST/"
  src_blobs=$(find "$OLLAMA_SRC/blobs" -type f 2>/dev/null | wc -l)
  dst_blobs=$(find "$OLLAMA_DST/blobs" -type f 2>/dev/null | wc -l)
  echo "blob count: src=$src_blobs dst=$dst_blobs"
  [ "$src_blobs" = "$dst_blobs" ] || warn "blob counts differ — re-run to converge"
else
  warn "no $OLLAMA_SRC — skipping ollama copy"
fi

# ---- 2. mysqldump every RUNNING mysql container ---------------------------
log "mysqldump running mysql containers -> $STORAGE/mysql"
mapfile -t MYSQL_CONTAINERS < <(docker ps --format '{{.Names}}\t{{.Image}}' | awk '/mysql/{print $1}')
if [ "${#MYSQL_CONTAINERS[@]}" -eq 0 ]; then
  warn "no running mysql containers"
fi
for c in "${MYSQL_CONTAINERS[@]}"; do
  [ -n "$c" ] || continue
  pw="$(docker exec "$c" printenv MYSQL_ROOT_PASSWORD 2>/dev/null || true)"
  out="$STORAGE/mysql/$c-$STAMP.sql.gz"
  echo "  dumping $c"
  if docker exec "$c" sh -c "exec mysqldump -uroot ${pw:+-p\"$pw\"} \
        --all-databases --single-transaction --routines --triggers --events" \
        2>/dev/null | gzip > "$out"; then
    echo "    ok ($(du -h "$out" | cut -f1))"
  else
    warn "$c dump failed (bad/absent MYSQL_ROOT_PASSWORD?) — removing empty file"
    rm -f "$out"
  fi
done

# ---- 3. compress andromeda (exclude regenerables, KEEP .git + beads) ------
if [ -d "$ANDROMEDA" ]; then
  log "compress andromeda -> $STORAGE/andromeda"
  if command -v zstd >/dev/null; then
    COMP=(--use-compress-program 'zstd -T0 -10'); EXT=tar.zst
  else
    warn "zstd not found — falling back to gzip"; COMP=(-z); EXT=tar.gz
  fi
  tar -C "$(dirname "$ANDROMEDA")" "${COMP[@]}" \
    --exclude='andromeda/**/node_modules' --exclude='andromeda/node_modules' \
    --exclude='andromeda/dist' --exclude='andromeda/tmp' \
    --exclude='andromeda/graphify-out' --exclude='andromeda/.nx' \
    --exclude='andromeda/coverage' --exclude='andromeda/test-results' \
    --exclude='andromeda/playwright-report' --exclude='andromeda/.turbo' \
    -cf "$STORAGE/andromeda/andromeda-$STAMP.$EXT" andromeda
  echo "  wrote $STORAGE/andromeda/andromeda-$STAMP.$EXT ($(du -h "$STORAGE/andromeda/andromeda-$STAMP.$EXT" | cut -f1))"
else
  warn "no $ANDROMEDA — skipping compress"
fi

# ---- 4. beads: push to git remote (belt-and-suspenders, non-fatal) --------
log "beads dolt push (non-fatal)"
for r in "$ANDROMEDA" "$HOME/code/tomfordweb/dotfiles"; do
  [ -d "$r/.beads" ] || continue
  ( cd "$r" && bd dolt push ) || warn "bd dolt push failed in $r"
done

# ---- summary --------------------------------------------------------------
log "DONE — summary"
du -sh "$OLLAMA_DST" 2>/dev/null || true
du -sh "$STORAGE/mysql" 2>/dev/null || true
ls -lh "$STORAGE/andromeda/"*."${EXT:-tar}"* 2>/dev/null || true
echo
echo "Next: verify 'ollama list' still works from $OLLAMA_DST after install,"
echo "and 'sudo chown -R ollama:ollama $OLLAMA_DST' on first NixOS boot."
