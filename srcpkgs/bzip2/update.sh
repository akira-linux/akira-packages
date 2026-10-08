#!/bin/bash
# Auto-updater for bzip2 (fetches latest version from sourceware.org)
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

echo "Fetching latest version from sourceware.org..."
SITE="https://sourceware.org/pub/bzip2/"
LISTING=$(curl -fsSL --retry 3 --retry-delay 2 "${SITE}")

latest_version=$(echo "${LISTING}" \
    | grep -oE 'bzip2-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' \
    | sed -E 's/bzip2-(.*)\.tar\.gz/\1/' \
    | sort -V | tail -1)

[[ ${latest_version} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "ERROR: invalid version from sourceware.org: ${latest_version}" >&2
    exit 1
}

echo "Latest version: ${latest_version}"

if [[ ${latest_version} == "${current_version}" ]]; then
    echo "bzip2 is current: ${current_version}"
    exit 0
fi

echo "bzip2: ${current_version} → ${latest_version}"

DOWNLOAD_URL="${SITE}bzip2-${latest_version}.tar.gz"
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