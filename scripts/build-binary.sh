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
HOST_ARCH=$(dpkg --print-architecture)

# Van-e a csomagban ezen az architektúrán fordítható bináris? (pl. vmmouse, intel, vesa: csak x86)
has_binary_for_host() { # <debian/control>
  local a
  for a in $(awk '/^Architecture:/{ $1=""; print }' "$1"); do
    [[ "$a" == "all" ]] && return 0
    dpkg-architecture -a"$HOST_ARCH" -i "$a" 2>/dev/null && return 0
  done
  return 1
}

while IFS=$'\t' read -r name _; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  dscs=("$SRC_DIR/${name}"_*.dsc)
  (( ${#dscs[@]} == 1 )) || { echo "::error::Nincs (vagy több van) forráscsomag: $name"; exit 1; }

  echo "::group::$name"
  rm -rf "${BUILD:?}"/*
  dpkg-source -x "${dscs[0]}" "$BUILD/src"
  if ! has_binary_for_host "$BUILD/src/debian/control"; then
    echo "::endgroup::"
    echo ">> $name kihagyva: $HOST_ARCH architektúrán nincs fordítható csomagja"
    continue
  fi
  if ! ( cd "$BUILD/src" \
         && apt-get build-dep -y ./ \
         && dpkg-buildpackage -b -uc -us -j"$(nproc)" ); then
    echo "::endgroup::"
    echo "::error::$name fordítása sikertelen ($COMPONENT/$HOST_ARCH)"
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
