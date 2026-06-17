#!/usr/bin/env sh
# Compute the url + sha256 for the Homebrew formula after you've pushed a tag.
# Usage: ./release.sh v0.2.0   (repo defaults to H0BB5/cz; override with CZ_REPO)
set -eu

TAG="${1:-}"
[ -n "$TAG" ] || { echo "usage: ./release.sh <tag>   e.g. ./release.sh v0.2.0" >&2; exit 1; }
REPO="${CZ_REPO:-H0BB5/cz}"
URL="https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz"

echo "fetching $URL …"
SHA="$(curl -fsSL "$URL" | shasum -a 256 | awk '{print $1}')" \
  || { echo "could not fetch $URL — is the tag pushed?" >&2; exit 1; }

cat <<EOF

Paste into homebrew/cz.rb (then push to your homebrew-$(basename "$REPO") tap):

  url "$URL"
  sha256 "$SHA"
  version "${TAG#v}"
EOF
