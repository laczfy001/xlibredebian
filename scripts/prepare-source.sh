#!/usr/bin/env bash
# Debian forráscsomag (.dsc) készítése: upstream tag + xlibre-debian csomagolás + új changelog bejegyzés.
# Használat: prepare-source.sh <upstream_verzió> <csomagolás_commit> <kimeneti_könyvtár>
# Kell hozzá: git, xz-utils, dpkg-dev, devscripts
set -euo pipefail

UP=$1
PKG_SHA=$2
OUT=$(mkdir -p "$3" && cd "$3" && pwd)

UPSTREAM_REPO=${UPSTREAM_REPO:-https://github.com/X11Libre/xserver.git}
PACKAGING_REPO=${PACKAGING_REPO:-https://github.com/xlibre-debian/xlibre-server.git}
export DEBFULLNAME=${MAINTAINER_NAME:-XLibre auto-builder}
export DEBEMAIL=${MAINTAINER_EMAIL:-noreply@example.invalid}
STAMP=${BUILD_STAMP:-$(date -u +%Y%m%d%H%M)}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
SRC="$WORK/xlibre-server-$UP"

echo ">> Upstream: xlibre-xserver-$UP"
git clone --quiet --depth 1 --branch "xlibre-xserver-$UP" "$UPSTREAM_REPO" "$WORK/upstream"
git -C "$WORK/upstream" archive --format=tar --prefix="xlibre-server-$UP/" HEAD \
  | xz -T0 -6 > "$WORK/xlibre-server_$UP.orig.tar.xz"
tar -C "$WORK" -xJf "$WORK/xlibre-server_$UP.orig.tar.xz"

echo ">> Csomagolás: $PACKAGING_REPO @ $PKG_SHA"
git init --quiet "$WORK/packaging"
git -C "$WORK/packaging" fetch --quiet --depth 1 "$PACKAGING_REPO" "$PKG_SHA"
git -C "$WORK/packaging" checkout --quiet FETCH_HEAD
rm -rf "$SRC/debian"
cp -a "$WORK/packaging/debian" "$SRC/debian"

# Verziószám: a csomagolás legfelső changelog-bejegyzéséből számolva, mindig annál nagyobb.
TOP=$(dpkg-parsechangelog -l "$SRC/debian/changelog" -S Version)   # pl. 2:25.2.2-1
EPOCH=""; [[ "$TOP" == *:* ]] && EPOCH="${TOP%%:*}:"
TOP_NOEPOCH=${TOP#*:}
TOP_UP=${TOP_NOEPOCH%-*}
TOP_REV=${TOP_NOEPOCH##*-}

if [[ "$TOP_UP" == "$UP" ]]; then
  NEWVER="${EPOCH}${UP}-${TOP_REV}+auto${STAMP}"
elif dpkg --compare-versions "$UP" gt "$TOP_UP"; then
  NEWVER="${EPOCH}${UP}-0+auto${STAMP}"
else
  echo "A csomagolás ($TOP_UP) újabb, mint a kért upstream verzió ($UP) – leállok." >&2
  exit 1
fi

echo ">> Új verzió: $NEWVER"
(cd "$SRC" && dch --newversion "$NEWVER" --distribution unstable --urgency medium \
  "Automatikus build: XLibre xserver $UP, csomagolás: ${PKG_SHA:0:7}.")

(cd "$WORK" && dpkg-source --build "xlibre-server-$UP")

cp -v "$WORK"/xlibre-server_*.dsc "$WORK"/xlibre-server_*.orig.tar.xz "$WORK"/xlibre-server_*.debian.tar.* "$OUT/"
echo "$NEWVER" > "$OUT/VERSION"
