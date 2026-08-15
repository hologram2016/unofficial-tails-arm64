# Reconnect to the unofficial arm64 builder

The job is meant to outlive this chat or an SSH drop.
Set `TAILS_ARM64_WORK` to the host workdir (disks + `STATUS.txt` + logs).

```sh
export TAILS_ARM64_WORK="${TAILS_ARM64_WORK:-$HOME/tails-arm64-work}"

cat "$TAILS_ARM64_WORK/STATUS.txt"

tail -50 "$TAILS_ARM64_WORK/logs/setup.log"
tail -50 "$TAILS_ARM64_WORK/logs/qemu-serial.log"
```

SSH into the builder guest (after STATUS is `WAITING_SSH` or later):

```sh
ssh -F /dev/null \
  -i "${TAILS_BUILDER_SSH_KEY:-$HOME/.ssh/id_ed25519_tails_builder}" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -p 2222 tailsbuild@127.0.0.1
```

Inside the guest:

```sh
tail -f ~/build.log
cat ~/STATUS.txt
```

STATUS values: `PREPARING`, `WAITING_SSH`, `READY`, `BUILDING`, `COMPLETE`, `FAILED`.

QEMU (not UTM) is the actual guest. `utmctl` / AppleScript cannot start VMs
from this agent or an SSH session on this Mac.

```sh
cat "$TAILS_ARM64_WORK/qemu.pid"
builder/start-qemu.sh   # idempotent if already running
builder/stop-builder.sh # graceful poweroff
```

ISO → USB `.img` (guest must already have a `tails-*.iso`):

```sh
# STOP_BUILDER=0 leaves QEMU up afterwards
builder/create-usb-img.sh
```
