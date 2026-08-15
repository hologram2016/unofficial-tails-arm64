# Unofficial fork notes

**This is not official Tails.** It is a public working copy of
[NoisyCoil’s unofficial arm64 / Asahi port](https://gitlab.tails.boum.org/noisycoil/tails)
of the [Tails](https://tails.net/) source tree, plus builder scripts and a
generic arm64 **VM** image.

- Not affiliated with the Tails Project, Tor, Asahi Linux, or Debian.
- NoisyCoil’s own preview warning still applies: **do not treat this like
  an official Tails release.** It will not protect you the way official Tails does.
- Official Tails is still **amd64 only**. Apple Silicon is unsupported by
  the Tails Project.

Read [README.md](README.md) for download and UTM steps.
Read [DOWNLOAD.md](DOWNLOAD.md) for Release assets.

## Why this repo exists

Official Tails does not ship arm64. NoisyCoil maintains an unofficial
port with two interesting lines:

| Upstream branch | Kernel | What it is for |
|-----------------|--------|----------------|
| `7.6.2/asahi` | Asahi / Apple Silicon laptop | Native Mac hardware (still needs internal firmware stub) |
| `7.6.2/arm64` | Generic Debian arm64 / UEFI | VMs (QEMU, UTM) and other generic AArch64 UEFI |

This GitHub repo is a place to:

1. Keep those trees on GitHub (shallow **snapshots**, not the full Tails history).
2. Build a **generic arm64** image in a VM on Apple Silicon.
3. Publish that unofficial ISO / `.img` so others can try the **VM** path.

It is **not** a promise of a Tails-equivalent live USB on M-series Macs.

## Apple Silicon live USB

A built image is **not** a drop-in USB amnesic OS on M1–M4 Macs.

Booting Linux on Apple Silicon normally needs an Asahi **`m1n1` + U-Boot**
EFI stub on the Mac’s **internal** disk first. That stub:

- is not something this project installs on a daily-driver Mac
- breaks the Tails idea of “leave no trace on the computer”
- is still **no / TBA** for some M4 installer / feature tables

So:

- **VM (this repo):** generic arm64 UEFI guest. This is the supported experiment.
- **Official Tails USB:** Intel/AMD PC, or an Intel Mac, from [tails.net](https://tails.net/).
- **Asahi on the internal disk:** out of scope. Do not do that “just to try Tails”.

## Provenance

| | |
|--|--|
| Asahi snapshot on `main` | `4d1ae11` — NoisyCoil `7.6.2/asahi` (`c2ea9e7`) |
| VM-kernel snapshot on `arm64` | `95923f7` — NoisyCoil `7.6.2/arm64` |
| Upstream (NoisyCoil) | https://gitlab.tails.boum.org/noisycoil/tails |
| Official Tails | https://gitlab.tails.boum.org/tails/tails |
| This GitHub repo | https://github.com/hologram2016/unofficial-tails-arm64 |

History here is a **shallow / orphan snapshot**, not a clone of the entire
Tails git history. Do not expect every upstream tag or merge commit.

### Remotes

```text
origin    https://github.com/hologram2016/unofficial-tails-arm64.git
upstream  https://gitlab.tails.boum.org/noisycoil/tails.git
```

## What we changed (on top of NoisyCoil)

These are **unofficial** build and VM fixes. They are not Tails Project work.

| Change | Where | Why |
|--------|--------|-----|
| `builder/` scripts | `main` | Headless QEMU/HVF Debian builder, resume, ISO→USB `.img`, download/publish helpers |
| `curl --fail --location` for Tor Browser | `arm64` (`da71a89`) | GitLab `/downloads/` URLs 302; without `--location` the SHA256 check failed |
| GRUB default = External Hard Disk | `arm64` (`89eb659`) and the published ISO/`.img` | QEMU/UTM virtio disks are not `live-media=removable` |
| Debian/Tor mirror remap | `builder/inside-vm-build.sh` | Official Tails time-based snapshots are **amd64-only** |
| Forky **ikiwiki** pin only | `builder/pin-ikiwiki-forky.sh` | Same idea as official Tails (website build); do not skip the website |

The published image also needed several **one-off resume** fixes during the
first build (IPv4 + public DNS in the chroot, `lb build noauto` so the
website was not rebuilt mid-chroot, treat a finished ISO as success). Those
lessons live in the builder scripts, not as a claim that the image is
“production Tails”.

### What is *not* in git

- Host workdir (images, qcow2 disks, logs, `STATUS.txt`)
- ntfy topic / URL (local env file only)
- SSH **private** keys
- Absolute home directories of any one Mac

Builder scripts take `TAILS_ARM64_WORK` (default `$HOME/tails-arm64-work`).
Someone else’s clone does **not** need the original machine’s paths.

`builder/cloud-init/user-data` contains an **SSH public** key used to log
into the *builder* VM (not the Tails guest). If you stand up your own
builder, replace that key with yours.

## How the unofficial image is built (short)

1. Debian 13 **arm64** cloud disk, 6 GB RAM, `qemu-system-aarch64` + HVF.
2. Copy the `arm64` source tree into the guest.
3. Official-style `lb config` / `lb build`, including the **offline website**
   (ikiwiki from Forky only).
4. Remap Tails time-based Debian/Tor snapshot URLs to archives that publish
   **arm64**.
5. `create-usb-image-from-iso` makes a GPT + FAT “Tails” ESP (no syslinux on
   aarch64).

The converter image is about **ISO size + 10 MiB**. Official Tails first-boot
then wants an **8 GB+** device before it will expand partitions. For VM tests
we used an 8 GB writable copy; the published `.img` is the small converter
output.

## Branches and Releases

| Ref | Meaning |
|-----|---------|
| `main` | Asahi snapshot + `builder/` + docs + download helper |
| `arm64` | Generic UEFI / VM kernel tree we built |
| `7.6.2/asahi` | Tracking ref for NoisyCoil’s Asahi branch (when fetched) |
| Release `unofficial-7.6.2-arm64.1` | Current unofficial ISO + `.img` + `SHA256SUMS` |

Release asset names (stable for the helper):

- `unofficial-tails-arm64-7.6.2.iso`
- `unofficial-tails-arm64-7.6.2.img`
- `SHA256SUMS`

## Verified so far (and not verified)

**Checked on Apple Silicon QEMU/HVF (unofficial image):**

- ISO and USB-layout `.img` boot UEFI GRUB.
- Default official-style entry (`live-media=removable`) fails on virtio/CD.
- **External Hard Disk** (now the default) reaches **GDM**.
- First-boot repartition runs on an 8 GB writable disk; virtio is not a
  removable stick.

**Not verified / not claimed:**

- Security equivalence with official Tails
- Amnesia on real hardware
- Native boot on any M-series Mac
- A full application / Tor / persistence test suite

## Licence

Same as upstream Tails: GNU GPL v3 or later (see `COPYING` and
[Tails’ licence page](https://tails.net/doc/about/license/)).
Tails includes non-free firmware so more hardware works.

NoisyCoil’s port is also GPL. This snapshot + scripts can be public for
that reason. The name “Tails” still belongs to the Tails Project — this
repo must stay clearly **unofficial**.
