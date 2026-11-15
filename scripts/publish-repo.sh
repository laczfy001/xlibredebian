#!/usr/bin/env bash
# APT tároló összeállítása reprepro-val.
# Használat: publish-repo.sh <bemenet> <kimeneti_site_könyvtár>
#   <bemenet>/source/*.dsc ...         – forráscsomag (opcionális)
#   <bemenet>/stable/*.deb, <bemenet>/testing/*.deb – saját buildek (opcionális)
# Környezeti változók:
#   SIGNING_FPR        – aláíró GPG kulcs ujjlenyomata (üresen: aláíratlan, csak teszthez)
#   MIRROR_EXTRAS      – true: a többi csomag (driverek, metacsomag, xorgproto) tükrözése
#   MIRROR_URL         – honnan tükrözzünk (alapból az xlibre-debian tároló)
#   MIRROR_KEY_FPR     – a tükrözött tároló kulcsának ujjlenyomata (üresen: blindtrust)
#   INCLUDE_DBGSYM     – true: a -dbgsym csomagok is bekerülnek
#   SITE_URL           – a publikált tároló URL-je (index.html-hez)
set -euo pipefail

IN=$(cd "$1" && pwd)
SITE=$(mkdir -p "$2" && cd "$2" && pwd)
WORK=$(mktemp -d)

ORIGIN=${ORIGIN:-XLibre-auto}
LABEL=${LABEL:-XLibre automatikus Debian tároló}
MIRROR_EXTRAS=${MIRROR_EXTRAS:-true}
MIRROR_URL=${MIRROR_URL:-https://xlibre-debian.github.io/debian}
INCLUDE_DBGSYM=${INCLUDE_DBGSYM:-false}
SITE_URL=${SITE_URL:-https://example.github.io/xlibre-apt/}
COMPONENTS="stable testing"

mkdir -p "$WORK/conf"
{
  echo "Origin: $ORIGIN"
  echo "Label: $LABEL"
  echo "Codename: main"
  echo "Architectures: amd64 arm64 source"
  echo "Components: $COMPONENTS"
  echo "Description: XLibre X szerver Debianra, automatikusan frissülő build"
  [[ -n "${SIGNING_FPR:-}" ]] && echo "SignWith: $SIGNING_FPR"
  [[ "$MIRROR_EXTRAS" == "true" ]] && echo "Update: xlibre-extras"
} > "$WORK/conf/distributions"

# A reprepro legfeljebb 16 hexa számjegyet fogad el (az ujjlenyomat vége).
MIRROR_KEY_ID=blindtrust
if [[ -n "${MIRROR_KEY_FPR:-}" ]]; then
  MIRROR_KEY_ID=$(echo "$MIRROR_KEY_FPR" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
  MIRROR_KEY_ID=${MIRROR_KEY_ID: -16}
fi

if [[ "$MIRROR_EXTRAS" == "true" ]]; then
  # Mindent tükrözünk, KIVÉVE: a saját magunk által épített xlibre-server forrás
  # csomagjait, a debug szimbólumokat és a másik tároló kulcscsomagjait.
  cat > "$WORK/conf/updates" <<EOF
Name: xlibre-extras
Method: $MIRROR_URL
Suite: main
Components: $COMPONENTS
Architectures: amd64 arm64
VerifyRelease: $MIRROR_KEY_ID
FilterFormula: !\$Source (== xlibre-server), !Package (% *-dbgsym), !Package (== xlibre-archive-keyring), !Package (== nexussfan-archive-keyring)
EOF
fi

R=(reprepro --basedir "$WORK" --outdir "$SITE" --silent)

if [[ "$MIRROR_EXTRAS" == "true" ]]; then
  echo ">> Tükrözés: $MIRROR_URL"
  "${R[@]}" --noskipold update
fi

shopt -s nullglob
for comp in $COMPONENTS; do
  debs=("$IN/$comp"/*.deb)
  if [[ "$INCLUDE_DBGSYM" != "true" ]] && (( ${#debs[@]} )); then
    mapfile -t debs < <(printf '%s\n' "${debs[@]}" | grep -v -- '-dbgsym_' || true)
  fi
  if (( ${#debs[@]} )); then
    echo ">> $comp: ${#debs[@]} saját .deb"
    "${R[@]}" -C "$comp" includedeb main "${debs[@]}"
  fi
  for dsc in "$IN"/source/*.dsc; do
    "${R[@]}" -C "$comp" includedsc main "$dsc"
  done
done

"${R[@]}" export
"${R[@]}" list main | sort > "$SITE/packages.txt"

if [[ -n "${SIGNING_FPR:-}" ]]; then
  gpg --armor --export "$SIGNING_FPR" > "$SITE/key.asc"
fi

SERVER_VER=$("${R[@]}" -A source -C stable list main xlibre-server 2>/dev/null | awk '{print $3}' | head -n1 || true)
sed -e "s#@SITE_URL@#${SITE_URL%/}/#g" \
    -e "s#@SERVER_VER@#${SERVER_VER:-?}#g" \
    -e "s#@DATE@#$(date -u '+%Y-%m-%d %H:%M UTC')#g" \
    "$(dirname "$0")/../site/index.html.in" > "$SITE/index.html"
touch "$SITE/.nojekyll"

rm -rf "$WORK"
echo ">> Kész: $SITE"
