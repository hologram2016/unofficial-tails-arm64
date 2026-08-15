#!/bin/bash
# Headless HVF aarch64 builder. Does not use UTM (utmctl/osascript fail
# from SSH / non-GUI agent sessions). Safe under nohup + caffeinate.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/host-env.sh
. "${SCRIPT_DIR}/lib/host-env.sh"
DATA="${WORK}/utm/tails-builder.utm/Data"
CODE="${TAILS_BUILDER_EDK2_CODE:-/opt/homebrew/share/qemu/edk2-aarch64-code.fd}"
VARS="${WORK}/utm/edk2-vars.fd"
DISK="${TAILS_BUILDER_QCOW:-${DATA}/E1308C9D-6291-4652-A2B9-AF35A4F767E1.qcow2}"
CIDATA="${DATA}/cidata.iso"
PIDFILE="${WORK}/qemu.pid"
SERIAL="${WORK}/logs/qemu-serial.log"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "qemu already running pid=$(cat "$PIDFILE")"
  exit 0
fi

if [ ! -f "$VARS" ]; then
  cp /opt/homebrew/share/qemu/edk2-arm-vars.fd "$VARS"
fi

# qemu -daemonize writes its own pid; we also record it
qemu-system-aarch64 \
  -name tails-builder \
  -machine virt,accel=hvf,highmem=on \
  -cpu host \
  -smp 4 \
  -m 6144 \
  -drive if=pflash,format=raw,readonly=on,file="$CODE" \
  -drive if=pflash,format=raw,file="$VARS" \
  -drive if=virtio,format=qcow2,file="$DISK" \
  -drive if=virtio,format=raw,readonly=on,file="$CIDATA" \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=net0,mac=DA:36:E0:02:FA:50 \
  -device virtio-rng-pci \
  -display none \
  -serial file:"$SERIAL" \
  -pidfile "$PIDFILE" \
  -daemonize

echo "started qemu pid=$(cat "$PIDFILE")"
