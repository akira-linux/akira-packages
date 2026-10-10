#!/bin/bash
# Auto-updater for rar (extracts version from archive link)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest RAR version from rarlab.com..."

# 1. Скачиваем страницу загрузок
PAGE=$(curl -fsSL "https://www.rarlab.com/download.htm") || {
    echo "ERROR: Failed to download page" >&2
    exit 1
}

# 2. Ищем ссылку на Linux x64 архив (например, rarlinux-x64-722.tar.gz)
LINK=$(echo "$PAGE" | grep -oP 'rarlinux-x64-\d+\.tar\.gz' | head -1)

if [ -z "$LINK" ]; then
    echo "ERROR: Could not find Linux x64 archive link" >&2
    exit 1
fi

# 3. Извлекаем версию из имени файла (rarlinux-x64-722.tar.gz → 722)
VERSION_SHORT=$(echo "$LINK" | grep -oP '\d+(?=\.tar\.gz)')

# Преобразуем в формат X.Y (например, 722 → 7.22)
LATEST="${VERSION_SHORT:0:1}.${VERSION_SHORT:1}"

if [ -z "$LATEST" ]; then
    echo "ERROR: Could not parse version from link: $LINK" >&2
    exit 1
fi

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "rar: ${CURRENT} — already up to date"
    exit 0
fi

echo "rar: ${CURRENT} → ${LATEST}"

# 4. Полный URL и контрольная сумма
DOWNLOAD_URL="https://www.rarlab.com/rar/${LINK}"
echo "URL: ${DOWNLOAD_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

# 5. Обновляем template
sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"
echo "WARNING: Verify the archive structure hasn't changed."