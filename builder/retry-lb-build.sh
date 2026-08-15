#!/bin/bash
# Host: push inside-vm-build.sh and start a detached lb build (skip website).
# SSH/session-proof: nohup + caffeinate (already pinned to qemu).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/host-env.sh
. "${SCRIPT_DIR}/lib/host-env.sh"

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

echo "BUILDING $(date -u '+%Y-%m-%dT%H:%MZ') resume from Perl hook, IPv4 DNS, keep chroot" \
  >"${WORK}/STATUS.txt"

scp_guest "${SCRIPT_DIR}/inside-vm-build.sh" "${TAILS_BUILDER_SSH_USER}@${TAILS_BUILDER_SSH_HOST}:inside-vm-build.sh"
ssh_guest 'chmod +x ~/inside-vm-build.sh'

# Kill a leftover guest build if any.
ssh_guest 'if [ -f ~/build.pid ]; then kill "$(cat ~/build.pid)" 2>/dev/null || true; fi' || true

RESUME_FROM_HOOK="${RESUME_FROM_HOOK:-08-install-Perl-programs}"
ssh_guest "nohup env SKIP_LB_CONFIG=1 SKIP_CHROOT_CLEAN=1 RESUME_FROM_HOOK=${RESUME_FROM_HOOK} bash ~/inside-vm-build.sh >>~/build.log 2>&1 </dev/null & echo \$! >~/outer.pid; sleep 1; if [ -f ~/build.pid ]; then echo INNER=\$(cat ~/build.pid); else echo INNER=pending; fi; echo OUTER=\$(cat ~/outer.pid); head -1 ~/STATUS.txt"

# Re-arm ntfy for the next terminal state.
: >"${WORK}/ntfy.last-state"
if [ -f "${WORK}/notify-watch.pid" ] && kill -0 "$(cat "${WORK}/notify-watch.pid")" 2>/dev/null; then
  echo "notify-watch already running pid=$(cat "${WORK}/notify-watch.pid")"
else
  nohup "${SCRIPT_DIR}/notify-watch.sh" >>"${WORK}/logs/notify-watch.log" 2>&1 &
  echo $! >"${WORK}/notify-watch.pid"
  echo "notify-watch pid=$(cat "${WORK}/notify-watch.pid")"
fi

echo "OK host STATUS:"
cat "${WORK}/STATUS.txt"
