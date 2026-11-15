#!/usr/bin/env bash
# Bináris csomagok fordítása egy Debian konténerben (debian:stable vagy debian:testing).
# Használat: build-binary.sh <komponens: stable|testing> <forrás_könyvtár .dsc-vel> <kimeneti_könyvtár>
set -euo pipefail

COMPONENT=$1
SRC_DIR=$(cd "$2" && pwd)
OUT=$(mkdir -p "$3" && cd "$3" && pwd)

# A build-függőségek egy része (pl. x11proto-dev >= 2025.1) Debian stable-ben csak
# backports-ból vagy az xlibre-debian tárolóból érhető el.
EXTRA_REPO_URL=${EXTRA_REPO_URL-https://xlibre-debian.github.io/debian/}
EXTRA_REPO_KEY_URL=${EXTRA_REPO_KEY_URL-https://mrchicken.nexussfan.cz/publickey.asc}

export DEBIAN_FRONTEND=noninteractive
. /etc/os-release
echo ">> $PRETTY_NAME ($VERSION_CODENAME), $(dpkg --print-architecture), komponens: $COMPONENT"

apt-get update -qq
apt-get install -y -qq --no-install-recommends ca-certificates curl gpg >/dev/null

if [[ "$COMPONENT" == "stable" ]]; then
  cat > /etc/apt/sources.list.d/backports.sources <<EOF
Types: deb
URIs: http://deb.debian.org/debian
Suites: ${VERSION_CODENAME}-backports
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
fi

if [[ -n "$EXTRA_REPO_URL" ]]; then
  install -d /usr/share/keyrings
  curl -fsSL "$EXTRA_REPO_KEY_URL" | gpg --dearmor > /usr/share/keyrings/extra-repo.pgp
  cat > /etc/apt/sources.list.d/extra-repo.sources <<EOF
Types: deb
URIs: $EXTRA_REPO_URL
Suites: main
Components: $COMPONENT
Signed-By: /usr/share/keyrings/extra-repo.pgp
EOF
fi

apt-get update -qq
apt-get install -y -qq --no-install-recommends build-essential dpkg-dev devscripts fakeroot >/dev/null

BUILD=$(mktemp -d)
dpkg-source -x "$SRC_DIR"/xlibre-server_*.dsc "$BUILD/src"
cd "$BUILD/src"
apt-get build-dep -y ./

dpkg-buildpackage -b -uc -us -j"$(nproc)"

cd "$BUILD"
cp -v ./*.deb ./*.buildinfo ./*.changes "$OUT/"
ls ./*.udeb >/dev/null 2>&1 && cp -v ./*.udeb "$OUT/" || true
