# Unofficial arm64 VM builder

Not official Tails. These scripts build a generic arm64 Tails-like image in
a headless QEMU/HVF guest on Apple Silicon.

Assumptions:

- Debian 13 arm64 cloud disk as the builder guest (6 GB RAM)
- Source from this repository’s `arm64` branch (NoisyCoil `7.6.2/arm64`)
- Host workdir `TAILS_ARM64_WORK`
- Guest SSH at `127.0.0.1:2222` with `~/.ssh/id_ed25519_tails_builder`

Official Tails time-based snapshots are amd64-only. `inside-vm-build.sh`
remaps Debian and Tor to the upstream archives so debootstrap can fetch
arm64 packages. The offline website uses ikiwiki from Debian Forky only
(`pin-ikiwiki-forky.sh`). Do not skip the website.

On `arm64`, GRUB defaults to External Hard Disk (`livenonremovable`) because
QEMU/UTM virtio disks are not removable. Official `live-media=removable`
entries stay on the menu.

| Script | Runs on | Purpose |
|--------|---------|---------|
| `setup-builder.sh` | host | First-time guest disk and cloud-init seed |
| `start-qemu.sh` | host | Headless `qemu-system-aarch64` + HVF |
| `inside-vm-build.sh` | guest | `lb config` / `lb build`, resume hooks, DNS/IPv4 |
| `retry-lb-build.sh` | host | Push the guest script and start a detached build |
| `inside-vm-usb-img.sh` | guest | Official `create-usb-image-from-iso` (GPT + FAT; no syslinux on aarch64) |
| `create-usb-img.sh` | host | Run the converter and copy `tails-*.img` to `images/` |
| `stop-builder.sh` | host | `poweroff` the builder QEMU |
| `download-image.sh` | any host with `curl` or `gh` | Fetch the latest unofficial ISO or `.img` from Releases |
| `publish-release.sh` | host | Upload ISO, `.img`, and `SHA256SUMS` to Releases |
| `pin-ikiwiki-forky.sh` | guest (root) | Forky pin for ikiwiki |
| `notify-watch.sh` / `send-ntfy.sh` | host | Optional ntfy on COMPLETE or FAILED (topic from a local env file) |
| `cloud-init/` | guest seed | `tailsbuild` user, sudo, packages |
| `patches/10-tbb-curl-location.patch` | guest source | Follow GitLab 302s when fetching aarch64 Tor Browser |

```sh
export TAILS_ARM64_WORK="$HOME/tails-arm64-work"
export TAILS_BUILDER_SSH_KEY="$HOME/.ssh/id_ed25519_tails_builder"
```

`send-ntfy.sh` reads `NTFY_URL` and `NTFY_TOPIC` from a local file (default
`$HOME/.config/projects-notify/ntfy.env`). Do not commit the topic.

Reconnect: [HOW-TO-RECONNECT.md](HOW-TO-RECONNECT.md).
