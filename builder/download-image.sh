#!/bin/bash
# Download the latest unofficial arm64 VM image from GitHub Releases.
#
# NOT official Tails. NOT a working amnesia USB on Apple Silicon Macs.
# For QEMU/UTM on arm64 only. GRUB defaults to External Hard Disk.
#
# Public GitHub Releases. Prefer curl; `gh` also works if installed.
#
# Usage:
#   builder/download-image.sh              # ISO (UTM / QEMU CD)
#   builder/download-image.sh --img        # USB-style disk image
#   builder/download-image.sh --both
#   builder/download-image.sh --dir DIR
#   builder/download-image.sh --tag unofficial-7.6.2-arm64.1
set -euo pipefail

REPO="${TAILS_ASAHI_REPO:-hologram2016/tails-asahi}"
WANT_ISO=1
WANT_IMG=0
OUTDIR="."
TAG=""

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --iso) WANT_ISO=1; WANT_IMG=0; shift ;;
    --img) WANT_ISO=0; WANT_IMG=1; shift ;;
    --both) WANT_ISO=1; WANT_IMG=1; shift ;;
    --dir) OUTDIR="${2:?}"; shift 2 ;;
    --tag) TAG="${2:?}"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "unknown option: $1" >&2; usage 1 ;;
  esac
done

mkdir -p "$OUTDIR"
OUTDIR="$(cd "$OUTDIR" && pwd)"
cd "$OUTDIR"

echo "Unofficial Tails-like arm64 image — not official Tails."
echo "Not a live USB for Apple Silicon. Repo: ${REPO}"
echo "Saving into: ${OUTDIR}"

have_gh() { command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; }

patterns=()
[ "$WANT_ISO" = 1 ] && patterns+=("*.iso")
[ "$WANT_IMG" = 1 ] && patterns+=("*.img")
patterns+=("SHA256SUMS")

names=()
[ "$WANT_ISO" = 1 ] && names+=("tails-asahi-unofficial-7.6.2-arm64.iso")
[ "$WANT_IMG" = 1 ] && names+=("tails-asahi-unofficial-7.6.2-arm64.img")
names+=("SHA256SUMS")

if have_gh; then
  args=(release download -R "$REPO")
  [ -n "$TAG" ] && args+=("$TAG")
  [ -z "$TAG" ] && args+=(--latest)
  for p in "${patterns[@]}"; do
    args+=(-p "$p")
  done
  args+=(--clobber)
  echo "Downloading with gh from ${REPO}..."
  gh "${args[@]}"
else
  if [ -n "$TAG" ]; then
    base="https://github.com/${REPO}/releases/download/${TAG}"
  else
    base="https://github.com/${REPO}/releases/latest/download"
  fi
  echo "Downloading with curl from ${base} ..."
  for f in "${names[@]}"; do
    curl -fL --retry 5 -o "$f" "${base}/${f}"
  done
fi

if [ -f SHA256SUMS ]; then
  echo "Verifying SHA256..."
  # macOS shasum has no --ignore-missing; check only files we downloaded.
  while read -r hash name; do
    [ -n "${hash:-}" ] && [ -n "${name:-}" ] || continue
    [ -f "$name" ] || continue
    if command -v shasum >/dev/null 2>&1; then
      echo "${hash}  ${name}" | shasum -a 256 -c -
    else
      echo "${hash}  ${name}" | sha256sum -c -
    fi
  done <SHA256SUMS
fi

echo
echo "Done. In UTM: new Apple Virtualization / QEMU ARM VM, attach the ISO"
echo "(or the .img as a disk). Let GRUB time out — default is External Hard Disk."
echo "Do not treat this as official Tails. Do not expect an M4 amnesia USB."
