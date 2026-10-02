#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/vinceliuice/Colloid-icon-theme/tags") || {
    echo "ERROR: failed to fetch GitHub API" >&2
    exit 1
}


TAG=$(echo "${INFO}" | python3 -c "
import sys, json
tags = json.load(sys.stdin)
for t in tags:
    name = t['name']
    if name.count('-') == 2 and name[:4].isdigit():
        print(name)
        break
")

if [[ -z ${TAG} ]]; then
    echo "ERROR: no matching tag found" >&2
    exit 1
fi

VERSION="${TAG//-/.}"
echo "Latest version: ${VERSION}"

if [[ ${VERSION} == "${CURRENT}" ]]; then
    echo "colloid-everforest-icon-theme: ${CURRENT} — already up to date"
    exit 0
fi

echo "colloid-everforest-icon-theme: ${CURRENT} → ${VERSION}"

URL="https://github.com/vinceliuice/Colloid-icon-theme/archive/refs/tags/${TAG}.tar.gz"
echo "URL: ${URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -fsSL "${URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${VERSION}/" "${TEMPLATE}"
sed -i "s|^distfiles=.*|distfiles=\"${URL}\"|" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${VERSION} (${CHECKSUM:0:16}...)"