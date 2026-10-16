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
API="https://api.github.com/repos/storytold/pdfcraft/releases/latest"
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
	echo "pdfcraft is current: ${current_version}"
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

echo "pdfcraft: ${current_version} → ${latest_version}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

SOURCE_URL="https://github.com/storytold/pdfcraft/archive/refs/tags/v${latest_version}.tar.gz"
echo "Downloading: ${SOURCE_URL}"
curl -fL --retry 3 --retry-delay 2 -o "${TMPDIR}/v${latest_version}.tar.gz" "${SOURCE_URL}"

SOURCE_SHA=$(sha256sum "${TMPDIR}/v${latest_version}.tar.gz" | cut -d' ' -f1)
[[ ${SOURCE_SHA} =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: bad checksum" >&2; exit 1; }

echo "Extracting for structure verification..."
mkdir -p "${TMPDIR}/extract"
tar -xzf "${TMPDIR}/v${latest_version}.tar.gz" -C "${TMPDIR}/extract"
workdir=$(find "${TMPDIR}/extract" -maxdepth 1 -mindepth 1 -type d | head -1)
[[ -d ${workdir} ]] || { echo "ERROR: extraction failed" >&2; exit 1; }

echo ""
echo "=== Structure verification ==="

fail=0

if grep -q 'rust-version' "${workdir}/Cargo.toml"; then
	msrv=$(grep 'rust-version' "${workdir}/Cargo.toml" | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
	installed_rust=$(rustc --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
	echo "MSRV (Cargo.toml): ${msrv}"
	echo "Installed rustc:   ${installed_rust}"
	if [[ ${installed_rust} != "unknown" ]]; then
		lowest=$(printf '%s\n%s\n' "${msrv}" "${installed_rust}" | sort -V | head -1)
		if [[ ${lowest} == "${installed_rust}" && ${msrv} != "${installed_rust}" ]]; then
			echo "WARNING: installed rust (${installed_rust}) is older than MSRV (${msrv})"
			echo "         build may fail"
		fi
	fi
else
	echo "WARNING: rust-version not found in Cargo.toml"
fi

for bin in pdfcraft pdfcraft-cli; do
	if [ -d "${workdir}/apps" ] && grep -rq "name *= *\"${bin}\"" "${workdir}"/apps/*/Cargo.toml 2>/dev/null; then
		echo "OK: binary '${bin}' declared"
	elif grep -rq "name *= *\"${bin}\"" "${workdir}"/crates/*/Cargo.toml 2>/dev/null; then
		echo "OK: binary '${bin}' declared"
	else
		echo "WARNING: binary '${bin}' not found in workspace — check do_install"
		fail=1
	fi
done

if [ -d "${workdir}/assets/app-icon/hicolor" ]; then
	count=$(find "${workdir}/assets/app-icon/hicolor" -name '*.png' -o -name '*.svg' | wc -l)
	echo "OK: icons found (${count} files in assets/app-icon/hicolor)"
else
	echo "WARNING: assets/app-icon/hicolor missing — update do_install"
	fail=1
fi

if [ -f "${workdir}/LICENSE-MIT" ] && [ -f "${workdir}/LICENSE-APACHE" ]; then
	echo "OK: license files present"
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
echo "  rm -rf hostdir/builddir/x86_64*/pdfcraft-*"
echo "  ./xbps-src pkg pdfcraft"