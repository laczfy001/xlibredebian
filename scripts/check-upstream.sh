#!/usr/bin/env bash
# Feloldja minden csomag upstream verzióját (packaging/packages.list alapján), és kiszámolja a build azonosítóját.
# Kimenet: build-set.tsv (<mappa> TAB <upstream verzió | native>), valamint key=value sorok
# (stdout, és $GITHUB_OUTPUT, ha létezik).
set -euo pipefail

LIST=${PACKAGES_LIST:-packaging/packages.list}
BUILD_SET=${BUILD_SET:-build-set.tsv}
# Kézzel megadott szerververzió (pl. 25.2.3); üresen a legfrissebb tag.
UPSTREAM_VERSION=${UPSTREAM_VERSION:-}

changelog_version() { sed -n '1s/^[^(]*(\([^)]*\)).*/\1/p' "$1"; }
upstream_part() { local v=${1#*:}; [[ "$v" == *-* ]] && v=${v%-*}; echo "$v"; }

latest_tag() { # <repo> <előtag>
  git ls-remote --tags --refs "$1" "${2}*" \
    | awk '{print $2}' | sed "s#^refs/tags/${2}##" \
    | grep -E '^[0-9]+(\.[0-9]+)+$' | sort -V | tail -n1
}

: > "$BUILD_SET"
SERVER_VERSION=""
while IFS=$'\t' read -r name repo prefix mode; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  top=$(changelog_version "packaging/$name/debian/changelog")
  case "$mode" in
    latest)
      if [[ "$name" == "xlibre-server" && -n "$UPSTREAM_VERSION" ]]; then
        ver=$UPSTREAM_VERSION
      else
        ver=$(latest_tag "$repo" "$prefix")
      fi
      [[ -n "$ver" ]] || { echo "Nincs kiadás: $name ($repo, $prefix*)" >&2; exit 1; }
      # Ha a csomagolás már újabb upstream verzióra készült, mint a legfrissebb tag, azt használjuk.
      pkg_up=$(upstream_part "$top")
      if dpkg --compare-versions "$pkg_up" gt "$ver" 2>/dev/null; then ver=$pkg_up; fi
      ;;
    pinned) ver=$(upstream_part "$top") ;;
    native) ver=native ;;
    *) echo "Ismeretlen mód: $mode ($name)" >&2; exit 1 ;;
  esac
  printf '%s\t%s\n' "$name" "$ver" >> "$BUILD_SET"
  [[ "$name" == "xlibre-server" ]] && SERVER_VERSION=$ver
done < "$LIST"

# A build azonosítója: a verziók listája + a packaging/ mappa git tree-hash-e.
# Bármelyik csomag új kiadása vagy bármilyen csomagolási módosítás új buildet indít.
TREE=$(git rev-parse HEAD:packaging 2>/dev/null || echo nogit)
BUILD_ID=$( { cat "$BUILD_SET"; echo "$TREE"; } | sha256sum | cut -c1-8)
RELEASE_TAG="build-${SERVER_VERSION}-${BUILD_ID}"

column -t "$BUILD_SET" >&2
out() { echo "$1=$2"; [[ -n "${GITHUB_OUTPUT:-}" ]] && echo "$1=$2" >> "$GITHUB_OUTPUT"; return 0; }
out upstream_version "$SERVER_VERSION"
out build_id "$BUILD_ID"
out release_tag "$RELEASE_TAG"
