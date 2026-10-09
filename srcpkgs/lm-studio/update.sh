#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

echo "Resolving latest AppImage URL via redirect..."

REDIRECT_URL="https://lmstudio.ai/download/latest/linux/x64?format=AppImage"
APPIMAGE_URL=$(curl -fsSIL -A "Mozilla/5.0 (X11; Linux x86_64)" \
    --max-time 30 -o /dev/null -w "%{url_effective}" "${REDIRECT_URL}" 2>/dev/null || true)

if [[ -z ${APPIMAGE_URL} ]] || [[ ${APPIMAGE_URL} != *.AppImage ]]; then
    echo "ERROR: could not resolve AppImage URL." >&2
    echo "Final URL: ${APPIMAGE_URL}" >&2
    exit 1
fi

echo "Resolved URL: ${APPIMAGE_URL}"

UPSTREAM=$(basename "${APPIMAGE_URL}" | \
    grep -oE 'LM-Studio-[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?-x64' | \
    head -1 | sed 's/^LM-Studio-//; s/-x64$//')

if [[ -z ${UPSTREAM} ]]; then
    echo "ERROR: could not parse version from URL" >&2
    exit 1
fi

PKG_VERSION="${UPSTREAM//-/.}"

echo "Upstream version: ${UPSTREAM}"
echo "Package version: ${PKG_VERSION}"

if [[ ${PKG_VERSION} == "${CURRENT}" ]]; then
    echo "lm-studio: ${CURRENT} — already up to date"
    exit 0
fi

echo "lm-studio: ${CURRENT} → ${PKG_VERSION}"

echo "Downloading and computing checksum..."
CHECKSUM=$(curl -fsSL -A "Mozilla/5.0 (X11; Linux x86_64)" \
    --retry 3 --retry-delay 2 --max-time 600 "${APPIMAGE_URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${PKG_VERSION}/" "${TEMPLATE}"
if grep -q '^_tag=' "${TEMPLATE}"; then
    sed -i "s|^_tag=.*|_tag=${UPSTREAM}|" "${TEMPLATE}"
else
    sed -i "/^version=/a _tag=${UPSTREAM}" "${TEMPLATE}"
fi
sed -i "s|^distfiles=.*|distfiles=\"${APPIMAGE_URL}\"|" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=\"${CHECKSUM}\"/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${PKG_VERSION} (${CHECKSUM:0:16}...)"