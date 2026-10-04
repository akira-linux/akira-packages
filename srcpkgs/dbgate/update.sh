#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

API_URL="https://api.github.com/repos/dbgate/dbgate/releases/latest"
LATEST_TAG=$(curl -sL "$API_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")

if [ "${CURRENT}" = "${LATEST_TAG#v}" ]; then
    echo "dbgate: ${CURRENT} — already up to date"
    exit 0
fi

echo "dbgate: ${CURRENT} → ${LATEST_TAG#v}"

DEB_URL="https://github.com/dbgate/dbgate/releases/download/${LATEST_TAG}/dbgate-${LATEST_TAG#v}-linux_amd64.deb"
echo "URL: ${DEB_URL}"

if ! curl --head --silent --fail "${DEB_URL}" > /dev/null; then
    echo "ERROR: Deb package not found at ${DEB_URL}" >&2
    exit 1
fi

CHECKSUM=$(curl -L -# "${DEB_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST_TAG#v}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST_TAG#v} (${CHECKSUM:0:16}...)"