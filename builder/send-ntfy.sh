#!/bin/bash
# Send one ntfy push. Does not print the topic.
# Usage: send-ntfy.sh TITLE TAGS body...
set -euo pipefail
CONF="${HOME}/.config/projects-notify/ntfy.env"
if [ ! -f "$CONF" ]; then
  echo "missing ntfy.env" >&2
  exit 1
fi
# shellcheck disable=SC1090
set +u
source "$CONF"
set -u
if [ -z "${NTFY_TOPIC:-}" ]; then
  echo "NTFY_TOPIC unset" >&2
  exit 1
fi
TITLE="${1:-tails-builder}"
TAGS="${2:-computer}"
shift 2
BODY="${*:-no message}"
curl -sS \
  -H "Title: ${TITLE}" \
  -H "Tags: ${TAGS}" \
  -d "${BODY}" \
  "${NTFY_URL:-https://ntfy.sh}/${NTFY_TOPIC}" >/dev/null
echo "ntfy sent (topic not printed)"
