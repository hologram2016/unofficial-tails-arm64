# Unofficial Tails-like arm64 (not official Tails)

**This repository is not official Tails.** It is not affiliated with the
[Tails Project](https://tails.net/), the Tor Project, Asahi Linux, or Debian.
Do not treat a build or a download from here as an official Tails release.
It will **not** protect you the way official Tails does.

| Want this | Use that |
|-----------|----------|
| Real Tails (amnesia USB, audited, amd64) | [tails.net](https://tails.net/) on an Intel/AMD PC or Intel Mac |
| Unofficial **VM** image for Apple Silicon (QEMU / UTM) | This repo’s [Releases](https://github.com/hologram2016/unofficial-tails-arm64/releases) |
| Native live USB / amnesia on an M-series Mac | **Not available here.** See [FORK.md](FORK.md#apple-silicon-live-usb) |

A downloaded ISO or `.img` does **not** contain anyone’s home directory or
builder paths. You attach the file in a VM. You do not need the original
machine’s disk layout.

## What this is

- A working GitHub copy of [NoisyCoil’s unofficial arm64 / Asahi Tails port](https://gitlab.tails.boum.org/noisycoil/tails) (version **7.6.2**).
- Extra **builder scripts** so we can produce a **generic arm64 UEFI** image and run it in **QEMU/HVF** or **UTM** on Apple Silicon.
- A published **unofficial** ISO and USB-style `.img` on [GitHub Releases](https://github.com/hologram2016/unofficial-tails-arm64/releases).

Two source lines live here:

| Branch | Kernel / target | Role |
|--------|-----------------|------|
| `main` | NoisyCoil `7.6.2/asahi` snapshot + `builder/` | Docs, download helper, builder scripts |
| `arm64` | NoisyCoil `7.6.2/arm64` (generic UEFI / VM kernel) | Tree we actually built |

The current VM image is the **generic arm64** line, not the Asahi laptop kernel.

## What this is not

- Not official Tails, not a Tails security equivalent, not “Tails for Apple Silicon”.
- Not an amnesic live USB you can plug into an M1/M2/M3/M4 Mac and boot.
- Not a reason to install Asahi Linux or `m1n1`+U-Boot on a daily-driver Mac.
- Not a Windows/Intel ISO. Official Tails remains **amd64-only**.

Linux on Apple Silicon as a **USB OS that forgets the machine** is blocked
in practice: the firmware stub has to live on the **internal** disk, which
breaks the Tails amnesia model. This project does not install that stub.

## Quick start (download a VM image)

```sh
# ISO (attach as a CD in UTM / QEMU)
curl -fL -O https://github.com/hologram2016/unofficial-tails-arm64/releases/latest/download/unofficial-tails-arm64-7.6.2.iso
curl -fL -O https://github.com/hologram2016/unofficial-tails-arm64/releases/latest/download/SHA256SUMS
shasum -a 256 -c SHA256SUMS
```

Or clone and run the helper (ISO by default):

```sh
git clone https://github.com/hologram2016/unofficial-tails-arm64.git
cd unofficial-tails-arm64
./builder/download-image.sh                 # ISO
./builder/download-image.sh --img           # USB-style disk image
./builder/download-image.sh --both --dir "$HOME/Downloads"
```

`gh` works too if you have [GitHub CLI](https://cli.github.com/) logged in.
Full notes: [DOWNLOAD.md](DOWNLOAD.md).

### Boot in UTM or QEMU

1. New VM, **ARM64** (Apple Virtualization or QEMU). Give it several GB of RAM.
2. Attach the **ISO**, or attach the **`.img` as a disk**.
3. Do **not** attach the Mac’s internal disk.
4. Let GRUB’s 4-second timeout run. The default is **External Hard Disk**
   (no `live-media=removable`). Virtio / UTM disks are not “removable”, so
   the first official-style menu line will fail to find the live filesystem.
5. You should reach GDM. This will not brick the Mac.

Do **not** `dd` the `.img` onto a USB stick expecting an M-series Mac to boot it.

## GRUB

On the unofficial arm64 image, GRUB **defaults to External Hard Disk**.
The official removable entries stay on the menu if you want them.

That default is set in the `arm64` branch (`config/binary_local-hooks/50-grub-efi`)
and was also patched into the published ISO / `.img`.

## Builder (rebuild from source)

Scripts in [`builder/`](builder/README.md) drive a **Debian 13 arm64**
guest under headless `qemu-system-aarch64` + HVF (not UTM — `utmctl` cannot
start VMs from SSH/agent sessions). They:

- remap official Tails **amd64-only** time-based snapshots to Debian / Tor archives
- pin **only ikiwiki** from Debian Forky (same idea as official Tails)
- run native `lb config` / `lb build` (including the offline website)
- can turn a finished ISO into a GPT/FAT USB `.img`

Host paths are **environment variables** (`TAILS_ARM64_WORK`,
`$HOME/tails-arm64-work` by default). They are not hardcoded to one Mac.
Optional ntfy topics stay in a local env file, not in git.

Rebuilds are large and slow. Most people should use the Release assets.

## Security honesty

- Official Tails: designed amnesia, Tor-by-default, a documented threat model, amd64.
- This image: unofficial port + our VM build fixes. We have verified it
  **boots to GDM in QEMU** on Apple Silicon. That is not a security audit.
- First-boot USB logic still expects an **8 GB+** stick if you treat the
  `.img` as a real Tails installer image. The published `.img` is about 1.9 GB
  (ISO + a small GPT wrapper).

If you need Tails’ guarantees, use [official Tails](https://tails.net/).

## Provenance and licence

See **[FORK.md](FORK.md)** for snapshots, remotes, what we changed, and
Apple Silicon USB limits.

Source is GNU GPL v3 or later, same as Tails (`COPYING`). Tails includes
non-free firmware so more hardware works. We did not change that.

## Official Tails

Everything about *real* Tails — downloads, design, donate, contribute —
lives at **[https://tails.net/](https://tails.net/)**. Their docs and
contribution pages do not apply to this unofficial image.
