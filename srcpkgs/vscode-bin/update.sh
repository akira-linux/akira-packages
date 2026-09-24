#!/bin/bash
# Auto-updater for vscode-bin
# Uses GitHub releases – always the latest stable tag
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest VSCode version from GitHub..."

API_URL="https://api.github.com/repos/microsoft/vscode/releases/latest"
LATEST=$(curl -fsSL "$API_URL" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['tag_name'])   # тег всегда имеет вид '1.128.0'
")

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "vscode-bin: ${CURRENT} — already up to date"
    exit 0
fi

echo "vscode-bin: ${CURRENT} → ${LATEST}"

DOWNLOAD_URL="https://update.code.visualstudio.com/${LATEST}/linux-x64/stable"
echo "Computing checksum (downloading ~100MB)..."
CHECKSUM=$(curl -fsSL "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"