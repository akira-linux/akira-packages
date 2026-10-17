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
echo "Current version: ${current_version}"

echo "Fetching latest release from GitHub..."
API="https://api.github.com/repos/earendil-works/pi/releases/latest"
JSON=$(curl -fsSL --retry 3 --retry-delay 2 \
	-H 'Accept: application/vnd.github+json' "${API}")

raw_tag=$(echo "${JSON}" | python3 -c "
import sys, json
print(json.load(sys.stdin).get('tag_name', ''))
")

[[ -n ${raw_tag} ]] || { echo "ERROR: no release found" >&2; exit 1; }
latest_version=${raw_tag#v}

[[ ${latest_version} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
	echo "ERROR: invalid version: ${latest_version}" >&2
	exit 1
}

echo "Latest version: ${latest_version}"

if [[ ${latest_version} == "${current_version}" ]]; then
	echo "pi is current: ${current_version}"
	exit 0
fi

echo ""
echo "=== Changelog ==="
echo "${JSON}" | python3 -c "
import sys, json
body = json.load(sys.stdin).get('body', '')
print(body[:1500])
"
echo ""

echo "pi: ${current_version} → ${latest_version}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

ARCHIVE="pi-linux-x64.tar.gz"
SOURCE_URL="https://github.com/earendil-works/pi/releases/download/v${latest_version}/${ARCHIVE}"
echo "Downloading: ${SOURCE_URL}"
curl -fL --retry 3 --retry-delay 2 -o "${TMPDIR}/${ARCHIVE}" "${SOURCE_URL}"

SOURCE_SHA=$(sha256sum "${TMPDIR}/${ARCHIVE}" | cut -d' ' -f1)
[[ ${SOURCE_SHA} =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: bad checksum" >&2; exit 1; }

echo ""
echo "=== Structure verification ==="

fail=0

mkdir -p "${TMPDIR}/extract"
tar -xzf "${TMPDIR}/${ARCHIVE}" -C "${TMPDIR}/extract"
workdir=$(find "${TMPDIR}/extract" -maxdepth 1 -mindepth 1 -type d | head -1)
[[ -d ${workdir} ]] || { echo "ERROR: extraction failed" >&2; exit 1; }

if [ -x "${workdir}/pi" ]; then
	echo "OK: binary 'pi' found in root"
else
	echo "WARNING: binary 'pi' not found at root — check do_install"
	fail=1
fi

if [ -d "${workdir}/docs" ]; then
	echo "OK: 'docs' directory present"
else
	echo "WARNING: 'docs' directory missing — documentation might have moved"
	fail=1
fi

if [ -d "${workdir}/assets" ]; then
	echo "OK: 'assets' directory present"
else
	echo "WARNING: 'assets' directory missing — structure might have changed"
	fail=1
fi

echo ""
echo "=== Updating template ==="
sed -i "s/^version=.*/version=${latest_version}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${SOURCE_SHA}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${current_version} -> ${latest_version}"
echo "Checksum: ${SOURCE_SHA}"
echo ""

if [[ ${fail} -eq 1 ]]; then
	echo "WARNING: structure changed — review do_install before building"
	exit 2
fi

echo "Verify with:"
echo "  cd ~/akira-packages"
echo "  rm -rf hostdir/builddir/x86_64*/pi-*"
echo "  ./xbps-src pkg pi"