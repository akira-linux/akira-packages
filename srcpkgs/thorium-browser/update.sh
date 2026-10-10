#!/bin/bash
# Auto-updater for thorium-browser (skip if no .deb asset)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template file not found" >&2
    exit 1
fi

CURRENT=$(grep '^version=' "$TEMPLATE" | cut -d= -f2)
echo "Current version: $CURRENT"
echo "Fetching latest Thorium release..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/Alex313031/thorium/releases/latest") || {
    echo "ERROR: Failed to fetch GitHub API" >&2
    exit 1
}

TAG=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['tag_name'])
" 2>/dev/null) || {
    echo "ERROR: Could not parse tag" >&2
    exit 1
}

echo "Latest tag: $TAG"

# Проверяем наличие assets
HAS_ASSETS=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(len(d.get('assets', [])))
" 2>/dev/null)

if [ "$HAS_ASSETS" -eq 0 ]; then
    echo "No assets in this release. Skipping update."
    exit 0
fi

echo "Available assets:"
echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d.get('assets', []):
    print(a['name'])
" 2>/dev/null

# Выбираем .deb: сначала с _AVX, потом любой другой
ASSET_NAME=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assets = d.get('assets', [])
for a in assets:
    name = a['name']
    if name.endswith('_AVX.deb'):
        print(name)
        break
else:
    for a in assets:
        name = a['name']
        if name.endswith('.deb'):
            print(name)
            break
" 2>/dev/null)

if [ -z "$ASSET_NAME" ]; then
    echo "No .deb asset found in this release. Skipping update."
    exit 0
fi

echo "Selected asset: $ASSET_NAME"

# Извлекаем версию
VERSION=$(echo "$ASSET_NAME" | sed -n 's/^thorium-browser_\(.*\)_AVX\.deb$/\1/p')
if [ -z "$VERSION" ]; then
    VERSION=$(echo "$ASSET_NAME" | sed -n 's/^thorium-browser_\(.*\)_amd64\.deb$/\1/p')
fi
if [ -z "$VERSION" ]; then
    echo "Could not extract version from asset name: $ASSET_NAME. Skipping."
    exit 0
fi

echo "Extracted version: $VERSION"

if [ "$CURRENT" = "$VERSION" ]; then
    echo "thorium-browser: $CURRENT — already up to date"
    exit 0
fi

echo "thorium-browser: $CURRENT → $VERSION"

DOWNLOAD_URL=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d['assets']:
    if a['name'] == '$ASSET_NAME':
        print(a['browser_download_url'])
        break
")
if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: Could not get download URL" >&2
    exit 1
fi

echo "URL: $DOWNLOAD_URL"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "$DOWNLOAD_URL" | sha256sum | cut -d' ' -f1)

if [[ ! "$CHECKSUM" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: Invalid checksum" >&2
    exit 1
fi

# Определяем суффикс
if [[ "$ASSET_NAME" == *_AVX.deb ]]; then
    DEB_SUFFIX="_AVX.deb"
else
    DEB_SUFFIX="_amd64.deb"
fi

sed -i "s/^version=.*/version=${VERSION}/" "$TEMPLATE"
sed -i "s|^distfiles=.*|distfiles=\"https://github.com/Alex313031/thorium/releases/download/${TAG}/thorium-browser_${VERSION}${DEB_SUFFIX}\"|" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "$TEMPLATE"
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"

echo "Done: $VERSION (${CHECKSUM:0:16}...)"
echo "WARNING: Verify internal layout hasn't changed."