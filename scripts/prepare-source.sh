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
# Opcionális: a szerver kiadási tag-jének PGP-aláírását ellenőrzi ezzel a kulccsal (40 hexa karakter).
SERVER_TAG_KEY_FPR=${SERVER_TAG_KEY_FPR:-}
# Honnan töltse le a kulcsot; üresen a keyserver.ubuntu.com-ról, ujjlenyomat alapján.
SERVER_TAG_KEY_URL=${SERVER_TAG_KEY_URL:-}

read -r _ REPO PREFIX MODE < <(awk -F'\t' -v n="$NAME" '$1==n' "$LIST")
[[ -n "${MODE:-}" ]] || { echo "Nincs ilyen csomag a $LIST fájlban: $NAME" >&2; exit 1; }

SRCNAME=$(awk '/^Source:/{print $2; exit}' "$PKG_DIR/debian/control")
FORMAT=$(cat "$PKG_DIR/debian/source/format" 2>/dev/null || echo "1.0")

TOP=$(dpkg-parsechangelog -l "$PKG_DIR/debian/changelog" -S Version)   # pl. 2:25.2.2-1
EPOCH=""; [[ "$TOP" == *:* ]] && EPOCH="${TOP%%:*}:"
TOP_NOEPOCH=${TOP#*:}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# A tag aláírásának ellenőrzése: csak a megadott ujjlenyomatú kulcs aláírását fogadjuk el.
verify_tag() { # <git könyvtár> <tag>
  local fpr gh status
  fpr=$(echo "$SERVER_TAG_KEY_FPR" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
  [[ "$fpr" =~ ^[0-9A-F]{40}$ ]] || { echo "SERVER_TAG_KEY_FPR nem 40 hexa karakter" >&2; exit 1; }
  gh="$WORK/gnupg"; mkdir -m 700 "$gh"
  if [[ -n "${SERVER_TAG_KEY_FILE:-}" ]]; then
    GNUPGHOME="$gh" gpg --batch --quiet --import "$SERVER_TAG_KEY_FILE"
  else
    curl -fsSL "${SERVER_TAG_KEY_URL:-https://keyserver.ubuntu.com/pks/lookup?op=get&options=mr&search=0x$fpr}" \
      | GNUPGHOME="$gh" gpg --batch --quiet --import
  fi
  [[ "$(git -C "$1" cat-file -t "$2")" == "tag" ]] || { echo "A(z) $2 tag nincs aláírva" >&2; exit 1; }
  status=$(GNUPGHOME="$gh" git -C "$1" -c gpg.format=openpgp -c gpg.program=gpg verify-tag --raw "$2" 2>&1) || { echo "$status" >&2; echo "A(z) $2 tag aláírása érvénytelen" >&2; exit 1; }
  # VALIDSIG <aláíró kulcs ujjl.> ... <elsődleges kulcs ujjl.>: bármelyik egyezhet
  grep -E "^\[GNUPG:\] VALIDSIG " <<<"$status" | grep -qw "$fpr" \
    || { echo "A(z) $2 tag-et nem a várt kulcs ($fpr) írta alá" >&2; exit 1; }
  echo ">> Tag-aláírás rendben: $2 ($fpr)"
}

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
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "${PREFIX}${UP}" "$REPO" "$WORK/upstream"
  if [[ "$NAME" == "xlibre-server" && -n "$SERVER_TAG_KEY_FPR" ]]; then
    verify_tag "$WORK/upstream" "${PREFIX}${UP}"
  fi
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
