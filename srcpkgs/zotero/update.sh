#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

REDIRECT_URL="https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64"
echo "Resolving latest release via redirect..."

APP_URL=$(curl -fsSIL -A "Mozilla/5.0 (X11; Linux x86_64)" \
    --max-time 30 -o /dev/null -w "%{url_effective}" "${REDIRECT_URL}" 2>/dev/null || true)

if [[ -z ${APP_URL} ]] || [[ ${APP_URL} != *Zotero-*_linux-x86_64.tar.xz ]]; then
    echo "ERROR: could not resolve download URL." >&2
    echo "Final URL: ${APP_URL}" >&2
    exit 1
fi

echo "Resolved URL: ${APP_URL}"

LATEST=$(echo "${APP_URL}" | \
    grep -oE 'Zotero-[0-9]+\.[0-9]+(\.[0-9]+)*_linux-x86_64\.tar\.xz' | \
    head -1 | sed 's/^Zotero-//; s/_linux-x86_64\.tar\.xz$//')

if [[ -z ${LATEST} ]]; then
    echo "ERROR: could not parse version from URL" >&2
    exit 1
fi

echo "Latest version: ${LATEST}"

if [[ ${LATEST} == "${CURRENT}" ]]; then
    echo "zotero: ${CURRENT} — already up to date"
    exit 0
fi

echo "zotero: ${CURRENT} → ${LATEST}"

echo "Downloading and computing checksum..."
CHECKSUM=$(curl -fsSL -A "Mozilla/5.0 (X11; Linux x86_64)" \
    --retry 3 --retry-delay 2 --max-time 600 "${APP_URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"