#!/bin/bash
# Auto-updater for musescore-bin
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template file not found" >&2
    exit 1
fi

CURRENT=$(grep '^version=' "$TEMPLATE" | cut -d= -f2)
echo "Current version: $CURRENT"
echo "Fetching latest MuseScore release..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/musescore/MuseScore/releases/latest") || {
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

ASSET_NAME=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d.get('assets', []):
    name = a['name']
    if 'MuseScore-Studio' in name and name.endswith('-x86_64.AppImage'):
        print(name)
        break
" 2>/dev/null) || {
    echo "ERROR: No AppImage asset found" >&2
    exit 1
}

if [ -z "$ASSET_NAME" ]; then
    echo "ERROR: Could not find AppImage asset" >&2
    exit 1
fi

echo "Asset: $ASSET_NAME"

FULL_VERSION=$(echo "$ASSET_NAME" | sed -n 's/^MuseScore-Studio-\(.*\)-x86_64\.AppImage$/\1/p')
if [ -z "$FULL_VERSION" ]; then
    echo "ERROR: Could not extract version from asset name" >&2
    exit 1
fi

echo "Full version: $FULL_VERSION"

if [ "$CURRENT" = "$FULL_VERSION" ]; then
    echo "musescore-bin: $CURRENT — already up to date"
    exit 0
fi

echo "musescore-bin: $CURRENT → $FULL_VERSION"

DOWNLOAD_URL=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d.get('assets', []):
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


sed -i "s/^version=.*/version=${FULL_VERSION}/" "$TEMPLATE"
sed -i "s|^distfiles=.*|distfiles=\"https://github.com/musescore/MuseScore/releases/download/${TAG}/MuseScore-Studio-${FULL_VERSION}-x86_64.AppImage\"|" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "$TEMPLATE"
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"

echo "Done: $FULL_VERSION (${CHECKSUM:0:16}...)"
echo "WARNING: Verify the internal AppImage structure hasn't changed."