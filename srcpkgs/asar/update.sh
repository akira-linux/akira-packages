#!/bin/bash
# Auto-updater for asar
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

echo "Fetching latest asar release..."
INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/electron/asar/releases/latest") || {
    echo "ERROR: failed to fetch GitHub API" >&2
    exit 1
}

TAG=$(echo "${INFO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
VERSION="${TAG#v}"
echo "Latest version: ${VERSION}"

if [[ -z ${VERSION} ]]; then
    echo "ERROR: could not parse version from tag '${TAG}'" >&2
    exit 1
fi

if [[ ${VERSION} == "${CURRENT}" ]]; then
    echo "asar: ${CURRENT} — already up to date"
    exit 0
fi

echo "asar: ${CURRENT} → ${VERSION}"

URL="https://github.com/electron/asar/archive/refs/tags/v${VERSION}.tar.gz"
echo "URL: ${URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -fsSL "${URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${VERSION}/" "${TEMPLATE}"
sed -i "s|^checksum=.*|checksum=\"${CHECKSUM}\"|" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${VERSION} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify that the archive layout and install paths haven't changed."