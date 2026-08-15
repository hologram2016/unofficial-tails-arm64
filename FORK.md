# Origin of this tree

Not official Tails. Not affiliated with the Tails Project, Tor, Asahi Linux,
or Debian. NoisyCoil’s preview warning applies: do not treat this as an
official Tails release.

Download and boot: [README.md](README.md), [DOWNLOAD.md](DOWNLOAD.md).

Official Tails does not ship arm64. NoisyCoil’s unofficial port has two
branches of interest:

| Upstream branch | Kernel | Intended use |
|-----------------|--------|----------------|
| `7.6.2/asahi` | Asahi (Apple Silicon) | Native Mac hardware; still requires an internal firmware stub |
| `7.6.2/arm64` | Generic Debian arm64 / UEFI | Virtual machines and other generic AArch64 UEFI |

This GitHub repository stores shallow snapshots of those trees, scripts that
build the generic arm64 image, and Release assets for that VM image. It does
not provide a Tails-equivalent live USB on M-series Macs.

## Apple Silicon USB boot

An image from this project is not an amnesic USB OS for M1–M4.

Linux on Apple Silicon normally requires Asahi `m1n1` and U-Boot as an EFI
stub on the **internal** disk. That stub is outside the scope of this
repository, and it contradicts Tails’ “leave no trace on the computer”
model. M4 installer tables have listed the relevant support as no or TBA.

| Goal | Route |
|------|--------|
| VM on Apple Silicon | Generic arm64 UEFI guest (this repository) |
| Official Tails USB | Intel/AMD PC or Intel Mac, from [tails.net](https://tails.net/) |
| Asahi on the internal disk | Out of scope |

## Snapshots

| Item | Reference |
|------|-----------|
| Asahi snapshot on `main` | `4d1ae11` (NoisyCoil `7.6.2/asahi`, `c2ea9e7`) |
| VM-kernel snapshot on `arm64` | `95923f7` (NoisyCoil `7.6.2/arm64`) |
| NoisyCoil | https://gitlab.tails.boum.org/noisycoil/tails |
| Official Tails | https://gitlab.tails.boum.org/tails/tails |
| This repository | https://github.com/hologram2016/unofficial-tails-arm64 |

History is a shallow, orphan snapshot, not a full clone of Tails. Upstream
tags and merge commits are not all present.

```text
origin    https://github.com/hologram2016/unofficial-tails-arm64.git
upstream  https://gitlab.tails.boum.org/noisycoil/tails.git
```

## Local patches (not Tails Project work)

| Change | Location | Reason |
|--------|----------|--------|
| Builder scripts | `builder/` on `main` | Headless QEMU/HVF Debian guest; ISO to USB `.img`; download helper |
| `curl --fail --location` for Tor Browser | `arm64` (`da71a89`) | GitLab `/downloads/` URLs return 302; SHA256 failed without `--location` |
| GRUB default External Hard Disk | `arm64` (`89eb659`); published ISO and `.img` | Virtio/UTM disks are not `live-media=removable` |
| Debian/Tor mirror remap | `builder/inside-vm-build.sh` | Official Tails time-based snapshots are amd64-only |
| Forky ikiwiki pin | `builder/pin-ikiwiki-forky.sh` | Official Tails takes only ikiwiki from Forky; the website build is required |

The first image build also needed resume handling (IPv4 and public DNS in
the chroot, `lb build noauto` after the website existed, treating a finished
ISO as success). Those behaviours are in the builder scripts.

Not stored in git: host workdirs, ntfy configuration, SSH private keys,
absolute home paths. Scripts use `TAILS_ARM64_WORK` (default
`$HOME/tails-arm64-work`).

`builder/cloud-init/user-data` contains an SSH **public** key for the builder
guest (not the Tails session). Replace it when running a builder of your own.

## Build outline

1. Debian 13 arm64 cloud disk, 6 GB RAM, `qemu-system-aarch64` + HVF.
2. `arm64` source tree copied into the guest.
3. `lb config` / `lb build`, including the offline website (ikiwiki from Forky).
4. Tails snapshot URLs remapped to Debian/Tor archives that publish arm64.
5. `create-usb-image-from-iso` writes a GPT + FAT ESP (no syslinux on aarch64).

The converter `.img` is roughly the ISO size plus 10 MiB. Official Tails
first-boot then requires an 8 GB or larger device before it expands
partitions. The published `.img` is that small converter output.

## Branches and releases

| Ref | Contents |
|-----|----------|
| `main` | Asahi snapshot, `builder/`, documentation |
| `arm64` | Generic UEFI / VM kernel tree used for the image |
| `7.6.2/asahi` | Tracking ref for NoisyCoil’s Asahi branch, when fetched |
| Release `unofficial-7.6.2-arm64.1` | Current unofficial ISO, `.img`, `SHA256SUMS` |

Release names used by the download helper:

- `unofficial-tails-arm64-7.6.2.iso`
- `unofficial-tails-arm64-7.6.2.img`
- `SHA256SUMS`

## Checks and limits

Observed on Apple Silicon QEMU/HVF with the unofficial image: UEFI GRUB
starts from both the ISO and the USB-layout `.img`; `live-media=removable`
fails on virtio and CD; External Hard Disk (the default) reaches GDM;
first-boot repartition runs on an 8 GB writable disk.

Not claimed: equivalence with official Tails, amnesia on hardware, native
boot on M-series Macs, or a full application / Tor / persistence test suite.

## Licence

GNU GPL v3 or later (`COPYING`; [Tails licence](https://tails.net/doc/about/license/)).
Non-free firmware is included, as in Tails. NoisyCoil’s port is also GPL.
The name “Tails” belongs to the Tails Project; this tree is unofficial.
