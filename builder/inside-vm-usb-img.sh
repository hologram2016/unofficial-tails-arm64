#!/bin/bash
# Runs *inside* the Debian builder VM. Turns an existing tails-*.iso
# into tails-*.img with the official create-usb-image-from-iso helper
# (GPT + FAT ESP; no syslinux on aarch64).
#
# Writes ~/STATUS.txt, ~/usb-img.pid, ~/usb-img.log.
set -euo pipefail

HOME_DIR="${HOME:-/home/tailsbuild}"
SRC="${HOME_DIR}/tails"
LOG="${HOME_DIR}/usb-img.log"
STATUS="${HOME_DIR}/STATUS.txt"
PIDFILE="${HOME_DIR}/usb-img.pid"

echo $$ >"$PIDFILE"

on_exit() {
  local rc="${1:-$?}"
  rm -f "$PIDFILE"
  if [ "$rc" -ne 0 ]; then
    echo "FAILED $(date --utc '+%Y-%m-%dT%H:%MZ') usb-img exit $rc" | tee "$STATUS" >/dev/null
  fi
}
trap 'on_exit $?' EXIT

say() {
  local line="$1"
  echo "$line" | tee "$STATUS" >/dev/null
  echo "$(date --utc '+%Y-%m-%dT%H:%MZ') $line" >>"$LOG"
}

cd "$SRC"

ISO="$(ls -1 tails-*.iso 2>/dev/null | head -1 || true)"
if [ -z "${ISO}" ] || [ ! -f "$ISO" ]; then
  say "FAILED no tails-*.iso in ${SRC}"
  exit 1
fi

IMG="${ISO%.iso}.img"
if [ -f "$IMG" ]; then
  sudo chmod a+r "$IMG" || true
  say "COMPLETE $(date --utc '+%Y-%m-%dT%H:%MZ') unofficial USB image already present ${IMG} (not official Tails)"
  exit 0
fi

say "BUILDING installing udisks2 + python3-gi for ISO→USB"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  udisks2 python3-gi gir1.2-udisks-2.0

sudo modprobe loop || true
sudo systemctl start dbus
sudo systemctl enable --now udisks2
for _ in $(seq 1 15); do
  if systemctl is-active --quiet udisks2 && [ -S /run/dbus/system_bus_socket ]; then
    break
  fi
  sleep 1
done
if ! systemctl is-active --quiet udisks2; then
  say "FAILED udisks2 did not start"
  systemctl status udisks2 --no-pager >>"$LOG" 2>&1 || true
  exit 1
fi

export PATH="${SRC}/auto/scripts:${PATH}"
say "BUILDING create-usb-image-from-iso ${ISO}"
# Official helper must be root (UDisks loop + mkfs).
sudo python3 "${SRC}/auto/scripts/create-usb-image-from-iso" "$ISO" >>"$LOG" 2>&1

if [ ! -f "$IMG" ]; then
  say "FAILED create-usb-image-from-iso produced no ${IMG}"
  exit 1
fi

sudo chmod a+r "$IMG"
ls -lh "$IMG" >>"$LOG"
say "COMPLETE $(date --utc '+%Y-%m-%dT%H:%MZ') unofficial USB image ${IMG} (not official Tails)"
exit 0
