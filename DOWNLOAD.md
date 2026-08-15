# Downloads

Not official Tails. These files are for QEMU or UTM on Apple Silicon. They
are not an amnesia live USB for M-series Macs.

Official Tails (amd64): <https://tails.net/>.

The ISO and `.img` are ordinary image files. They do not contain another
machine’s home directory or builder paths.

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

| File | Use |
|------|-----|
| `unofficial-tails-arm64-7.6.2.iso` | CD in UTM or QEMU |
| `unofficial-tails-arm64-7.6.2.img` | Virtio or USB disk |
| `SHA256SUMS` | Checksums |

GRUB defaults to External Hard Disk (`live-media=removable` is off). The
timeout is four seconds. The first menu line is still the official removable
entry.

## After download

1. New ARM64 VM (Apple Virtualization or QEMU).
2. Attach the ISO, or attach the `.img` as a disk. Do not attach the host internal disk.
3. Boot; the guest should reach GDM.
4. Do not write the `.img` to a stick expecting an M-series Mac to boot it.

Rebuild scripts: [`builder/`](builder/README.md). Origin notes: [FORK.md](FORK.md).
