#!/bin/bash
# Host orchestrator. Safe to re-run. Safe if SSH drops:
# launch with: nohup caffeinate -s -i this-script >>logs/setup.log 2>&1 &
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/host-env.sh
. "${SCRIPT_DIR}/lib/host-env.sh"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
UTMCTL="/Applications/UTM.app/Contents/MacOS/utmctl"
SSH_PUB="${SSH_KEY}.pub"
VM_NAME="tails-builder"
VM_UUID="67C93037-5AFB-4316-9D2A-6E50E0E4DD10"
DISK_ID="E1308C9D-6291-4652-A2B9-AF35A4F767E1"
CD_ID="9B22FFE6-EC20-41CF-80B1-A8575A8D336B"
MACADDR="DA:36:E0:02:FA:50"
SSH_PORT=2222
SRC_HOST="${WORK}/src/tails-arm64"
UTM_BUNDLE="${WORK}/utm/${VM_NAME}.utm"
UTM_DOCS="${HOME}/Library/Containers/com.utmapp.UTM/Data/Documents"
CLOUD_QCOW="${WORK}/images/debian-13-genericcloud-arm64.qcow2"
BUILDER_QCOW="${UTM_BUNDLE}/Data/${DISK_ID}.qcow2"
CIDATA_ISO="${UTM_BUNDLE}/Data/cidata.iso"

mkdir -p "${WORK}/logs" "${WORK}/images" "${WORK}/iso" "${UTM_BUNDLE}/Data"

status() {
  local line="$1"
  echo "$line" >"${WORK}/STATUS.txt"
  echo "$(date '+%Y-%m-%d %H:%M:%S') $line" | tee -a "${WORK}/logs/setup.log"
}

notify() {
  local msg="$1"
  local conf="${HOME}/.config/projects-notify/ntfy.env"
  if [ -f "$conf" ]; then
    # shellcheck disable=SC1090
    set +u
    source "$conf"
    set -u
    if [ -n "${NTFY_TOPIC:-}" ]; then
      curl -sS \
        -H "Title: tails-builder" \
        -H "Tags: computer" \
        -d "$msg" \
        "${NTFY_URL:-https://ntfy.sh}/${NTFY_TOPIC}" >/dev/null || true
    fi
  fi
}

ssh_vm() {
  ssh -F /dev/null \
    -i "$SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=8 \
    -o BatchMode=yes \
    -p "$SSH_PORT" \
    tailsbuild@127.0.0.1 \
    "$@"
}

wait_for() {
  local desc="$1"
  local tries="$2"
  shift 2
  local i=0
  while [ "$i" -lt "$tries" ]; do
    if "$@"; then
      return 0
    fi
    i=$((i + 1))
    sleep 5
  done
  status "FAILED timed out waiting for ${desc}"
  notify "tails-builder FAILED: timed out waiting for ${desc}"
  return 1
}

# ---------- 1. Debian cloud image ----------
status "PREPARING $(date) waiting for Debian cloud image"
if [ ! -s "$CLOUD_QCOW" ]; then
  status "FAILED missing $CLOUD_QCOW"
  exit 1
fi

# ---------- 2. qemu-img ----------
status "PREPARING $(date) waiting for qemu-img"
if ! command -v qemu-img >/dev/null 2>&1; then
  # brew may still be installing
  i=0
  while [ "$i" -lt 120 ]; do
    command -v qemu-img >/dev/null 2>&1 && break
    sleep 10
    i=$((i + 1))
  done
fi
if ! command -v qemu-img >/dev/null 2>&1; then
  status "FAILED qemu-img not on PATH after waiting"
  notify "tails-builder FAILED: qemu-img missing"
  exit 1
fi

# ---------- 3. arm64 source tree ----------
status "PREPARING $(date) waiting for arm64 source clone"
if [ ! -d "${SRC_HOST}/.git" ]; then
  i=0
  while [ "$i" -lt 180 ]; do
    [ -d "${SRC_HOST}/.git" ] && [ -f "${SRC_HOST}/auto/config" ] && break
    sleep 10
    i=$((i + 1))
  done
fi
if [ ! -f "${SRC_HOST}/auto/config" ]; then
  status "FAILED arm64 source clone did not finish"
  notify "tails-builder FAILED: source clone"
  exit 1
fi

# ---------- 4. GitHub arm64 branch (best effort) ----------
status "PREPARING $(date) pushing arm64 snapshot to GitHub"
if command -v gh >/dev/null 2>&1; then
  (
    set +e
    TMPBR="${WORK}/src/tails-arm64-github"
    if [ ! -d "${TMPBR}/.git" ]; then
      mkdir -p "$TMPBR"
      # reuse worktree files via rsync into an orphan repo
      rsync -a --delete --exclude .git "${SRC_HOST}/" "${TMPBR}/"
      git -C "$TMPBR" init -b arm64
      git -C "$TMPBR" config user.name "${GIT_AUTHOR_NAME:-$(git config --global user.name)}"
      git -C "$TMPBR" config user.email "${GIT_AUTHOR_EMAIL:-$(git config --global user.email)}"
      cat >"${TMPBR}/FORK.md" <<'EOF'
# Unofficial generic arm64 working snapshot

**This is not official Tails.** Generic UEFI arm64 tree from
NoisyCoil `7.6.2/arm64`, for virtual machines (UTM / KVM).

The Asahi kernel (Apple Silicon bare metal) lives on `main`.
This `arm64` branch is the VM image: Debian `linux-image-arm64`, not `linux-image-asahi`.
EOF
      git -C "$TMPBR" add -A
      git -C "$TMPBR" commit -m "Initial snapshot of NoisyCoil Tails 7.6.2/arm64 (VM kernel)."
      git -C "$TMPBR" remote add origin "https://github.com/${TAILS_ARM64_REPO:-hologram2016/unofficial-tails-arm64}.git"
    fi
    git -C "$TMPBR" push -u origin arm64
  ) >>"${WORK}/logs/github-push.log" 2>&1 || \
    echo "github push failed (non-fatal)" >>"${WORK}/logs/setup.log"
fi

# ---------- 5. cloud-init seed ----------
status "PREPARING $(date) building cloud-init seed"
SEED="${WORK}/iso/cidata-src"
rm -rf "$SEED"
mkdir -p "$SEED"
cp "${SCRIPT_DIR}/cloud-init/user-data" "${SCRIPT_DIR}/cloud-init/meta-data" "$SEED/"
# FAT labelled cidata — more reliable for cloud-init than ISO9660
rm -f "${WORK}/iso/cidata.cdr" "${WORK}/iso/cidata.iso"
hdiutil create -ov -fs "MS-DOS" -volname cidata \
  -srcfolder "$SEED" -format UDTO "${WORK}/iso/cidata" >/dev/null
mv -f "${WORK}/iso/cidata.cdr" "${WORK}/iso/cidata.iso"

# ---------- 6. UTM bundle ----------
status "PREPARING $(date) creating UTM bundle"
mkdir -p "${UTM_BUNDLE}/Data"
if [ ! -f "$BUILDER_QCOW" ]; then
  cp "$CLOUD_QCOW" "$BUILDER_QCOW"
  qemu-img resize "$BUILDER_QCOW" 64G
fi
cp -f "${WORK}/iso/cidata.iso" "$CIDATA_ISO"

cat >"${UTM_BUNDLE}/config.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Backend</key>
	<string>QEMU</string>
	<key>ConfigurationVersion</key>
	<integer>4</integer>
	<key>Display</key>
	<array>
		<dict>
			<key>DownscalingFilter</key>
			<string>Linear</string>
			<key>DynamicResolution</key>
			<true/>
			<key>Hardware</key>
			<string>virtio-ramfb</string>
			<key>NativeResolution</key>
			<false/>
			<key>UpscalingFilter</key>
			<string>Nearest</string>
		</dict>
	</array>
	<key>Drive</key>
	<array>
		<dict>
			<key>Identifier</key>
			<string>${CD_ID}</string>
			<key>ImageName</key>
			<string>cidata.iso</string>
			<key>ImageType</key>
			<string>CD</string>
			<key>Interface</key>
			<string>USB</string>
			<key>InterfaceVersion</key>
			<integer>1</integer>
			<key>ReadOnly</key>
			<true/>
		</dict>
		<dict>
			<key>Identifier</key>
			<string>${DISK_ID}</string>
			<key>ImageName</key>
			<string>${DISK_ID}.qcow2</string>
			<key>ImageType</key>
			<string>Disk</string>
			<key>Interface</key>
			<string>VirtIO</string>
			<key>InterfaceVersion</key>
			<integer>1</integer>
			<key>ReadOnly</key>
			<false/>
		</dict>
	</array>
	<key>Information</key>
	<dict>
		<key>Icon</key>
		<string>linux</string>
		<key>IconCustom</key>
		<false/>
		<key>Name</key>
		<string>${VM_NAME}</string>
		<key>UUID</key>
		<string>${VM_UUID}</string>
	</dict>
	<key>Input</key>
	<dict>
		<key>MaximumUsbShare</key>
		<integer>3</integer>
		<key>UsbBusSupport</key>
		<string>3.0</string>
		<key>UsbSharing</key>
		<false/>
	</dict>
	<key>Network</key>
	<array>
		<dict>
			<key>Hardware</key>
			<string>virtio-net-pci</string>
			<key>IsolateFromHost</key>
			<false/>
			<key>MacAddress</key>
			<string>${MACADDR}</string>
			<key>Mode</key>
			<string>Shared</string>
			<key>PortForward</key>
			<array>
				<dict>
					<key>GuestAddress</key>
					<string></string>
					<key>GuestPort</key>
					<integer>22</integer>
					<key>HostAddress</key>
					<string>127.0.0.1</string>
					<key>HostPort</key>
					<integer>${SSH_PORT}</integer>
					<key>Protocol</key>
					<string>TCP</string>
				</dict>
			</array>
		</dict>
	</array>
	<key>QEMU</key>
	<dict>
		<key>AdditionalArguments</key>
		<array/>
		<key>BalloonDevice</key>
		<false/>
		<key>DebugLog</key>
		<false/>
		<key>Hypervisor</key>
		<true/>
		<key>PS2Controller</key>
		<false/>
		<key>RNGDevice</key>
		<true/>
		<key>RTCLocalTime</key>
		<false/>
		<key>TPMDevice</key>
		<false/>
		<key>TSO</key>
		<false/>
		<key>UEFIBoot</key>
		<true/>
	</dict>
	<key>Serial</key>
	<array>
		<dict>
			<key>Mode</key>
			<string>Terminal</string>
			<key>Target</key>
			<string>Auto</string>
			<key>Terminal</key>
			<dict>
				<key>BackgroundColor</key>
				<string>#000000</string>
				<key>CursorBlink</key>
				<true/>
				<key>Font</key>
				<string>Menlo</string>
				<key>FontSize</key>
				<integer>12</integer>
				<key>ForegroundColor</key>
				<string>#ffffff</string>
			</dict>
		</dict>
	</array>
	<key>Sharing</key>
	<dict>
		<key>ClipboardSharing</key>
		<true/>
		<key>DirectoryShareMode</key>
		<string>VirtFS</string>
		<key>DirectorySharePath</key>
		<string>${WORK}</string>
		<key>DirectoryShareReadOnly</key>
		<false/>
	</dict>
	<key>Sound</key>
	<array>
		<dict>
			<key>Hardware</key>
			<string>intel-hda</string>
		</dict>
	</array>
	<key>System</key>
	<dict>
		<key>Architecture</key>
		<string>aarch64</string>
		<key>CPU</key>
		<string>default</string>
		<key>CPUCount</key>
		<integer>4</integer>
		<key>CPUFlagsAdd</key>
		<array/>
		<key>CPUFlagsRemove</key>
		<array/>
		<key>ForceMulticore</key>
		<false/>
		<key>JITCacheSize</key>
		<integer>0</integer>
		<key>MemorySize</key>
		<integer>6144</integer>
		<key>Target</key>
		<string>virt</string>
	</dict>
</dict>
</plist>
EOF

# Register with UTM via symlink into UTM's Documents folder
mkdir -p "$UTM_DOCS"
ln -sfn "$UTM_BUNDLE" "${UTM_DOCS}/${VM_NAME}.utm"

# ---------- 7. start UTM ----------
status "WAITING_SSH $(date) starting UTM ${VM_NAME}"
open -a UTM
sleep 5
# utmctl list may need a moment after first registration
if ! "$UTMCTL" list 2>/dev/null | grep -q "$VM_NAME"; then
  sleep 5
fi
if "$UTMCTL" list 2>/dev/null | grep -q "$VM_NAME"; then
  "$UTMCTL" start "$VM_NAME" || "$UTMCTL" start "$VM_UUID" || true
else
  # Opening the bundle registers it
  open "$UTM_BUNDLE"
  sleep 8
  "$UTMCTL" start "$VM_NAME" || "$UTMCTL" start "$VM_UUID" || true
fi

# ---------- 8. wait for SSH ----------
status "WAITING_SSH $(date) cloud-init + sshd"
wait_for "ssh" 120 ssh_vm true

# ---------- 9. wait for cloud-init packages ----------
status "WAITING_SSH $(date) waiting for cloud-init packages"
wait_for "cloud-init-done" 180 ssh_vm test -f /var/lib/tails-builder/cloud-init-done

# Try VirtFS mount (non-fatal)
ssh_vm 'sudo mkdir -p /mnt/work; sudo mount -t 9p -o trans=virtio,version=9p2000.L share /mnt/work 2>/dev/null || sudo mount -t virtiofs share /mnt/work 2>/dev/null || true' || true

# ---------- 10. copy source ----------
status "READY $(date) rsync source into VM"
rsync -a --delete \
  -e "ssh -F /dev/null -i ${SSH_KEY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p ${SSH_PORT}" \
  "${SRC_HOST}/" "tailsbuild@127.0.0.1:tails/"
scp -F /dev/null \
  -i "$SSH_KEY" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -P "$SSH_PORT" \
  "${SCRIPT_DIR}/inside-vm-build.sh" \
  tailsbuild@127.0.0.1:inside-vm-build.sh
ssh_vm 'chmod +x ~/inside-vm-build.sh'

# ---------- 11. detached build inside VM ----------
status "BUILDING $(date) starting nohup lb build in VM"
ssh_vm 'nohup bash ~/inside-vm-build.sh >~/build.log 2>&1 & echo $! >~/build.pid'
# host-side watcher: poll until COMPLETE/FAILED, write STATUS
(
  while true; do
    remote="$(ssh_vm 'cat ~/STATUS.txt 2>/dev/null' || echo 'BUILDING unreachable')"
    echo "$remote" >"${WORK}/STATUS.txt"
    case "$remote" in
      COMPLETE*|FAILED*) break ;;
    esac
    sleep 60
  done
  notify "tails-builder: $remote"
) >>"${WORK}/logs/watch.log" 2>&1 &
echo $! >"${WORK}/watch.pid"

status "BUILDING $(date) image build running in VM (see HOW-TO-RECONNECT.txt)"
notify "tails-builder: BUILDING — session can drop"
exit 0
