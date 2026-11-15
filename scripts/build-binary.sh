#!/usr/bin/env bash
# Az összes csomag fordítása egy Debian konténerben (debian:stable vagy debian:testing),
# a packaging/packages.list sorrendjében. Minden kész csomag egy helyi APT tárolóba kerül,
# így a következő csomag már az előzőleg fordított függőségekre épül (pl. a driverek a friss szerverre).
# Használat (a tároló gyökeréből): build-binary.sh <komponens: stable|testing> <forrás_könyvtár> <kimeneti_könyvtár>
set -euo pipefail

COMPONENT=$1
SRC_DIR=$(cd "$2" && pwd)
OUT=$(mkdir -p "$3" && cd "$3" && pwd)
LIST=${PACKAGES_LIST:-packaging/packages.list}
LIST=$(cd "$(dirname "$LIST")" && pwd)/$(basename "$LIST")

export DEBIAN_FRONTEND=noninteractive
. /etc/os-release
echo ">> $PRETTY_NAME ($VERSION_CODENAME), $(dpkg --print-architecture), komponens: $COMPONENT"

if [[ "$COMPONENT" == "stable" ]]; then
  cat > /etc/apt/sources.list.d/backports.sources <<EOF
Types: deb
URIs: http://deb.debian.org/debian
Suites: ${VERSION_CODENAME}-backports
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
fi

LOCAL=/srv/localrepo
mkdir -p "$LOCAL"
: > "$LOCAL/Packages"
cat > /etc/apt/sources.list.d/localrepo.sources <<EOF
Types: deb
URIs: file:$LOCAL
Suites: ./
Trusted: yes
EOF

apt-get update -qq
# x11-xserver-utils: a szerver tesztjei az xrandr-t is futtatják, de ez nincs a Build-Depends-ben.
apt-get install -y -qq --no-install-recommends \
  build-essential dpkg-dev devscripts fakeroot ca-certificates x11-xserver-utils >/dev/null

BUILD=$(mktemp -d)
shopt -s nullglob

while IFS=$'\t' read -r name _; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  dscs=("$SRC_DIR/${name}"_*.dsc)
  (( ${#dscs[@]} == 1 )) || { echo "::error::Nincs (vagy több van) forráscsomag: $name"; exit 1; }

  echo "::group::$name"
  rm -rf "${BUILD:?}"/*
  dpkg-source -x "${dscs[0]}" "$BUILD/src"
  if ! ( cd "$BUILD/src" \
         && apt-get build-dep -y ./ \
         && dpkg-buildpackage -b -uc -us -j"$(nproc)" ); then
    echo "::endgroup::"
    echo "::error::$name fordítása sikertelen ($COMPONENT/$(dpkg --print-architecture))"
    exit 1
  fi
  echo "::endgroup::"

  cp "$BUILD"/*.deb "$LOCAL/"
  mv "$BUILD"/*.deb "$BUILD"/*.buildinfo "$BUILD"/*.changes "$OUT/"
  (cd "$LOCAL" && dpkg-scanpackages -m . > Packages 2>/dev/null)
  apt-get update -qq
  echo ">> $name kész"
done < "$LIST"

echo ">> Minden csomag elkészült: $(ls "$OUT"/*.deb | wc -l) .deb"
