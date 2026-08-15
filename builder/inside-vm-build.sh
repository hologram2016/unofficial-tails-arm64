#!/bin/bash
# Runs *inside* the Debian builder VM. Detached by the host via nohup.
# Writes ~/STATUS.txt, ~/build.pid and ~/build.log. Also mirrors status
# onto /mnt/work when the VirtFS share is mounted.
#
# Official Tails time-based snapshots are amd64-only and re-signed with
# the Tails archive key. This unofficial arm64 build remaps Debian and
# TorProject mirrors to the upstream archives (which publish arm64).
# The Tails custom repo (deb.tails.boum.org) stays as-is until it fails.
#
# SKIP_LB_CONFIG=1     reuse an already-finished lb config + website.
# SKIP_CHROOT_CLEAN=1  do not delete the chroot (resume after a hook fail).
# RESUME_FROM_HOOK=08-install-Perl-programs
#   move earlier local-hooks aside so lb does not re-run adduser etc.
set -euo pipefail

HOME_DIR="${HOME:-/home/tailsbuild}"
SRC="${HOME_DIR}/tails"
LOG="${HOME_DIR}/build.log"
STATUS="${HOME_DIR}/STATUS.txt"
PIDFILE="${HOME_DIR}/build.pid"
WORK_STATUS="/mnt/work/STATUS.txt"

echo $$ >"$PIDFILE"

on_exit() {
  local rc="${1:-$?}"
  rm -f "$PIDFILE"
  if [ "$rc" -ne 0 ]; then
    echo "FAILED $(date --utc '+%Y-%m-%dT%H:%MZ') inside-vm-build exit $rc" | tee "$STATUS" >/dev/null
    if [ -d /mnt/work ] && touch /mnt/work/.writetest 2>/dev/null; then
      rm -f /mnt/work/.writetest
      echo "FAILED $(date --utc '+%Y-%m-%dT%H:%MZ') inside-vm-build exit $rc" >"$WORK_STATUS"
    fi
  fi
}
trap 'rc=$?; restore_parked_hooks; on_exit "$rc"' EXIT

HOOK_PARK=""
restore_parked_hooks() {
  if [ -n "${HOOK_PARK:-}" ] && [ -d "${HOOK_PARK}" ]; then
    sudo mv "${HOOK_PARK}"/* config/chroot_local-hooks/ 2>/dev/null || true
    rmdir "${HOOK_PARK}" 2>/dev/null || true
    HOOK_PARK=""
  fi
}

say() {
  local line="$1"
  echo "$line" | tee "$STATUS" >/dev/null
  if [ -d /mnt/work ] && touch /mnt/work/.writetest 2>/dev/null; then
    rm -f /mnt/work/.writetest
    echo "$line" >"$WORK_STATUS"
  fi
  echo "$(date --utc '+%Y-%m-%dT%H:%MZ') $line" >>"$LOG"
}

# QEMU user-net slirp DNS (10.0.2.3) flakes under heavy apt. Prefer IPv4
# and public resolvers so chroot hooks can fetch packages.
harden_guest_dns() {
  say "BUILDING pinning IPv4 + public DNS (avoid QEMU slirp DNS flakes)"
  printf 'precedence :ffff:0:0/96  100\n' | sudo tee /etc/gai.conf >/dev/null
  echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4 >/dev/null
  echo 'Acquire::Retries "20";' | sudo tee /etc/apt/apt.conf.d/99retries >/dev/null
  # Break systemd-resolved stub so chroot copies a resolver that works
  # inside the chroot (127.0.0.53 is the VM stub; 127.0.0.1 in the chroot
  # is nothing).
  sudo rm -f /etc/resolv.conf
  printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\n' | sudo tee /etc/resolv.conf >/dev/null
  if [ -d chroot/etc ]; then
    sudo mkdir -p chroot/etc/apt/apt.conf.d
    echo 'Acquire::ForceIPv4 "true";' | sudo tee chroot/etc/apt/apt.conf.d/99force-ipv4 >/dev/null
    echo 'Acquire::Retries "20";' | sudo tee chroot/etc/apt/apt.conf.d/99retries >/dev/null
    printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\n' | sudo tee chroot/etc/resolv.conf >/dev/null
    printf 'precedence :ffff:0:0/96  100\n' | sudo tee chroot/etc/gai.conf >/dev/null
  fi
}

# Official Tails snapshots: amd64 only. Use Debian/Tor archives for arm64.
remap_debian_mirrors() {
  local debian_m="${TAILS_DEBIAN_MIRROR:-http://deb.debian.org/debian}"
  local security_m="${TAILS_DEBIAN_SECURITY_MIRROR:-http://security.debian.org/debian-security}"
  local tor_m="${TAILS_TOR_MIRROR:-http://deb.torproject.org/torproject.org}"
  local f
  say "BUILDING remapping amd64-only Tails snapshots to Debian/Tor arm64 archives"
  for f in config/bootstrap config/chroot_sources/*.chroot config/chroot_sources/*.binary; do
    [ -f "$f" ] || continue
    sed -i \
      -e "s|http://time-based.snapshots.deb.tails.boum.org/debian/[0-9][0-9]*|${debian_m}|g" \
      -e "s|http://time-based.snapshots.deb.tails.boum.org/debian-security/[0-9][0-9]*|${security_m}|g" \
      -e "s|http://time-based.snapshots.deb.tails.boum.org/torproject/[0-9][0-9]*|${tor_m}|g" \
      "$f"
  done
}

say "BUILDING $(date --utc '+%Y-%m-%dT%H:%MZ') starting lb config/build"

cd "$SRC"

# Orphan/shallow snapshots have no official release tags. apt-mirror on a
# stable-based branch then dies with "None of the two last version in
# changelog were released". A lightweight tag for the *previous* changelog
# version unblocks time-based snapshots. Do not tag the current version
# (e.g. 7.6.2): if HEAD is also a tag, apt-mirror would pick official
# tagged Tails snapshots, which are amd64-only.
PREV_VER="$(dpkg-parsechangelog --offset 1 --count 1 | awk '/^Version: / { print $2 }')"
if [ -n "${PREV_VER}" ] && [ -z "$(git tag -l "${PREV_VER}")" ]; then
  git tag "${PREV_VER}"
fi

if [ ! -x /usr/bin/lb ] && [ ! -x /usr/local/bin/lb ]; then
  if [ -d submodules/live-build ]; then
    sudo make -C submodules/live-build install
  else
    say "FAILED no live-build submodule and no lb binary"
    exit 1
  fi
else
  # Always reinstall from the Tails submodule so we use their fork.
  if [ -d submodules/live-build ]; then
    sudo make -C submodules/live-build install
  fi
fi

export TAILS_PROXY_TYPE="${TAILS_PROXY_TYPE:-none}"
export TAILS_WEBSITE_CACHE="${TAILS_WEBSITE_CACHE:-no}"
export TAILS_RAM_BUILD="${TAILS_RAM_BUILD:-no}"
export GIT_COMMIT="${GIT_COMMIT:-$(git rev-parse HEAD)}"
export GIT_REF="${GIT_REF:-$(git rev-parse --abbrev-ref HEAD)}"
export BASE_BRANCH_GIT_COMMIT="${BASE_BRANCH_GIT_COMMIT:-$GIT_COMMIT}"
export FEATURE_BRANCH_GIT_COMMIT="${FEATURE_BRANCH_GIT_COMMIT:-$GIT_COMMIT}"
# auto/build normally sources this. `lb build noauto` does not, and hook
# 19-clock-epoch plus squashfs/ISO stages need SOURCE_DATE_EPOCH.
# shellcheck disable=SC1091
. config/variables
if [ -f tmp/build_environment ]; then
  # shellcheck disable=SC1091
  . tmp/build_environment
  export EXTRA_XORRISO_OPTIONS
fi
: "${MKSQUASHFS_OPTIONS:=-comp zstd -Xcompression-level 22 -b 1024K -no-exports}"
export MKSQUASHFS_OPTIONS="${MKSQUASHFS_OPTIONS} -mem 512M -wildcards -ef chroot/usr/share/tails/build/mksquashfs-excludes"
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY || true

PRESERVE=TAILS_PROXY_TYPE,TAILS_WEBSITE_CACHE,TAILS_RAM_BUILD,GIT_COMMIT,GIT_REF,BASE_BRANCH_GIT_COMMIT,FEATURE_BRANCH_GIT_COMMIT,SOURCE_DATE_EPOCH,SOURCE_DATE_YYYYMMDD,MKSQUASHFS_OPTIONS,EXTRA_XORRISO_OPTIONS

# Native live-build on this VM (no nested Vagrant).
if [ "${SKIP_LB_CONFIG:-0}" = 1 ]; then
  if [ "${SKIP_CHROOT_CLEAN:-0}" = 1 ]; then
    say "BUILDING skip lb config; resume existing chroot"
  else
    say "BUILDING skip lb config (keep offline website); clean failed chroot only"
    # Do not use `lb clean --all`: it deletes tracked package lists.
    sudo rm -rf chroot .build/bootstrap .build/chroot || true
  fi
  remap_debian_mirrors
else
  sudo --preserve-env="$PRESERVE" lb config --cache false
  remap_debian_mirrors
fi

harden_guest_dns

if [ -n "${RESUME_FROM_HOOK:-}" ]; then
  say "BUILDING resume local-hooks from ${RESUME_FROM_HOOK}"
  sudo rm -f .lock
  # Mount stamps lie after a failed cleanup (unmounted, stamp still present).
  # Only remount proc/dev/sys/resolv. Re-running hosts/apt/dpkg install
  # recreates *.orig backups and 99-zzz_check-for-dot-orig-files dies.
  sudo rm -f .stage/chroot_devpts .stage/chroot_proc .stage/chroot_sysfs \
    .stage/chroot_resolv
  HOOK_PARK="$(mktemp -d /tmp/done-hooks.XXXXXX)"
  for hook in config/chroot_local-hooks/*; do
    base="$(basename "$hook")"
    if [ "$base" = "$RESUME_FROM_HOOK" ]; then
      break
    fi
    sudo mv "$hook" "$HOOK_PARK/"
  done
  # 99-zzz_check-for-dot-orig-files -> 01-check-for-dot-orig-files.
  # Parking 01 leaves that symlink dangling and `cp` dies.
  for hook in config/chroot_local-hooks/*; do
    if [ -L "$hook" ] && [ ! -e "$hook" ]; then
      target="$(basename "$(readlink "$hook")")"
      if [ -f "${HOOK_PARK}/${target}" ]; then
        sudo rm -f "$hook"
        sudo cp "${HOOK_PARK}/${target}" "$hook"
        sudo chmod +x "$hook"
      fi
    fi
  done
fi

# `lb build` (no args) runs auto/build, which re-runs the website and
# refresh-translations. intltool then scans the populated chroot and
# dies. `noauto` continues from live-build stage files instead.
if [ "${SKIP_LB_CONFIG:-0}" = 1 ]; then
  sudo --preserve-env="$PRESERVE" lb build noauto
else
  sudo --preserve-env="$PRESERVE" lb build
fi
restore_parked_hooks
HOOK_PARK=""

# auto/build normally renames binary.iso and builds the USB image.
# We use `lb build noauto` on resume, so do the arm64-safe tail here.
# isohybrid is amd64-only; USB .img needs udisks and is a later step.
if [ -f binary.iso ] && ! compgen -G "tails-*.iso" >/dev/null; then
  if [ -f tmp/build_environment ]; then
    # shellcheck disable=SC1091
    . tmp/build_environment
  fi
  iso_name="${BUILD_BASENAME:-tails-arm64-unsigned}.iso"
  sudo truncate -s %2048 binary.iso
  sudo mv -f binary.iso "$iso_name"
  [ -f binary.packages ] && sudo mv -f binary.packages "${iso_name%.iso}.packages"
fi

if compgen -G "tails-*.img" >/dev/null || compgen -G "tails-*.iso" >/dev/null; then
  mkdir -p /mnt/work/images 2>/dev/null || true
  cp -n tails-*.img tails-*.iso /mnt/work/images/ 2>/dev/null || true
  ls -lh tails-*.iso tails-*.img tails-*.packages 2>/dev/null | tee -a "$LOG"
  say "COMPLETE $(date --utc '+%Y-%m-%dT%H:%MZ') unofficial image built (not official Tails)"
  exit 0
fi

say "FAILED $(date --utc '+%Y-%m-%dT%H:%MZ') lb build finished with no tails-*.iso or tails-*.img"
exit 1
