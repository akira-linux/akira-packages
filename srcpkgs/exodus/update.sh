#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

echo "Fetching version from AUR..."
AUR_JSON=$(curl -fsSL --max-time 20 \
    "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=exodus") || {
    echo "ERROR: failed to fetch AUR API" >&2
    exit 1
}

LATEST=$(echo "${AUR_JSON}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('resultcount', 0) == 0:
    sys.exit('ERROR: package not found in AUR')
ver = d['results'][0]['Version']
print(ver.rsplit('-', 1)[0])
")

if [[ -z ${LATEST} ]]; then
    echo "ERROR: could not parse version from AUR response" >&2
    exit 1
fi

echo "Latest version: ${LATEST}"

if [[ ${LATEST} == "${CURRENT}" ]]; then
    echo "exodus: ${CURRENT} — already up to date"
    exit 0
fi

echo "exodus: ${CURRENT} → ${LATEST}"

URL="https://downloads.exodus.com/releases/exodus-linux-x64-${LATEST}.zip"
echo "URL: ${URL}"

echo "Checking availability..."
if ! curl -fsI --max-time 30 "${URL}" >/dev/null 2>&1; then
    echo "ERROR: ${URL} is not reachable" >&2
    exit 1
fi

echo "Downloading and computing checksum..."
CHECKSUM=$(curl -fsSL --retry 3 --retry-delay 2 "${URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify that the ZIP layout hasn't changed."