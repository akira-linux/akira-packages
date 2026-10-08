#!/bin/bash
# Auto-updater for libunistring (fetches latest version from GNU ftp)
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

echo "Fetching latest version from GNU ftp..."
SITE="https://ftp.gnu.org/gnu/libunistring/"
LISTING=$(curl -fsSL --retry 3 --retry-delay 2 "${SITE}")

latest_version=$(echo "${LISTING}" \
    | grep -oE 'libunistring-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.xz' \
    | sed -E 's/libunistring-(.*)\.tar\.xz/\1/' \
    | sort -V | tail -1)

[[ ${latest_version} =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || {
    echo "ERROR: invalid version from GNU ftp: ${latest_version}" >&2
    exit 1
}

echo "Latest version: ${latest_version}"

if [[ ${latest_version} == "${current_version}" ]]; then
    echo "libunistring is current: ${current_version}"
    exit 0
fi

echo "libunistring: ${current_version} → ${latest_version}"
DOWNLOAD_URL="${SITE}libunistring-${latest_version}.tar.xz"
echo "URL: ${DOWNLOAD_URL}"

TMPFILE=$(mktemp)
trap 'rm -f "${TMPFILE}"' EXIT
echo "Downloading..."
curl -fL --retry 3 --retry-delay 2 -o "${TMPFILE}" "${DOWNLOAD_URL}"
CHECKSUM=$(sha256sum "${TMPFILE}" | cut -d' ' -f1)
[[ ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: invalid checksum" >&2; exit 1; }

sed -i "s/^version=.*/version=${latest_version}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${current_version} -> ${latest_version}"
echo "Checksum: ${CHECKSUM}"
echo "Remember to verify that the archive layout hasn't changed."