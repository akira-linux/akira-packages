#!/bin/bash
# Auto-updater for adw-gtk3-theme
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

echo "Fetching latest adw-gtk3 release..."
INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/lassekongo83/adw-gtk3/releases/latest") || {
    echo "ERROR: failed to fetch GitHub API" >&2
    exit 1
}

TAG=$(echo "${INFO}" | python3 -c "
import sys, json
print(json.load(sys.stdin)['tag_name'])
")
VERSION="${TAG#v}"
echo "Latest version: ${VERSION}"

if [[ -z ${VERSION} ]]; then
    echo "ERROR: could not parse version" >&2
    exit 1
fi

if [[ ${VERSION} == "${CURRENT}" ]]; then
    echo "adw-gtk3-theme: ${CURRENT} — already up to date"
    exit 0
fi

echo "adw-gtk3-theme: ${CURRENT} → ${VERSION}"

# Ищем ассет tarball
ASSET_NAME=$(echo "${INFO}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for a in data.get('assets', []):
    n = a['name']
    if n.endswith('.tar.xz') and 'adw-gtk3' in n:
        print(n)
        break
")

if [[ -z ${ASSET_NAME} ]]; then
    echo "ERROR: no adw-gtk3 tarball asset found in release ${TAG}" >&2
    exit 1
fi
echo "Asset: ${ASSET_NAME}"

DOWNLOAD_URL=$(echo "${INFO}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for a in data['assets']:
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
sed -i "s/^checksum=.*/checksum=\"${CHECKSUM}\"/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${VERSION} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify that the archive layout hasn't changed."