#!/bin/bash
# Auto-updater for firefox-nightly (official Mozilla versions API)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest Firefox Nightly version from Mozilla API..."

API_URL="https://product-details.mozilla.org/1.0/firefox_versions.json"
VERSIONS=$(curl -fsSL "$API_URL") || {
    echo "ERROR: Failed to fetch versions API" >&2
    exit 1
}

LATEST=$(echo "$VERSIONS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['FIREFOX_NIGHTLY'])
" 2>/dev/null) || {
    echo "ERROR: Could not parse nightly version" >&2
    exit 1
}

if [ -z "${LATEST}" ]; then
    echo "ERROR: No FIREFOX_NIGHTLY found" >&2
    exit 1
fi

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "firefox-nightly: ${CURRENT} — already up to date"
    exit 0
fi

echo "firefox-nightly: ${CURRENT} → ${LATEST}"

DOWNLOAD_URL="https://download.mozilla.org/?product=firefox-nightly-latest&os=linux64&lang=en-US"
echo "Downloading: ${DOWNLOAD_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"