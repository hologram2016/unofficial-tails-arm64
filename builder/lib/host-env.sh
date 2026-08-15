# Shared host-side paths for the unofficial Tails arm64 builder.
# Source from the other scripts in this directory. Do not print ntfy topics.
#
#   export TAILS_ASAHI_WORK=/path/to/workdir   # disks, logs, STATUS
#   export TAILS_BUILDER_SSH_KEY=$HOME/.ssh/id_ed25519_tails_builder
#
# This file must not contain absolute home directories or ntfy topics.

: "${TAILS_ASAHI_WORK:=${HOME}/tails-asahi-work}"
: "${TAILS_BUILDER_SSH_KEY:=${HOME}/.ssh/id_ed25519_tails_builder}"
: "${TAILS_BUILDER_SSH_PORT:=2222}"
: "${TAILS_BUILDER_SSH_USER:=tailsbuild}"
: "${TAILS_BUILDER_SSH_HOST:=127.0.0.1}"

export TAILS_ASAHI_WORK TAILS_BUILDER_SSH_KEY TAILS_BUILDER_SSH_PORT
export TAILS_BUILDER_SSH_USER TAILS_BUILDER_SSH_HOST

WORK="${TAILS_ASAHI_WORK}"
SSH_KEY="${TAILS_BUILDER_SSH_KEY}"
SSH_PORT="${TAILS_BUILDER_SSH_PORT}"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"
