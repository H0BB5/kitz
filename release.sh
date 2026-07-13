#!/usr/bin/env sh
# Compute the url + sha256 for the Homebrew formula after you've pushed a tag.
# Usage: ./release.sh v0.2.0   (repo defaults to H0BB5/kitz; override with KITZ_REPO)
set -eu

TAG="${1:-}"
[ -n "$TAG" ] || { echo "usage: ./release.sh <tag>   e.g. ./release.sh v0.2.0" >&2; exit 1; }
REPO="${KITZ_REPO:-H0BB5/kitz}"
URL="https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz"

echo "fetching $URL …"
# Download to a file first: piping curl into shasum hides curl's exit status,
# so a 404 would otherwise yield the SHA256 of empty input (e3b0c442…b855).
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
if ! curl -fsSL "$URL" -o "$TMP"; then
  echo "could not fetch $URL — is the tag pushed AND the repo public?" >&2
  echo "(GitHub archive tarballs 404 for private repos; make it public first.)" >&2
  exit 1
fi
SHA="$(shasum -a 256 "$TMP" | awk '{print $1}')"

cat <<EOF

Paste into homebrew/kitz.rb (then push it to h0bb5/homebrew-tap at Formula/kitz.rb):

  url "$URL"
  sha256 "$SHA"
  version "${TAG#v}"
EOF
