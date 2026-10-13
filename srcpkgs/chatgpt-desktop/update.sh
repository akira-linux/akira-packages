#!/bin/bash
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
[[ -f ${TEMPLATE} ]] || { echo "ERROR: template not found" >&2; exit 1; }

CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
echo "Current version: ${CURRENT}"

DEB_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

echo "Downloading latest chatgpt_amd64.deb..."
curl -fL --retry 3 --retry-delay 2 --max-time 900 \
    --progress-bar \
    -o "${TMPDIR}/chatgpt.deb" "${DEB_URL}"

cd "${TMPDIR}"

echo "Extracting control metadata..."
ar x chatgpt.deb

CONTROL=""
for f in control.tar.zst control.tar.xz control.tar.gz control.tar; do
    [ -f "$f" ] && CONTROL="$f" && break
done

if [[ -z ${CONTROL:-} ]]; then
    echo "ERROR: no control tarball in .deb" >&2
    ls -la >&2
    exit 1
fi

LATEST=$(python3 - "$CONTROL" << 'PYEOF'
import sys, io, lzma, gzip, tarfile

name = sys.argv[1]

try:
    if name.endswith('.xz'):
        data = lzma.open(name, 'rb').read()
    elif name.endswith('.gz'):
        data = gzip.open(name, 'rb').read()
    elif name.endswith('.tar'):
        data = open(name, 'rb').read()
    else:
        sys.exit(1)

    with tarfile.open(fileobj=io.BytesIO(data)) as tf:
        for m in tf.getmembers():
            if m.name in ('./control', 'control'):
                f = tf.extractfile(m)
                if f:
                    text = f.read().decode('utf-8', errors='replace')
                    for line in text.splitlines():
                        if line.startswith('Version:'):
                            print(line.split(':', 1)[1].strip())
                            sys.exit(0)
except Exception as e:
    print(f'failed: {e}', file=sys.stderr)
    sys.exit(1)

sys.exit(1)
PYEOF
)

if [[ -z ${LATEST} ]]; then
    echo "ERROR: could not parse Version from control" >&2
    exit 1
fi

echo "Latest version: ${LATEST}"

if [[ ${LATEST} == "${CURRENT}" ]]; then
    echo "chatgpt-desktop-bin: ${CURRENT} — already up to date"
    exit 0
fi

echo "chatgpt-desktop-bin: ${CURRENT} → ${LATEST}"

CHECKSUM=$(sha256sum chatgpt.deb | cut -d' ' -f1)
[[ ${CHECKSUM} =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: invalid checksum" >&2; exit 1; }

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s|^distfiles=.*|distfiles=\"https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb>chatgpt_\${version}_amd64.deb\"|" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: ${LATEST} (${CHECKSUM:0:16}...)"