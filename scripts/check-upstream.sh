#!/usr/bin/env bash
# Megkeresi a legfrissebb XLibre xserver kiadást és a Debian-csomagolás aktuális commitját.
# Kimenet: key=value sorok (stdout, és $GITHUB_OUTPUT, ha létezik).
set -euo pipefail

UPSTREAM_REPO=${UPSTREAM_REPO:-https://github.com/X11Libre/xserver.git}
PACKAGING_REPO=${PACKAGING_REPO:-https://github.com/xlibre-debian/xlibre-server.git}
PACKAGING_BRANCH=${PACKAGING_BRANCH:-xlibre/latest}
# Kézzel megadott verzió (pl. 25.2.3); üresen a legfrissebb tag-et használja.
UPSTREAM_VERSION=${UPSTREAM_VERSION:-}

if [[ -z "$UPSTREAM_VERSION" ]]; then
  UPSTREAM_VERSION=$(
    git ls-remote --tags --refs "$UPSTREAM_REPO" 'xlibre-xserver-*' \
      | awk '{print $2}' | sed 's#^refs/tags/xlibre-xserver-##' \
      | grep -E '^[0-9]+(\.[0-9]+)+$' \
      | sort -V | tail -n1
  )
fi
[[ -n "$UPSTREAM_VERSION" ]] || { echo "Nem találtam upstream verziót" >&2; exit 1; }

PACKAGING_SHA=$(git ls-remote "$PACKAGING_REPO" "refs/heads/$PACKAGING_BRANCH" | cut -f1)
[[ -n "$PACKAGING_SHA" ]] || { echo "Nem találom a csomagolási ágat: $PACKAGING_BRANCH" >&2; exit 1; }

RELEASE_TAG="xlibre-server-${UPSTREAM_VERSION}-pkg${PACKAGING_SHA:0:7}"

out() { echo "$1=$2"; [[ -n "${GITHUB_OUTPUT:-}" ]] && echo "$1=$2" >> "$GITHUB_OUTPUT"; return 0; }
out upstream_version "$UPSTREAM_VERSION"
out packaging_sha "$PACKAGING_SHA"
out release_tag "$RELEASE_TAG"
