#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

INDEX_URL="https://repo.steampowered.com/steam/pool/steam/s/steam/"

echo "Fetching Steam repo index..."
INDEX=$(curl -fsSL --max-time 20 "${INDEX_URL}") || {
    echo "ERROR: failed to fetch Steam repo index" >&2
    exit 1
}

LATEST=$(echo "${INDEX}" | \
    grep -oE 'steam_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' | \
    sed 's/^steam_//; s/\.tar\.gz$//' | \
    sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | \
    tail -1)

if [[ -z ${LATEST} ]]; then
    echo "ERROR: could not parse version from repo index" >&2
    exit 1
fi

echo "Latest version: ${LATEST}"

if [[ ${LATEST} == "${CURRENT}" ]]; then
    echo "steam-bin: ${CURRENT} — already up to date"
    exit 0
fi

echo "steam-bin: ${CURRENT} → ${LATEST}"

URL="https://repo.steampowered.com/steam/pool/steam/s/steam/steam_${LATEST}.tar.gz"
echo "URL: ${URL}"

echo "Downloading and computing checksum..."
CHECKSUM=$(curl -fsSL --retry 3 --retry-delay 2 --max-time 600 "${URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"