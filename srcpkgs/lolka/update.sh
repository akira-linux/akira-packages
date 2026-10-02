#!/bin/bash
set -uo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

BASE="https://storage.yandexcloud.net/lolka-electron"

echo "Fetching update manifest..."
LATEST=""

for URL in \
    "${BASE}/latest-linux.yml" \
    "${BASE}/releases/latest-linux.yml" \
    "${BASE}/releases/latest.yml"
do
    MANIFEST=$(curl -fsSL --max-time 15 "${URL}" 2>/dev/null || true)
    if [[ -n ${MANIFEST} ]]; then
        LATEST=$(echo "${MANIFEST}" | grep -E "^version:" | head -1 | sed 's/version:[[:space:]]*//; s/"//g' | xargs)
        if [[ -n ${LATEST} ]]; then
            echo "Found manifest: ${URL}"
            break
        fi
    fi
done

if [[ -z ${LATEST} ]]; then
    echo "ERROR: could not auto-detect version from electron-updater manifest." >&2
    echo "Please update manually:" >&2
    echo "  1. Check https://lolka.app for the latest version" >&2
    echo "  2. Update 'version' and 'checksum' in srcpkgs/lolka/template" >&2
    exit 1
fi

echo "Latest version: ${LATEST}"

if [[ ${LATEST} == "${CURRENT}" ]]; then
    echo "lolka: ${CURRENT} — already up to date"
    exit 0
fi

echo "lolka: ${CURRENT} → ${LATEST}"

DEB_URL="${BASE}/releases/Lolka_${LATEST}_amd64.deb"
echo "URL: ${DEB_URL}"

echo "Checking availability..."
if ! curl -fsI --max-time 15 "${DEB_URL}" >/dev/null 2>&1; then
    echo "ERROR: ${DEB_URL} is not reachable" >&2
    exit 1
fi

echo "Downloading and computing checksum..."
CHECKSUM=$(curl -fsSL --max-time 300 "${DEB_URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify that the .deb layout hasn't changed."