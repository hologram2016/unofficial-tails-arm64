# Unofficial arm64 VM builder

**Not official Tails.** Scripts to build a generic arm64 Tails-like
image in a headless QEMU/HVF guest on an Apple Silicon Mac.

They assume:

- Debian 13 arm64 cloud disk as the builder guest (6 GB RAM)
- Source tree from this repo’s `arm64` branch (NoisyCoil `7.6.2/arm64`)
- Host workdir on a large disk (`TAILS_ASAHI_WORK`)
- Guest SSH on `127.0.0.1:2222` with `~/.ssh/id_ed25519_tails_builder`

Official Tails time-based snapshots are **amd64-only**. `inside-vm-build.sh`
remaps Debian and Tor mirrors to the upstream archives so debootstrap can
fetch arm64 packages. Offline website generation uses **ikiwiki from Forky
only** (`pin-ikiwiki-forky.sh`). Do not skip the website.

On the `arm64` branch, GRUB defaults to **External Hard Disk**
(`livenonremovable`) because QEMU/UTM virtio disks are not removable.
The official `live-media=removable` entries stay on the menu.

## Layout

| Script | Where it runs | Role |
|--------|----------------|------|
| `setup-builder.sh` | host | First-time guest + seed (UTM path; QEMU is what we actually boot) |
| `start-qemu.sh` | host | Headless `qemu-system-aarch64` + HVF |
| `inside-vm-build.sh` | guest | `lb config` / `lb build`, resume hooks, DNS/IPv4 |
| `retry-lb-build.sh` | host | Push guest script, resume detached build, re-arm ntfy |
| `inside-vm-usb-img.sh` | guest | Official `create-usb-image-from-iso` (GPT + FAT; no syslinux on aarch64) |
| `create-usb-img.sh` | host | Push converter, copy `tails-*.img` to `images/`, ntfy, optional stop |
| `stop-builder.sh` | host | Graceful `poweroff` of the builder QEMU (leaves Kali UTM alone) |
| `download-image.sh` | any Mac with `gh` | Fetch the latest unofficial ISO/`.img` from GitHub Releases |
| `pin-ikiwiki-forky.sh` | guest (root) | Official Tails Forky pin for ikiwiki |
| `notify-watch.sh` / `send-ntfy.sh` | host | One ntfy on COMPLETE or FAILED (topic from local env, never printed) |
| `cloud-init/` | guest seed | `tailsbuild` user, sudo, packages |
| `patches/10-tbb-curl-location.patch` | guest source | Follow GitLab 302s when fetching aarch64 Tor Browser |

## Host environment

```sh
export TAILS_ASAHI_WORK="$HOME/tails-asahi-work"   # or an external volume
export TAILS_BUILDER_SSH_KEY="$HOME/.ssh/id_ed25519_tails_builder"
```

`send-ntfy.sh` reads `$HOME/.config/projects-notify/ntfy.env` (`NTFY_URL`,
`NTFY_TOPIC`). The topic must not be committed.

## Reconnect

See [HOW-TO-RECONNECT.md](HOW-TO-RECONNECT.md).
