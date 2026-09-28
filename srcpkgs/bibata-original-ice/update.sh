#!/bin/bash
# Auto-updater for bibata-original-ice
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

echo "Fetching latest Bibata release..."
INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest") || {
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
    echo "bibata-original-ice: ${CURRENT} — already up to date"
    exit 0
fi

echo "bibata-original-ice: ${CURRENT} → ${VERSION}"

ASSET_NAME="Bibata-Original-Ice.tar.xz"
HAS_ASSET=$(echo "${INFO}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assets = d.get('assets', [])
print('yes' if any(a['name'] == '${ASSET_NAME}' for a in assets) else 'no')
")

if [[ ${HAS_ASSET} != "yes" ]]; then
    echo "No ${ASSET_NAME} in release ${TAG}. Skipping." >&2
    exit 1
fi

DOWNLOAD_URL=$(echo "${INFO}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d['assets']:
    if a['name'] == '${ASSET_NAME}':
        print(a['browser_download_url'])
        break
")

echo "URL: ${DOWNLOAD_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -fsSL "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${VERSION}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${VERSION} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify that the archive layout hasn't changed."