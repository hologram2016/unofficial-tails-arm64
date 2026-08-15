#!/bin/bash
# Official Tails builder recipe: ikiwiki from Forky only; all other
# Forky packages pinned away. Run as root on the Debian builder VM.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

install -d /etc/apt/sources.list.d /etc/apt/preferences.d

cat >/etc/apt/sources.list.d/forky.sources <<'EOF'
Types: deb
URIs: mirror+file:///etc/apt/mirrors/debian.list
Suites: forky
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

cat >/etc/apt/preferences.d/ikiwiki <<'EOF'
Package: ikiwiki
Pin: release n=forky
Pin-Priority: 1000
EOF

cat >/etc/apt/preferences.d/forky <<'EOF'
Package: *
Pin: release n=forky
Pin-Priority: 1
EOF

apt-get update -qq
apt-get install -y --no-install-recommends ikiwiki
apt-cache policy ikiwiki
command -v ikiwiki
ikiwiki --version | head -1
