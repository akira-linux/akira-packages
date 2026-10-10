#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

GITLAB_PROJECT="mission-center-devs%2Fmission-center"
API_URL="https://gitlab.com/api/v4/projects/${GITLAB_PROJECT}/releases?per_page=1"

echo "Fetching latest release from GitLab..."
INFO=$(curl -fsSL --max-time 20 "${API_URL}") || {
    echo "ERROR: failed to fetch GitLab API" >&2
    exit 1
}

TAG=$(echo "${INFO}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['tag_name'])")
LATEST="${TAG#v}"

if [[ -z ${LATEST} ]]; then
    echo "ERROR: could not parse version from tag '${TAG}'" >&2
    exit 1
fi

echo "Latest version: ${LATEST}"

if [[ ${LATEST} == "${CURRENT}" ]]; then
    echo "mission-center: ${CURRENT} — already up to date"
    exit 0
fi

echo "mission-center: ${CURRENT} → ${LATEST}"

DOWNLOAD_URL=$(echo "${INFO}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
release = d[0]
for link in release.get('assets', {}).get('links', []):
    name = link.get('name', '')
    if 'x86_64' in name and 'AppImage' in name:
        print(link.get('direct_asset_url', link.get('url', '')))
        break
")

if [[ -z ${DOWNLOAD_URL} ]]; then
    echo "ERROR: no x86_64 AppImage link found in release ${TAG}" >&2
    exit 1
fi

echo "URL: ${DOWNLOAD_URL}"
echo "Downloading and computing checksum..."
CHECKSUM=$(curl -fsSL --retry 3 --retry-delay 2 --max-time 600 "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s|^distfiles=.*|distfiles=\"${DOWNLOAD_URL}\"|" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"