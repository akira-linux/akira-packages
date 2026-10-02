#!/bin/bash
# Auto-updater for chatbox (AppImage via GitHub releases)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest Chatbox version from GitHub..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/chatboxai/chatbox/releases/latest")

LATEST=$(echo "${INFO}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['tag_name'].lstrip('v'))
")

if [ -z "${LATEST}" ]; then
    echo "ERROR: Could not determine latest version" >&2
    exit 1
fi

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "chatbox: ${CURRENT} — already up to date"
    exit 0
fi

echo "chatbox: ${CURRENT} → ${LATEST}"

APPIMAGE_URL="https://download.chatboxai.app/releases/Chatbox-${LATEST}-x86_64.AppImage"
echo "URL: ${APPIMAGE_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${APPIMAGE_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify that the AppImage internal structure (binary name, icon paths) hasn't changed."