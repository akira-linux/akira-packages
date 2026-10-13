#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

PACKAGES_URL="https://download.max.ru/linux/deb/dists/stable/main/binary-amd64/Packages"

echo "Fetching Packages index..."
INDEX=$(curl -fsSL --max-time 30 "${PACKAGES_URL}") || {
    echo "ERROR: failed to fetch Packages" >&2
    exit 1
}

LATEST=$(echo "${INDEX}" | awk '
    /^Package: max$/ { in_pkg=1; next }
    in_pkg && /^Version:/ { print $2; exit }
')

FILENAME=$(echo "${INDEX}" | awk -v ver="${LATEST}" '
    /^Package: max$/ { in_pkg=1; version=""; filename=""; next }
    in_pkg && /^Version:/ { version=$2 }
    in_pkg && /^Filename:/ { filename=$2 }
    in_pkg && version==ver && filename!="" { print filename; exit }
')

if [[ -z ${LATEST} ]] || [[ -z ${FILENAME} ]]; then
    echo "ERROR: could not parse version/filename from index" >&2
    exit 1
fi

echo "Latest version: ${LATEST}"
echo "Filename: ${FILENAME}"

if [[ ${LATEST} == "${CURRENT}" ]]; then
    echo "max-messenger-bin: ${CURRENT} — already up to date"
    exit 0
fi

echo "max-messenger-bin: ${CURRENT} → ${LATEST}"

URL="https://download.max.ru/linux/deb/${FILENAME}"
echo "URL: ${URL}"

echo "Downloading and computing checksum..."
CHECKSUM=$(curl -fsSL --retry 3 --retry-delay 2 --max-time 900 "${URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

# Обновляем version и checksum, distfiles формируем динамически
sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s|^distfiles=.*|distfiles=\"https://download.max.ru/linux/deb/${FILENAME}\"|" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"