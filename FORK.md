# Unofficial Apple Silicon working fork

**This is not official Tails.** It is a private working copy of
[NoisyCoil's unofficial arm64 / Asahi port](https://gitlab.tails.boum.org/noisycoil/tails)
of the [Tails](https://tails.net/) source tree.

- Not affiliated with the Tails Project, Tor, Asahi Linux, or Debian.
- NoisyCoil's own preview warning still applies: **do not treat this like an official Tails release.** It will not protect you the way official Tails does.
- Official Tails is still **amd64 only**. Apple Silicon is unsupported by the Tails Project.
- A built image is **not** a drop-in USB amnesic OS on M-series Macs. Booting Linux on Apple Silicon needs an Asahi `m1n1` + U-Boot EFI stub on the Mac's **internal** disk first.

## Provenance

| | |
|--|--|
| Snapshot | NoisyCoil branch / tag `7.6.2/asahi` (`c2ea9e7`) |
| Upstream | https://gitlab.tails.boum.org/noisycoil/tails |
| Official Tails | https://gitlab.tails.boum.org/tails/tails |
| This GitHub repo | private working tree only |

History here is a **shallow snapshot** of that Asahi branch, not the full Tails git history.

Host/guest scripts for the unofficial **VM image** live in [`builder/`](builder/README.md) (`arm64` branch + QEMU/HVF, not Asahi live USB).

## Remotes

```text
origin    https://github.com/hologram2016/tails-asahi.git
upstream  https://gitlab.tails.boum.org/noisycoil/tails.git
```

## License

Same as upstream Tails: GNU GPL v3 or later (see `COPYING` and the Tails license page).
Non-free firmware is included in Tails builds for hardware support.
