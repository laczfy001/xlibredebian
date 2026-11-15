#!/usr/bin/env bash
# Egy Debian forráscsomag (.dsc) készítése: upstream tag + packaging/<mappa>/debian + új changelog-bejegyzés.
# Használat: prepare-source.sh <mappa> <upstream_verzió | native> <kimeneti_könyvtár>
#   A tároló gyökeréből futtatandó. Az upstream tárolót és a tag-előtagot a packaging/packages.list adja.
# Kell hozzá: git, xz-utils, gzip, dpkg-dev, devscripts
set -euo pipefail

NAME=$1
UP=$2
OUT=$(mkdir -p "$3" && cd "$3" && pwd)

LIST=${PACKAGES_LIST:-packaging/packages.list}
PKG_DIR=$(cd "packaging/$NAME" && pwd)
PKG_ID=${PACKAGING_ID:-$(git rev-parse --short HEAD 2>/dev/null || echo helyi)}
export DEBFULLNAME=${MAINTAINER_NAME:-XLibre auto-builder}
export DEBEMAIL=${MAINTAINER_EMAIL:-noreply@example.invalid}
STAMP=${BUILD_STAMP:-$(date -u +%Y%m%d%H%M)}

read -r _ REPO PREFIX MODE < <(awk -F'\t' -v n="$NAME" '$1==n' "$LIST")
[[ -n "${MODE:-}" ]] || { echo "Nincs ilyen csomag a $LIST fájlban: $NAME" >&2; exit 1; }

SRCNAME=$(awk '/^Source:/{print $2; exit}' "$PKG_DIR/debian/control")
FORMAT=$(cat "$PKG_DIR/debian/source/format" 2>/dev/null || echo "1.0")

TOP=$(dpkg-parsechangelog -l "$PKG_DIR/debian/changelog" -S Version)   # pl. 2:25.2.2-1
EPOCH=""; [[ "$TOP" == *:* ]] && EPOCH="${TOP%%:*}:"
TOP_NOEPOCH=${TOP#*:}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo ">> $NAME ($SRCNAME), formátum: $FORMAT"

if [[ "$MODE" == "native" ]]; then
  # Natív csomag: a mappa maga a teljes forrás, nincs külön upstream.
  NEWVER="${TOP}+auto${STAMP}"
  SRC="$WORK/${SRCNAME}-src"
  mkdir -p "$SRC"
  (cd "$PKG_DIR" && tar --exclude=./README.md -cf - .) | tar -x -C "$SRC"
else
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

  echo ">> Upstream: $REPO @ ${PREFIX}${UP}"
  git clone --quiet --depth 1 --branch "${PREFIX}${UP}" "$REPO" "$WORK/upstream"
  SRC="$WORK/${SRCNAME}-${UP}"
  # Az 1.0 formátum csak gzip-es orig tarballt fogad el.
  if [[ "$FORMAT" == "1.0" ]]; then ORIG="${SRCNAME}_${UP}.orig.tar.gz"; COMP=(gzip -n -9)
  else ORIG="${SRCNAME}_${UP}.orig.tar.xz"; COMP=(xz -T0 -6); fi
  git -C "$WORK/upstream" archive --format=tar --prefix="${SRCNAME}-${UP}/" HEAD | "${COMP[@]}" > "$WORK/$ORIG"
  tar -C "$WORK" -xf "$WORK/$ORIG"
  rm -rf "$SRC/debian"
  cp -a "$PKG_DIR/debian" "$SRC/debian"
fi

echo ">> Új verzió: $NEWVER"
(cd "$SRC" && dch --newversion "$NEWVER" --distribution unstable --urgency medium \
  "Automatikus build (upstream: $UP, csomagolás: ${PKG_ID:0:7}).")

(cd "$WORK" && dpkg-source --build "$(basename "$SRC")")

shopt -s nullglob
cp "$WORK/${SRCNAME}"_*.dsc "$WORK/${SRCNAME}"_*.tar.* "$WORK/${SRCNAME}"_*.diff.gz "$OUT/"
printf '%s\t%s\n' "$NAME" "$NEWVER" >> "$OUT/VERSIONS"
