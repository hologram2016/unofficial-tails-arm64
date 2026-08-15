#!/bin/bash
# Detached watcher: one ntfy on COMPLETE or FAILED. Survives this chat.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/host-env.sh
. "${SCRIPT_DIR}/lib/host-env.sh"
STAMP="${WORK}/ntfy.last-state"
LOG="${WORK}/logs/notify-watch.log"

say() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"; }

send() {
  local tags="$1"
  local body="$2"
  "${SCRIPT_DIR}/send-ntfy.sh" "tails-builder" "$tags" "$body" >>"$LOG" 2>&1 || \
    say "ntfy send failed"
}

remote_status() {
  ssh -F /dev/null -i "$SSH_KEY" \
    -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
    -o ConnectTimeout=8 \
    -p "$SSH_PORT" "${TAILS_BUILDER_SSH_USER}@${TAILS_BUILDER_SSH_HOST}" \
    'cat ~/STATUS.txt 2>/dev/null; echo; if [ -f ~/build.pid ] && kill -0 "$(cat ~/build.pid)" 2>/dev/null; then echo BUILD_ALIVE; else echo BUILD_DEAD; fi' \
    2>/dev/null || true
}

last="$(cat "$STAMP" 2>/dev/null || echo none)"
say "watcher start last=$last"

while true; do
  host="$(tr -d '\n' <"${WORK}/STATUS.txt" 2>/dev/null || echo unknown)"
  rem="$(remote_status)"
  rline="$(printf '%s\n' "$rem" | head -1)"
  alive="$(printf '%s\n' "$rem" | grep -c BUILD_ALIVE || true)"

  state="RUNNING"
  if printf '%s\n%s\n' "$host" "$rline" | grep -q '^COMPLETE'; then
    state="COMPLETE"
  elif printf '%s\n%s\n' "$host" "$rline" | grep -q '^FAILED'; then
    state="FAILED"
  elif printf '%s\n' "$host$rline" | grep -q 'BUILDING' && [ "$alive" = "0" ]; then
    # Build process gone but STATUS never flipped.
    state="FAILED"
    echo "FAILED $(date -u '+%Y-%m-%dT%H:%MZ') build process died (see VM ~/build.log)" \
      >"${WORK}/STATUS.txt"
  fi

  if [ "$state" != "$last" ]; then
    case "$state" in
      COMPLETE)
        send "white_check_mark,tada" "Tails arm64 image build COMPLETE. Check workdir images/ and STATUS.txt"
        last="$state"
        echo "$last" >"$STAMP"
        say "notified COMPLETE"
        exit 0
        ;;
      FAILED)
        send "x,warning" "Tails arm64 image build FAILED. cat STATUS.txt and tail VM ~/build.log"
        last="$state"
        echo "$last" >"$STAMP"
        say "notified FAILED"
        exit 0
        ;;
    esac
  fi
  sleep 45
done
