#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
CURRENT_TAG=$(grep '^_tag=' "${TEMPLATE}" | cut -d= -f2 || true)
echo "Current version: ${CURRENT}"

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

echo "Fetching latest librepods release..."
INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/kavishdevar/librepods/releases/latest") || {
    echo "ERROR: failed to fetch GitHub API" >&2
    exit 1
}

TAG=$(echo "${INFO}" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
UPSTREAM_TAG="${TAG#v}"

PKG_VERSION="${UPSTREAM_TAG//-/.}"

echo "Upstream tag: ${UPSTREAM_TAG}"
echo "Package version: ${PKG_VERSION}"

if [[ -z ${PKG_VERSION} ]]; then
    echo "ERROR: could not parse version from tag '${TAG}'" >&2
    exit 1
fi

if [[ ${PKG_VERSION} == "${CURRENT}" ]]; then
    echo "librepods: ${CURRENT} — already up to date"
    exit 0
fi

echo "librepods: ${CURRENT} → ${PKG_VERSION}"

URL="https://github.com/kavishdevar/librepods/archive/refs/tags/v${UPSTREAM_TAG}.tar.gz"
echo "URL: ${URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -fsSL --retry 3 --retry-delay 2 "${URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${PKG_VERSION}/" "${TEMPLATE}"

if grep -q '^_tag=' "${TEMPLATE}"; then
    sed -i "s|^_tag=.*|_tag=${UPSTREAM_TAG}|" "${TEMPLATE}"
else
    sed -i "/^version=/a _tag=${UPSTREAM_TAG}" "${TEMPLATE}"
fi

sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${PKG_VERSION} (${CHECKSUM:0:16}...)"