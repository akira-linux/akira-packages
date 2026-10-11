#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

BASE="https://desktop.app.music.yandex.net/stable"

LATEST=""

echo "Trying electron-updater manifests..."
for MANIFEST in "latest-linux.yml" "latest.yml" "latest-linux.yaml"; do
    CONTENT=$(curl -fsSL --max-time 20 "${BASE}/${MANIFEST}" 2>/dev/null || true)
    if [[ -n ${CONTENT} ]]; then
        V=$(echo "${CONTENT}" | grep -E "^version:" | head -1 | sed 's/version:[[:space:]]*//; s/"//g' | xargs)
        if [[ -n ${V} ]]; then
            LATEST="${V}"
            echo "Found via ${MANIFEST}: ${LATEST}"
            break
        fi
    fi
done

if [[ -z ${LATEST} ]]; then
    echo "Trying to detect from download page..."
    PAGE=$(curl -fsSL --max-time 20 -A "Mozilla/5.0" \
        "https://music.yandex.ru/download/" 2>/dev/null || true)
    LATEST=$(echo "${PAGE}" | \
        grep -oE 'Yandex_Music_amd64_[0-9]+\.[0-9]+\.[0-9]+\.deb' | \
        head -1 | sed 's/^Yandex_Music_amd64_//; s/\.deb$//')
fi

if [[ -z ${LATEST} ]]; then
    echo "ERROR: could not detect latest version." >&2
    echo "Check https://music.yandex.ru/download/ manually." >&2
    exit 1
fi

echo "Latest version: ${LATEST}"

if [[ ${LATEST} == "${CURRENT}" ]]; then
    echo "yandex-music: ${CURRENT} — already up to date"
    exit 0
fi

echo "yandex-music: ${CURRENT} → ${LATEST}"

URL="${BASE}/Yandex_Music_amd64_${LATEST}.deb"
echo "URL: ${URL}"

echo "Checking availability..."
if ! curl -fsI --max-time 30 "${URL}" >/dev/null 2>&1; then
    echo "ERROR: ${URL} is not reachable" >&2
    exit 1
fi

echo "Downloading and computing checksum..."
CHECKSUM=$(curl -fsSL --retry 3 --retry-delay 2 --max-time 600 "${URL}" | sha256sum | cut -d' ' -f1)

if [[ ! ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: invalid checksum" >&2
    exit 1
fi

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=\"${CHECKSUM}\"/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"