#!/bin/bash
# Auto-updater for albion-online-launcher
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

MANIFEST_URL="https://live.albiononline.com/autoupdate/manifest.xml"
echo "Fetching manifest: ${MANIFEST_URL}"

MANIFEST=$(curl -fsSL -A "Mozilla/5.0 (X11; Linux x86_64)" "${MANIFEST_URL}") || {
    echo "ERROR: failed to fetch manifest" >&2
    exit 1
}

INFO=$(echo "${MANIFEST}" | python3 -c "
import sys, xml.etree.ElementTree as ET
root = ET.fromstring(sys.stdin.read())
node = root.find('installer/linux/fullinstall')
if node is None:
    sys.exit('ERROR: linux/fullinstall not found in manifest')
print(node.attrib.get('version', ''))
print(node.attrib.get('file', ''))
")

NEW_VERSION=$(echo "${INFO}" | sed -n '1p')
NEW_FILE=$(echo "${INFO}" | sed -n '2p')

if [[ -z ${NEW_VERSION} || -z ${NEW_FILE} ]]; then
    echo "ERROR: could not parse manifest" >&2
    exit 1
fi

normalize_version() {
    local v="$1"
    IFS='.' read -ra parts <<< "$v"
    local out=""
    local first=1
    for p in "${parts[@]}"; do
        p=$(echo "$p" | sed 's/^0*//')
        [ -z "$p" ] && p=0
        if [ $first -eq 1 ]; then
            out="$p"
            first=0
        else
            out="$out.$p"
        fi
    done
    echo "$out"
}

NEW_VERSION=$(normalize_version "${NEW_VERSION}")
CURRENT=$(normalize_version "${CURRENT}")

echo "Latest version: ${NEW_VERSION}"

if [[ ${NEW_VERSION} == "${CURRENT}" ]]; then
    echo "albion-online-launcher: ${CURRENT} — already up to date"
    exit 0
fi

echo "albion-online-launcher: ${CURRENT} → ${NEW_VERSION}"

NEW_URL="https://live.albiononline.com/autoupdate/${NEW_FILE}"
echo "URL: ${NEW_URL}"

TMPFILE=$(mktemp)
trap 'rm -f "${TMPFILE}"' EXIT
echo "Downloading installer..."
curl -fsSL -A "Mozilla/5.0 (X11; Linux x86_64)" "${NEW_URL}" -o "${TMPFILE}"
CHECKSUM=$(sha256sum "${TMPFILE}" | cut -d' ' -f1)
[[ ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]] || {
    echo "ERROR: invalid checksum" >&2
    exit 1
}

sed -i "s/^version=.*/version=${NEW_VERSION}/" "${TEMPLATE}"
sed -i "s|^distfiles=.*|distfiles=\"${NEW_URL}\"|" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${NEW_VERSION} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify that the archive layout hasn't changed."