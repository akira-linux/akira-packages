#!/bin/bash
# Auto-updater for peazip
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template file not found" >&2
    exit 1
fi

CURRENT=$(grep '^version=' "$TEMPLATE" | cut -d= -f2)
echo "Current version: $CURRENT"
echo "Fetching latest PeaZip version..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/peazip/PeaZip/releases/latest") || {
    echo "ERROR: Failed to fetch GitHub API" >&2
    exit 1
}

LATEST=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
# тег может быть как с 'v', так и без, убираем 'v' если есть
tag = d['tag_name']
if tag.startswith('v'):
    tag = tag[1:]
print(tag)
" 2>/dev/null) || {
    echo "ERROR: Could not parse version" >&2
    exit 1
}

if [ -z "$LATEST" ]; then
    echo "ERROR: No version found" >&2
    exit 1
fi

if [ "$CURRENT" = "$LATEST" ]; then
    echo "peazip: $CURRENT — already up to date"
    exit 0
fi

echo "peazip: $CURRENT → $LATEST"

ARCHIVE_URL="https://github.com/peazip/PeaZip/releases/download/${LATEST}/peazip_portable-${LATEST}.LINUX.Qt6.x86_64.tar.gz"
echo "URL: $ARCHIVE_URL"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "$ARCHIVE_URL" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "$TEMPLATE"
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"

echo "Done: $LATEST (${CHECKSUM:0:16}...)"
echo "WARNING: Verify internal structure hasn't changed."