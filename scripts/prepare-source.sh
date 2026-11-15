#!/usr/bin/env bash
# Debian forráscsomag (.dsc) készítése: upstream tag + saját csomagolás + új changelog bejegyzés.
# Használat: prepare-source.sh <upstream_verzió> <csomagolás_mappa> <kimeneti_könyvtár>
#   <csomagolás_mappa>: az a mappa, amelyben a debian/ könyvtár van (pl. packaging/xlibre-server)
# Kell hozzá: git, xz-utils, dpkg-dev, devscripts
set -euo pipefail

UP=$1
PKG_DIR=$(cd "$2" && pwd)
[[ -f "$PKG_DIR/debian/changelog" ]] || { echo "Nincs debian/changelog itt: $PKG_DIR" >&2; exit 1; }
PKG_ID=${PACKAGING_ID:-$(git -C "$PKG_DIR" rev-parse --short HEAD 2>/dev/null || echo helyi)}
OUT=$(mkdir -p "$3" && cd "$3" && pwd)

UPSTREAM_REPO=${UPSTREAM_REPO:-https://github.com/X11Libre/xserver.git}
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

echo ">> Csomagolás: $PKG_DIR ($PKG_ID)"
rm -rf "$SRC/debian"
cp -a "$PKG_DIR/debian" "$SRC/debian"

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
  "Automatikus build: XLibre xserver $UP, csomagolás: ${PKG_ID:0:7}.")

(cd "$WORK" && dpkg-source --build "xlibre-server-$UP")

cp -v "$WORK"/xlibre-server_*.dsc "$WORK"/xlibre-server_*.orig.tar.xz "$WORK"/xlibre-server_*.debian.tar.* "$OUT/"
echo "$NEWVER" > "$OUT/VERSION"
