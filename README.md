# unofficial-tails-arm64

Not official Tails. Not affiliated with the [Tails Project](https://tails.net/),
the Tor Project, Asahi Linux, or Debian. Images and builds from this repository
are not official releases and do not carry Tails’ security properties.

Official Tails (amd64, amnesia USB) is published at
[tails.net](https://tails.net/).

This repository holds:

- snapshots of [NoisyCoil’s unofficial arm64 / Asahi Tails port](https://gitlab.tails.boum.org/noisycoil/tails) (7.6.2)
- scripts that build a **generic arm64 UEFI** image for QEMU or UTM
- [Release](https://github.com/hologram2016/unofficial-tails-arm64/releases) assets: an unofficial ISO and USB-style `.img`

| Branch | Contents |
|--------|----------|
| `main` | NoisyCoil `7.6.2/asahi` snapshot, `builder/`, documentation |
| `arm64` | NoisyCoil `7.6.2/arm64` (generic UEFI / VM kernel); this is the tree used for the published image |

The published image uses the generic arm64 kernel, not the Asahi laptop kernel.

It is not a live USB for M-series Macs, and it is not a reason to install
Asahi or `m1n1`+U-Boot on an internal disk. Apple Silicon USB boot needs a
firmware stub on the **internal** disk, which is incompatible with Tails’
amnesia model. That stub is out of scope. See [FORK.md](FORK.md).

Release files are ordinary ISO / disk images. They do not embed another
machine’s home directory or builder paths.

## Download

```sh
curl -fL -O https://github.com/hologram2016/unofficial-tails-arm64/releases/latest/download/unofficial-tails-arm64-7.6.2.iso
curl -fL -O https://github.com/hologram2016/unofficial-tails-arm64/releases/latest/download/SHA256SUMS
shasum -a 256 -c SHA256SUMS
```

```sh
git clone https://github.com/hologram2016/unofficial-tails-arm64.git
cd unofficial-tails-arm64
./builder/download-image.sh            # ISO
./builder/download-image.sh --img      # USB-style .img
```

Details: [DOWNLOAD.md](DOWNLOAD.md).

## Boot (UTM or QEMU)

1. Create an ARM64 virtual machine. Several gigabytes of RAM are required.
2. Attach the ISO, or attach the `.img` as a disk. Do not attach the host’s internal disk.
3. Leave GRUB at the default, **External Hard Disk** (4-second timeout). Virtio and similar virtual disks are not `live-media=removable`; the first official-style menu entry will not find the live filesystem.
4. The guest should reach GDM.

Do not write the `.img` to a USB stick in the expectation that an M-series
Mac will boot it.

## GRUB

The unofficial arm64 image defaults to External Hard Disk. Removable entries
remain on the menu. The default is set in `arm64`
(`config/binary_local-hooks/50-grub-efi`) and in the published assets.

## Rebuilds

[`builder/`](builder/README.md) runs Debian 13 arm64 under headless
`qemu-system-aarch64` + HVF. Official Tails time-based snapshots are
amd64-only; the guest remaps Debian and Tor to archives that publish arm64.
Website generation uses ikiwiki from Debian Forky only, as in official Tails.
`utmctl` cannot start guests from a non-GUI session; QEMU is the builder.

The workdir is `TAILS_ARM64_WORK` (default `$HOME/tails-arm64-work`). Rebuilds
are large. Prefer the Release assets unless a new image is required.

QEMU on Apple Silicon has reached GDM with this image. That is a boot check,
not a security audit. Official Tails first-boot still expects an 8 GB or
larger device if the `.img` is treated as an installer stick; the published
`.img` is about 1.9 GB (ISO plus a small GPT wrapper).

## Licence and origin

GNU GPL v3 or later, same as Tails (`COPYING`). Non-free firmware is included,
as in Tails.

Snapshots, remotes, and local patches: [FORK.md](FORK.md).
Official Tails documentation and contribution pages apply only to
[tails.net](https://tails.net/).
