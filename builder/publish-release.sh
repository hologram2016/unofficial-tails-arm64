#!/bin/bash
# Publish unofficial ISO + .img from TAILS_ARM64_WORK/images to GitHub Releases.
# Not official Tails. Does not print ntfy topics. No home paths required.
#
#   export TAILS_ARM64_WORK=/path/to/workdir
#   builder/publish-release.sh unofficial-7.6.2-arm64.1
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/host-env.sh
. "${SCRIPT_DIR}/lib/host-env.sh"

REPO="${TAILS_ARM64_REPO:-hologram2016/unofficial-tails-arm64}"
TAG="${1:?usage: publish-release.sh TAG}"
IMGDIR="${WORK}/images"

iso="$(ls -1 "${IMGDIR}"/tails-arm64-*.iso 2>/dev/null | tail -1 || true)"
img="$(ls -1 "${IMGDIR}"/tails-arm64-*.img 2>/dev/null | tail -1 || true)"
if [ -z "${iso}" ]; then
  echo "no tails-arm64-*.iso in ${IMGDIR}" >&2
  exit 1
fi

sums="${IMGDIR}/SHA256SUMS"
python3 - "$iso" "${img:-}" "$sums" <<'PY'
import hashlib, sys
from pathlib import Path

iso, img, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
lines = ["# Unofficial arm64 VM images — not official Tails"]


def add(path: str, name: str) -> None:
    if not path:
        return
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    lines.append(f"{digest.hexdigest()}  {name}")


add(iso, "unofficial-tails-arm64-7.6.2.iso")
if img:
    add(img, "unofficial-tails-arm64-7.6.2.img")
out.write_text("\n".join(lines) + "\n")
print(out.read_text(), end="")
PY

notes="$(mktemp)"
cat >"$notes" <<EOF
**Not official Tails.** Unofficial generic arm64 VM image (NoisyCoil 7.6.2/arm64 + our builder).

- QEMU / UTM on Apple Silicon only
- GRUB defaults to **External Hard Disk** (virtio is not removable)
- Not an amnesia live USB on M-series Macs
- Do not attach the host internal disk to the VM

Download: see DOWNLOAD.md or \`builder/download-image.sh\`.
EOF

if gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  echo "release ${TAG} already exists"
else
  gh release create "$TAG" -R "$REPO" \
    --title "Unofficial arm64 VM ${TAG} (not official Tails)" \
    --notes-file "$notes"
fi
rm -f "$notes"

# Stage short names. `file#name` breaks when WORK contains spaces.
stage="$(mktemp -d)"
cleanup_stage() { rm -rf "$stage"; }
trap cleanup_stage EXIT
ln "$iso" "${stage}/unofficial-tails-arm64-7.6.2.iso" 2>/dev/null || \
  cp "$iso" "${stage}/unofficial-tails-arm64-7.6.2.iso"
cp "$sums" "${stage}/SHA256SUMS"
if [ -n "${img}" ]; then
  ln "$img" "${stage}/unofficial-tails-arm64-7.6.2.img" 2>/dev/null || \
    cp "$img" "${stage}/unofficial-tails-arm64-7.6.2.img"
fi
gh release upload "$TAG" -R "$REPO" --clobber "${stage}"/*

echo "published ${TAG} on ${REPO}"
