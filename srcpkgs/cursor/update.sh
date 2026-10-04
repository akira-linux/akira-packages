#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

echo "Fetching Cursor download info..."
INFO=$(curl -fsSL "https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable") || {
    echo "ERROR: failed to fetch download info" >&2
    exit 1
}

DL_URL=$(echo "${INFO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['downloadUrl'])")

if [[ -z ${DL_URL} ]]; then
    echo "ERROR: could not parse downloadUrl" >&2
    exit 1
fi

echo "API returned: ${DL_URL}"

HASH=$(echo "${DL_URL}" | sed -n 's|.*/production/\([a-f0-9]\{40\}\)/.*|\1|p')
LATEST=$(echo "${DL_URL}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [[ -z ${HASH} || -z ${LATEST} ]]; then
    echo "ERROR: could not parse hash or version from URL" >&2
    exit 1
fi

echo "Latest version: ${LATEST}"
echo "Hash: ${HASH}"

if [[ ${LATEST} == "${CURRENT}" ]]; then
    echo "cursor: ${CURRENT} — already up to date"
    exit 0
fi

echo "cursor: ${CURRENT} → ${LATEST}"

DEB_URL="https://downloads.cursor.com/production/${HASH}/linux/x64/deb/amd64/deb/cursor_${LATEST}_amd64.deb"
echo "Deb URL: ${DEB_URL}"

echo "Checking availability..."
if ! curl -fsI --max-time 20 "${DEB_URL}" >/dev/null 2>&1; then
    echo "ERROR: ${DEB_URL} is not reachable" >&2
    exit 1
fi

DISTFILES="${DEB_URL}>cursor-${LATEST}-amd64.deb"

echo "Downloading and computing checksum..."
CHECKSUM=$(curl -fsSL --retry 3 --retry-delay 2 "${DEB_URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s|^distfiles=.*|distfiles=\"${DISTFILES}\"|" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"