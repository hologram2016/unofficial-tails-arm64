# Downloads

Not official Tails. These files are for QEMU or UTM on Apple Silicon. They
are not an amnesia live USB for M-series Macs.

Official Tails (amd64): <https://tails.net/>.

The ISO and `.img` are ordinary image files. They do not contain another
machine’s home directory or builder paths.

## Files

Current release: [unofficial-7.6.2-arm64.1](https://github.com/hologram2016/unofficial-tails-arm64/releases/tag/unofficial-7.6.2-arm64.1)
([all releases](https://github.com/hologram2016/unofficial-tails-arm64/releases)).

| File | Size | SHA-256 |
|------|------|---------|
| [unofficial-tails-arm64-7.6.2.iso](https://github.com/hologram2016/unofficial-tails-arm64/releases/download/unofficial-7.6.2-arm64.1/unofficial-tails-arm64-7.6.2.iso) | 1.9 GB | `e196c31c30c2c6ce219f9be3ee593fd103a69e15cd08eeb74cca6ff050b2630a` |
| [unofficial-tails-arm64-7.6.2.img](https://github.com/hologram2016/unofficial-tails-arm64/releases/download/unofficial-7.6.2-arm64.1/unofficial-tails-arm64-7.6.2.img) | 1.9 GB | `961b6a71f218642bc8340476eed4f4da99c88632c2f7ecea1fa2179b501265a7` |
| [SHA256SUMS](https://github.com/hologram2016/unofficial-tails-arm64/releases/download/unofficial-7.6.2-arm64.1/SHA256SUMS) | | |

ISO: CD in UTM or QEMU. `.img`: virtio or USB-style disk.

## curl

```sh
curl -fL -O https://github.com/hologram2016/unofficial-tails-arm64/releases/latest/download/unofficial-tails-arm64-7.6.2.iso
curl -fL -O https://github.com/hologram2016/unofficial-tails-arm64/releases/latest/download/SHA256SUMS
shasum -a 256 -c SHA256SUMS
```

Optional USB-style disk image:

```sh
curl -fL -O https://github.com/hologram2016/unofficial-tails-arm64/releases/latest/download/unofficial-tails-arm64-7.6.2.img
```

## Helper

```sh
git clone https://github.com/hologram2016/unofficial-tails-arm64.git
cd unofficial-tails-arm64
./builder/download-image.sh           # ISO
./builder/download-image.sh --img     # USB-style .img
./builder/download-image.sh --both --dir "$HOME/Downloads"
```

GitHub CLI:

```sh
gh release download -R hologram2016/unofficial-tails-arm64 --latest
```

GRUB defaults to External Hard Disk (`live-media=removable` is off). The
timeout is four seconds. The first menu line is still the official removable
entry.

## After download

1. New ARM64 VM (Apple Virtualization or QEMU).
2. Attach the ISO, or attach the `.img` as a disk. Do not attach the host internal disk.
3. Boot; the guest should reach GDM.
4. Do not write the `.img` to a stick expecting an M-series Mac to boot it.

Rebuild scripts: [`builder/`](builder/README.md). Origin notes: [FORK.md](FORK.md).
