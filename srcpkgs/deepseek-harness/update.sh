#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

read_assignment() {
    local key=$1
    awk -F= -v key="${key}" '
        $1 == key {
            value = substr($0, index($0, "=") + 1)
            gsub(/^[[:space:]"\047]+|[[:space:]"\047]+$/, "", value)
            print value
            exit
        }
    ' "${TEMPLATE}"
}

current_version=$(read_assignment version)
current_revision=$(read_assignment revision)

echo "Current version: ${current_version} (revision ${current_revision})"

echo "Fetching latest tag from GitHub..."
API="https://api.github.com/repos/deepseek-ai/deepseek-harness/releases"
JSON=$(curl -fsSL --retry 3 --retry-delay 2 \
    -H 'Accept: application/vnd.github+json' "${API}")

latest_tag=$(echo "${JSON}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for rel in data:
    tag = rel.get('tag_name', '')
    if tag.startswith('dsh-v'):
        print(tag)
        break
")

[[ -n ${latest_tag} ]] || { echo "ERROR: no dsh-v* tag found" >&2; exit 1; }

tag_version=${latest_tag#dsh-v}
latest_version=${tag_version//-/.}

echo "Latest tag: ${latest_tag}"
echo "Latest version: ${latest_version}"

if [[ ${latest_version} == "${current_version}" ]]; then
    echo "deepseek-harness is current: ${current_version}"
    exit 0
fi

echo "deepseek-harness: ${current_version} → ${latest_version}"

SOURCE_URL="https://github.com/deepseek-ai/deepseek-harness/archive/refs/tags/${latest_tag}.tar.gz"
echo "Source URL: ${SOURCE_URL}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

echo "Downloading source tarball..."
curl -fL --retry 3 --retry-delay 2 -o "${TMPDIR}/source.tar.gz" "${SOURCE_URL}"
CHECKSUM=$(sha256sum "${TMPDIR}/source.tar.gz" | cut -d' ' -f1)
[[ ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: invalid checksum" >&2; exit 1; }

echo "Extracting to read electron version..."
mkdir -p "${TMPDIR}/extract"
tar -xzf "${TMPDIR}/source.tar.gz" -C "${TMPDIR}/extract"
workdir=$(find "${TMPDIR}/extract" -maxdepth 1 -mindepth 1 -type d | head -1)

electron_spec=$(grep -oE '"electron"[[:space:]]*:[[:space:]]*"\^?[0-9]+\.[0-9]+\.[0-9]+"' \
    "${workdir}/apps/desktop/package.json" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

[[ -n ${electron_spec} ]] || { echo "ERROR: could not detect electron version" >&2; exit 1; }
echo "Electron version: ${electron_spec}"

ELECTRON_URL="https://github.com/electron/electron/releases/download/v${electron_spec}/electron-v${electron_spec}-linux-x64.zip"
SHASUMS_URL="https://github.com/electron/electron/releases/download/v${electron_spec}/SHASUMS256.txt"
echo "Electron URL: ${ELECTRON_URL}"

echo "Downloading electron..."
curl -fL --retry 3 --retry-delay 2 -o "${TMPDIR}/electron.zip" "${ELECTRON_URL}"
echo "Downloading SHASUMS256.txt..."
curl -fL --retry 3 --retry-delay 2 -o "${TMPDIR}/SHASUMS256.txt" "${SHASUMS_URL}"

SRCDIR="${XBPS_DISTDIR:-$(dirname "$0")/../../hostdir}/sources/${pkgname:-deepseek-harness}-${latest_version}"
mkdir -p "${SRCDIR}"
cp "${TMPDIR}/source.tar.gz" "${SRCDIR}/${latest_tag}.tar.gz"
cp "${TMPDIR}/electron.zip" "${SRCDIR}/electron-v${electron_spec}-linux-x64.zip"
cp "${TMPDIR}/SHASUMS256.txt" "${SRCDIR}/SHASUMS256.txt"

echo "Files stored in ${SRCDIR}:"
ls -la "${SRCDIR}"

sed -i "s/^version=.*/version=${latest_version}/" "${TEMPLATE}"
sed -i "s|^distfiles=.*|distfiles=\"${SOURCE_URL}\"|" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${current_version} -> ${latest_version}"
echo "Checksum: ${CHECKSUM}"
echo "Electron: ${electron_spec}"
echo ""
echo "NOTE: if upstream bumped electron major version, update hardcoded value"
echo "      in do_build's CACHE_ROOT hash calculation (currently v44.7.0)"