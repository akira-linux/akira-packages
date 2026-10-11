#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
CURRENT_BUILD=$(grep '^_build=' "${TEMPLATE}" | cut -d= -f2 2>/dev/null || echo "")
echo "Current version: ${CURRENT}${CURRENT_BUILD:+ (build ${CURRENT_BUILD})}"

echo "Fetching Zoom download API..."
INFO=$(curl -fsSL --max-time 20 -A "Mozilla/5.0 (X11; Linux x86_64)" \
    -H "Accept: application/json" \
    "https://zoom.us/rest/download?os=linux") || {
    echo "ERROR: failed to fetch Zoom API" >&2
    exit 1
}

VERSION_BUILD=$(echo "${INFO}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ver = d.get('result', {}).get('downloadVO', {}).get('zoom', {}).get('version', '')
print(ver)
")

if [[ -z ${VERSION_BUILD} ]]; then
    echo "ERROR: could not parse version from API response" >&2
    echo "${INFO}" | head -30 >&2
    exit 1
fi

LATEST="${VERSION_BUILD%.*}"
BUILD="${VERSION_BUILD##*.}"

echo "Latest version: ${LATEST} (build ${BUILD})"

if [[ "${LATEST}" == "${CURRENT}" ]] && [[ "${BUILD}" == "${CURRENT_BUILD:-$BUILD}" ]]; then
    echo "zoom: ${CURRENT} — already up to date"
    exit 0
fi

echo "zoom: ${CURRENT} → ${LATEST} (build ${BUILD})"

URL="https://cdn.zoom.us/prod/${LATEST}.${BUILD}/zoom_x86_64.pkg.tar.xz"
echo "URL: ${URL}"

echo "Checking availability..."
if ! curl -fsI --max-time 30 -A "Mozilla/5.0" "${URL}" >/dev/null 2>&1; then
    echo "ERROR: ${URL} is not reachable" >&2
    exit 1
fi

echo "Downloading and computing checksum..."
CHECKSUM=$(curl -fsSL --retry 3 --retry-delay 2 --max-time 600 -A "Mozilla/5.0" "${URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"

if grep -q '^_build=' "${TEMPLATE}"; then
    sed -i "s/^_build=.*/_build=${BUILD}/" "${TEMPLATE}"
else
    sed -i "/^version=/a _build=${BUILD}" "${TEMPLATE}"
fi

sed -i "s|^distfiles=.*|distfiles=\"https://cdn.zoom.us/prod/\${version}.\${_build}/zoom_x86_64.pkg.tar.xz\"|" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST}.${BUILD} (${CHECKSUM:0:16}...)"