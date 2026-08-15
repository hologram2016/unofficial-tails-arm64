# Reconnect to the unofficial arm64 builder

The build is meant to continue if the controlling session drops.
`TAILS_ARM64_WORK` is the host workdir (disks, `STATUS.txt`, logs).

```sh
export TAILS_ARM64_WORK="${TAILS_ARM64_WORK:-$HOME/tails-arm64-work}"

cat "$TAILS_ARM64_WORK/STATUS.txt"
tail -50 "$TAILS_ARM64_WORK/logs/setup.log"
tail -50 "$TAILS_ARM64_WORK/logs/qemu-serial.log"
```

SSH into the builder guest once STATUS is `WAITING_SSH` or later:

```sh
ssh -F /dev/null \
  -i "${TAILS_BUILDER_SSH_KEY:-$HOME/.ssh/id_ed25519_tails_builder}" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -p 2222 tailsbuild@127.0.0.1
```

In the guest:

```sh
tail -f ~/build.log
cat ~/STATUS.txt
```

STATUS values: `PREPARING`, `WAITING_SSH`, `READY`, `BUILDING`, `COMPLETE`, `FAILED`.

The builder guest is QEMU, not UTM. `utmctl` and AppleScript cannot start VMs
from a non-GUI session on macOS.

```sh
cat "$TAILS_ARM64_WORK/qemu.pid"
builder/start-qemu.sh    # idempotent if already running
builder/stop-builder.sh  # guest poweroff
```

ISO to USB `.img` (a `tails-*.iso` must already exist in the guest):

```sh
# STOP_BUILDER=0 leaves QEMU running afterwards
builder/create-usb-img.sh
```
