# Download the unofficial arm64 VM image

**Not official Tails.** This is an unofficial image for **QEMU / UTM on
Apple Silicon**. It is **not** an amnesia live USB for M-series Macs, and
it will not protect you the way official Tails does.

Official Tails: <https://tails.net/> (amd64 only).

A download is just the ISO or `.img`. It does not include anyone’s home
directory or builder paths.

## curl (no GitHub login)

```sh
curl -fL -O https://github.com/hologram2016/tails-asahi/releases/latest/download/tails-asahi-unofficial-7.6.2-arm64.iso
curl -fL -O https://github.com/hologram2016/tails-asahi/releases/latest/download/SHA256SUMS
shasum -a 256 -c SHA256SUMS
```

USB-style disk image (optional):

```sh
curl -fL -O https://github.com/hologram2016/tails-asahi/releases/latest/download/tails-asahi-unofficial-7.6.2-arm64.img
```

## Helper script

```sh
git clone https://github.com/hologram2016/tails-asahi.git
cd tails-asahi
./builder/download-image.sh           # ISO
./builder/download-image.sh --img     # USB-style .img
./builder/download-image.sh --both --dir "$HOME/Downloads"
```

`gh release download -R hologram2016/tails-asahi --latest` also works if
you have GitHub CLI.

## What you get

| Asset | Use |
|-------|-----|
| `tails-asahi-unofficial-7.6.2-arm64.iso` | Attach as a CD in UTM / QEMU |
| `tails-asahi-unofficial-7.6.2-arm64.img` | Attach as a virtio / USB disk |
| `SHA256SUMS` | Check the download |

GRUB **defaults to External Hard Disk** (no `live-media=removable`).
Let the 4-second timeout run. The first menu line is still the official
removable entry if you want it.

## After download

1. UTM → new VM → **ARM64** (Apple Virtualization or QEMU).
2. Attach the ISO, or attach the `.img` as a disk. Do not attach the Mac’s internal disk.
3. Boot. You should reach GDM. This will not brick the Mac.
4. Do **not** `dd` the `.img` onto a stick expecting an M-series Mac to boot it.

Builder scripts (rebuild from source) live in [`builder/`](builder/README.md).
More background: [FORK.md](FORK.md).
