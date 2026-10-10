#!/bin/bash
# Auto-updater for rustdesk
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest RustDesk version..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/rustdesk/rustdesk/releases/latest")

LATEST=$(echo "${INFO}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
# теги без 'v', но на всякий случай убираем
print(d['tag_name'].lstrip('v'))
")

if [ -z "${LATEST}" ]; then
    echo "ERROR: Could not determine latest version" >&2
    exit 1
fi

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "rustdesk: ${CURRENT} — already up to date"
    exit 0
fi

echo "rustdesk: ${CURRENT} → ${LATEST}"

DEB_URL="https://github.com/rustdesk/rustdesk/releases/download/${LATEST}/rustdesk-${LATEST}-x86_64.deb"
echo "URL: ${DEB_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${DEB_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify internal layout hasn't changed."