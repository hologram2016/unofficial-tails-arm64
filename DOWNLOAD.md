# Download the unofficial arm64 VM image

**Not official Tails.** This is a private working image for
QEMU / UTM on Apple Silicon. It is **not** an amnesia live USB for
M-series Macs, and it will not protect you the way official Tails does.

Official Tails: <https://tails.net/> (amd64 only).

The repo is **private**. Anyone who should download needs a GitHub
account that can see `hologram2016/tails-asahi` (collaborator or the
same account), plus [GitHub CLI](https://cli.github.com/) (`gh auth login`).

## One shot

```sh
gh release download -R hologram2016/tails-asahi --latest -p '*.iso' -p SHA256SUMS
shasum -a 256 -c SHA256SUMS --ignore-missing
```

Or clone the repo and run the helper (ISO by default):

```sh
git clone https://github.com/hologram2016/tails-asahi.git
cd tails-asahi
./builder/download-image.sh           # ISO
./builder/download-image.sh --img     # USB-style .img
./builder/download-image.sh --both --dir "$HOME/Downloads"
```

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
4. Do **not** `dd` the `.img` onto a stick expecting this Mac mini to boot it.

Builder scripts (rebuild from source) live in [`builder/`](builder/README.md).
