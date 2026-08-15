#!/bin/bash
# Host: turn the existing unofficial ISO into a USB .img inside the
# builder guest, copy it to images/, ntfy. SSH/session-proof.
# Set STOP_BUILDER=0 to leave QEMU running after success.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/host-env.sh
. "${SCRIPT_DIR}/lib/host-env.sh"
LOG="${WORK}/logs/usb-img-host.log"
HOST_STATUS="${WORK}/STATUS.txt"
STOP_BUILDER="${STOP_BUILDER:-1}"

mkdir -p "${WORK}/logs" "${WORK}/images"

say() {
  echo "$(date -u '+%Y-%m-%dT%H:%MZ') $*" | tee -a "$LOG"
  echo "$*" >"$HOST_STATUS"
}

ssh_guest() {
  ssh -F /dev/null -i "$SSH_KEY" \
    -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -p "$SSH_PORT" "${TAILS_BUILDER_SSH_USER}@${TAILS_BUILDER_SSH_HOST}" "$@"
}

scp_guest() {
  scp -F /dev/null -i "$SSH_KEY" \
    -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -P "$SSH_PORT" "$@"
}

ntfy() {
  local tags="$1"
  local body="$2"
  "${SCRIPT_DIR}/send-ntfy.sh" "tails-builder" "$tags" "$body" >>"$LOG" 2>&1 || \
    echo "WARN ntfy send failed (topic not printed)" >>"$LOG"
}

fail() {
  say "FAILED $*"
  ntfy "x,warning" "Tails arm64 USB .img FAILED. cat STATUS.txt and logs/usb-img-host.log"
  exit 1
}

if [ ! -f "${WORK}/qemu.pid" ] || ! kill -0 "$(cat "${WORK}/qemu.pid")" 2>/dev/null; then
  fail "builder qemu is not running; start-qemu.sh first"
fi

say "BUILDING $(date -u '+%Y-%m-%dT%H:%MZ') ISO→USB .img in builder guest"
scp_guest "${SCRIPT_DIR}/inside-vm-usb-img.sh" \
  "${TAILS_BUILDER_SSH_USER}@${TAILS_BUILDER_SSH_HOST}:inside-vm-usb-img.sh"
ssh_guest 'chmod +x ~/inside-vm-usb-img.sh'

# Drop a leftover converter if any.
ssh_guest 'if [ -f ~/usb-img.pid ]; then kill "$(cat ~/usb-img.pid)" 2>/dev/null || true; fi' || true

ssh_guest 'nohup bash ~/inside-vm-usb-img.sh >>~/usb-img.log 2>&1 </dev/null & echo $! >~/usb-img-outer.pid; sleep 1; echo OUTER=$(cat ~/usb-img-outer.pid); if [ -f ~/usb-img.pid ]; then echo INNER=$(cat ~/usb-img.pid); fi; head -1 ~/STATUS.txt'

deadline=$((SECONDS + 3600))
guest_state=""
while [ "$SECONDS" -lt "$deadline" ]; do
  guest_state="$(ssh_guest 'head -1 ~/STATUS.txt' 2>/dev/null || echo UNREACHABLE)"
  echo "$(date -u '+%Y-%m-%dT%H:%MZ') guest: ${guest_state}" >>"$LOG"
  case "$guest_state" in
    COMPLETE*)
      break
      ;;
    FAILED*)
      fail "guest: ${guest_state}"
      ;;
    BUILDING*|UNREACHABLE)
      echo "BUILDING USB .img — ${guest_state}" >"$HOST_STATUS"
      sleep 20
      ;;
    *)
      sleep 20
      ;;
  esac
done

if [[ ! "$guest_state" =~ ^COMPLETE ]]; then
  fail "timed out waiting for guest USB image (${guest_state})"
fi

IMG_NAME="$(ssh_guest 'ls -1 ~/tails/tails-*.img | head -1 | xargs -n1 basename' || true)"
if [ -z "${IMG_NAME}" ]; then
  fail "guest COMPLETE but no tails-*.img"
fi

say "BUILDING copying ${IMG_NAME} to host images/"
scp_guest "${TAILS_BUILDER_SSH_USER}@${TAILS_BUILDER_SSH_HOST}:tails/${IMG_NAME}" \
  "${WORK}/images/${IMG_NAME}"

if [ ! -f "${WORK}/images/${IMG_NAME}" ]; then
  fail "scp of ${IMG_NAME} produced no host file"
fi

HOST_IMG="${WORK}/images/${IMG_NAME}"
ls -lh "$HOST_IMG" >>"$LOG"
file "$HOST_IMG" >>"$LOG" || true
# GPT signature at LBA 1 (offset 512).
if ! dd if="$HOST_IMG" bs=1 skip=512 count=8 2>/dev/null | grep -q 'EFI PART'; then
  fail "${IMG_NAME} has no GPT header"
fi

say "COMPLETE $(date -u '+%Y-%m-%dT%H:%MZ') unofficial USB image ${IMG_NAME} (not official Tails; not a working M4 live stick)"
ntfy "white_check_mark,tada" "Tails arm64 USB .img COMPLETE. Check workdir images/ and STATUS.txt"

if [ "$STOP_BUILDER" = 1 ]; then
  "${SCRIPT_DIR}/stop-builder.sh" >>"$LOG" 2>&1 || \
    echo "WARN stop-builder failed; qemu may still be up" >>"$LOG"
fi

exit 0
