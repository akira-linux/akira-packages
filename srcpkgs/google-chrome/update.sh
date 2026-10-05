#!/bin/bash
# Auto-updater for google-chrome (stable) – safe version
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest Google Chrome Stable version..."

REPO_BASE="https://dl.google.com/linux/chrome/rpm/stable/x86_64"
REPOMD_URL="${REPO_BASE}/repodata/repomd.xml"

REPOMD=$(curl -fsSL "$REPOMD_URL") || { echo "ERROR: Failed to download repomd.xml" >&2; exit 1; }

HREF=$(echo "$REPOMD" | python3 -c "
import sys, xml.etree.ElementTree as ET
ns = {'r': 'http://linux.duke.edu/metadata/repo'}
root = ET.fromstring(sys.stdin.read())
for data in root.findall('.//r:data', ns):
    if data.get('type') == 'primary':
        print(data.find('r:location', ns).get('href'))
        break
")
[ -z "$HREF" ] && { echo "ERROR: Could not find primary XML location" >&2; exit 1; }

HREF="${HREF#./}"
PRIMARY_XML_URL="${REPO_BASE}/${HREF}"

TMP_GZ=$(mktemp)
trap 'rm -f "$TMP_GZ"' EXIT
curl -fsSL --output "$TMP_GZ" "$PRIMARY_XML_URL" || { echo "ERROR: Failed to download primary XML" >&2; exit 1; }

PRIMARY_XML=$(gunzip -c "$TMP_GZ") || { echo "ERROR: Failed to unzip primary XML" >&2; exit 1; }

LATEST_VER=$(echo "$PRIMARY_XML" | python3 -c "
import sys, xml.etree.ElementTree as ET
ns = {'r': 'http://linux.duke.edu/metadata/common'}
root = ET.fromstring(sys.stdin.read())
for pkg in root.findall('.//r:package', ns):
    name = pkg.find('r:name', ns).text
    if name == 'google-chrome-stable':
        ver_elem = pkg.find('r:version', ns)
        print(ver_elem.get('ver'))
        break
")
[ -z "$LATEST_VER" ] && { echo "ERROR: Could not find google-chrome-stable" >&2; exit 1; }

# Берём только версию до дефиса (например, 149.0.7827.155-1 → 149.0.7827.155)
VERSION="${LATEST_VER%-*}"

if [ "${CURRENT}" = "${VERSION}" ]; then
    echo "google-chrome: ${CURRENT} — already up to date"
    exit 0
fi

# Всегда используем фиксированный номер ревизии 1
DEB_URL="https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${VERSION}-1_amd64.deb"
echo "URL: ${DEB_URL}"

# Проверяем, что deb-пакет действительно доступен
if ! curl --head --silent --fail "${DEB_URL}" > /dev/null; then
    echo "ERROR: Deb package not found at ${DEB_URL} — maybe not released yet?" >&2
    exit 1
fi

echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${DEB_URL}" | sha256sum | cut -d' ' -f1)

# Обновляем только version и checksum, distfiles не трогаем (там уже правильная строка)
sed -i "s/^version=.*/version=${VERSION}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${VERSION} (${CHECKSUM:0:16}...)"