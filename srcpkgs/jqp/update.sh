#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

echo "Fetching latest jqp release..."
INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/noahgorstein/jqp/releases/latest") || {
    echo "ERROR: failed to fetch GitHub API" >&2
    exit 1
}

TAG=$(echo "${INFO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
LATEST="${TAG#v}"
echo "Latest version: ${LATEST}"

if [[ -z ${LATEST} ]]; then
    echo "ERROR: could not parse version from tag '${TAG}'" >&2
    exit 1
fi

if [[ ${LATEST} == "${CURRENT}" ]]; then
    echo "jqp: ${CURRENT} — already up to date"
    exit 0
fi

echo "jqp: ${CURRENT} → ${LATEST}"

ASSET_NAME="jqp_Linux_x86_64.tar.gz"
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
CHECKSUM=$(curl -fsSL --retry 3 --retry-delay 2 "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"