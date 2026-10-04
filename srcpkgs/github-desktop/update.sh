#!/bin/bash
# Auto-updater for github-desktop (shiftkey fork)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template file not found" >&2
    exit 1
fi

CURRENT=$(grep '^version=' "$TEMPLATE" | cut -d= -f2)
echo "Current version: $CURRENT"
echo "Fetching latest GitHub Desktop (shiftkey) version..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/shiftkey/desktop/releases/latest") || {
    echo "ERROR: Failed to fetch GitHub API" >&2
    exit 1
}

# Извлекаем tag_name, например "release-3.4.13-linux1"
TAG=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['tag_name'])
" 2>/dev/null) || {
    echo "ERROR: Could not parse tag" >&2
    exit 1
}

# Извлекаем версию и номер линукс-билда из тега
# Ожидаемый формат: release-<version>-linux<N>
if [[ "$TAG" =~ ^release-([0-9.]+)-linux([0-9]+)$ ]]; then
    VERSION="${BASH_REMATCH[1]}"
    LINUX_BUILD="${BASH_REMATCH[2]}"
else
    echo "ERROR: Unexpected tag format: $TAG" >&2
    exit 1
fi

if [ -z "$VERSION" ]; then
    echo "ERROR: Empty version" >&2
    exit 1
fi

if [ "$CURRENT" = "$VERSION" ]; then
    echo "github-desktop: $CURRENT — already up to date"
    exit 0
fi

echo "github-desktop: $CURRENT → $VERSION (linux build $LINUX_BUILD)"

# Формируем URL deb-пакета
DEB_URL="https://github.com/shiftkey/desktop/releases/download/${TAG}/GitHubDesktop-linux-amd64-${VERSION}-linux${LINUX_BUILD}.deb"
echo "URL: $DEB_URL"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "$DEB_URL" | sha256sum | cut -d' ' -f1)

# Проверка корректности контрольной суммы
if [[ ! "$CHECKSUM" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: Downloaded file is invalid or checksum not obtained" >&2
    exit 1
fi

# Обновляем template
sed -i "s/^version=.*/version=${VERSION}/" "$TEMPLATE"
# Заменяем distfiles: важно обновить и номер линукс-билда
sed -i "s|^distfiles=.*|distfiles=\"https://github.com/shiftkey/desktop/releases/download/release-\${version}-linux${LINUX_BUILD}/GitHubDesktop-linux-amd64-\${version}-linux${LINUX_BUILD}.deb\"|" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "$TEMPLATE"
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"

echo "Done: $VERSION (${CHECKSUM:0:16}...)"
echo "WARNING: Verify internal layout hasn't changed."