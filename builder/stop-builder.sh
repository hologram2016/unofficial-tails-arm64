#!/bin/bash
# Gracefully stop the headless builder QEMU.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/host-env.sh
. "${SCRIPT_DIR}/lib/host-env.sh"
PIDFILE="${WORK}/qemu.pid"

if [ ! -f "$PIDFILE" ]; then
  echo "no qemu.pid; builder already stopped"
  exit 0
fi
QPID="$(cat "$PIDFILE")"
if ! kill -0 "$QPID" 2>/dev/null; then
  rm -f "$PIDFILE"
  echo "stale qemu.pid ${QPID}; removed"
  exit 0
fi

echo "stopping builder qemu pid=${QPID}"
ssh -F /dev/null -i "$SSH_KEY" \
  -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
  -o ConnectTimeout=8 \
  -p "$SSH_PORT" "${TAILS_BUILDER_SSH_USER}@${TAILS_BUILDER_SSH_HOST}" \
  'sudo /sbin/poweroff' 2>/dev/null || true

for _ in $(seq 1 30); do
  if ! kill -0 "$QPID" 2>/dev/null; then
    rm -f "$PIDFILE"
    echo "builder qemu stopped"
    exit 0
  fi
  sleep 2
done

echo "poweroff timed out; sending TERM to ${QPID}"
kill "$QPID" 2>/dev/null || true
sleep 3
if kill -0 "$QPID" 2>/dev/null; then
  kill -9 "$QPID" 2>/dev/null || true
  sleep 1
fi
rm -f "$PIDFILE"
if kill -0 "$QPID" 2>/dev/null; then
  echo "FAILED to stop qemu ${QPID}" >&2
  exit 1
fi
echo "builder qemu stopped (forced)"
exit 0
