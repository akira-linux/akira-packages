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
API="https://api.github.com/repos/Faugus/faugus-launcher/releases/latest"
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
	echo "faugus-launcher is current: ${current_version}"
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

echo "faugus-launcher: ${current_version} → ${latest_version}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

SOURCE_URL="https://github.com/Faugus/faugus-launcher/archive/refs/tags/${latest_version}.tar.gz"
echo "Downloading: ${SOURCE_URL}"
curl -fL --retry 3 --retry-delay 2 -o "${TMPDIR}/${latest_version}.tar.gz" "${SOURCE_URL}"

SOURCE_SHA=$(sha256sum "${TMPDIR}/${latest_version}.tar.gz" | cut -d' ' -f1)
[[ ${SOURCE_SHA} =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: bad checksum" >&2; exit 1; }

echo "Extracting for structure verification..."
mkdir -p "${TMPDIR}/extract"
tar -xzf "${TMPDIR}/${latest_version}.tar.gz" -C "${TMPDIR}/extract"
workdir=$(find "${TMPDIR}/extract" -maxdepth 1 -mindepth 1 -type d | head -1)
[[ -d ${workdir} ]] || { echo "ERROR: extraction failed" >&2; exit 1; }

echo ""
echo "=== Structure verification ==="

fail=0

if [ -f "${workdir}/meson.build" ]; then
	echo "OK: meson.build found"
	# Проверяем, не сменился ли язык или проект
	if grep -q "project('faugus-launcher'" "${workdir}/meson.build" || grep -q 'project("faugus-launcher"' "${workdir}/meson.build"; then
		echo "OK: project name is 'faugus-launcher'"
	else
		echo "WARNING: project name might have changed in meson.build"
		fail=1
	fi
else
	echo "ERROR: meson.build missing! Build style might have changed."
	exit 1
fi

if [ -d "${workdir}/faugus" ]; then
	echo "OK: 'faugus' python module directory found"
else
	echo "WARNING: 'faugus' python directory missing (renamed?)"
	fail=1
fi

if [ -d "${workdir}/data" ] && [ -f "${workdir}/data/io.github.Faugus.faugus-launcher.desktop" ]; then
	echo "OK: upstream .desktop file found"
else
	echo "WARNING: upstream .desktop file missing or renamed in data/"
	fail=1
fi

if [ -d "${workdir}/languages" ]; then
	echo "OK: 'languages' directory found (gettext still needed)"
else
	echo "WARNING: 'languages' directory missing. You might not need 'gettext' in hostmakedepends"
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
	echo "WARNING: structure changed — review template (do_install / depends) before building"
	exit 2
fi

echo "Verify with:"
echo "  cd ~/akira-packages"
echo "  rm -rf hostdir/builddir/x86_64*/faugus-launcher-*"
echo "  ./xbps-src pkg faugus-launcher"