#!/bin/bash
# Auto-updater for heroic
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"

if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template file not found at $TEMPLATE" >&2
    exit 1
fi

CURRENT=$(grep -m1 '^version=' "$TEMPLATE" | cut -d= -f2) || {
    echo "ERROR: Could not read version from template" >&2
    exit 1
}

echo "Current version: $CURRENT"
echo "Fetching latest Heroic Games Launcher version..."

CURL_ARGS=(-fsSL -H "Accept: application/vnd.github+json")
[ -n "${GITHUB_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

INFO=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest") || {
    echo "ERROR: Failed to fetch releases" >&2
    exit 1
}

LATEST=$(echo "$INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['tag_name'].lstrip('v'))
" 2>/dev/null) || {
    echo "ERROR: Could not parse latest version" >&2
    exit 1
}

if [ -z "$LATEST" ]; then
    echo "ERROR: No version found" >&2
    exit 1
fi

if [ "$CURRENT" = "$LATEST" ]; then
    echo "heroic: $CURRENT — already up to date"
    exit 0
fi

echo "heroic: $CURRENT → $LATEST"

DEB_URL="https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/v${LATEST}/Heroic-${LATEST}-linux-amd64.deb"
echo "URL: $DEB_URL"
echo "Computing checksum..."
CHECKSUM=$(curl -L -# "$DEB_URL" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "$TEMPLATE"
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"

echo "Done: $LATEST (${CHECKSUM:0:16}...)"
echo "WARNING: Verify internal layout hasn't changed."