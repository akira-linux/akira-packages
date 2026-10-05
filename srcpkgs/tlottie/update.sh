#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

echo "Fetching latest tlottie tag..."
INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/dkaraush/tlottie/tags") || {
    echo "ERROR: failed to fetch GitHub API" >&2
    exit 1
}

LATEST=$(echo "${INFO}" | python3 -c "
import sys, json
tags = json.load(sys.stdin)
for t in tags:
    name = t['name']
    if name.startswith('v') and name[1:2].isdigit():
        print(name.lstrip('v'))
        break
")

if [[ -z ${LATEST} ]]; then
    echo "ERROR: no versioned tag found in tlottie repo" >&2
    exit 1
fi

echo "Latest version: ${LATEST}"

if [[ ${LATEST} == "${CURRENT}" ]]; then
    echo "tlottie: ${CURRENT} — already up to date"
    exit 0
fi

echo "tlottie: ${CURRENT} → ${LATEST}"

URL="https://github.com/dkaraush/tlottie/archive/refs/tags/v${LATEST}.tar.gz"
echo "URL: ${URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -fsSL --retry 3 --retry-delay 2 "${URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"