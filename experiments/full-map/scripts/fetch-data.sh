#!/bin/bash
set -euo pipefail
preview_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$preview_root"
if shasum -a 256 -c data-files.sha256 >/dev/null 2>&1; then
  echo "The full-map data is ready."
  exit 0
fi
if [[ -e Data ]]; then
  echo "Data contains different or incomplete files. Move that folder aside, then run this command again." >&2
  exit 1
fi
archive_name="MaleCNS-v1.0-fruitfly-data.tar.gz"
archive_url="https://github.com/onequbitaway/fruitfly/releases/download/full-map-preview-0.1.0/$archive_name"
cache="$preview_root/../../.cache/full-map-download"
mkdir -p "$cache"
archive="$cache/$archive_name"
expected="$(awk '{print $1}' data-pack.sha256)"
valid_archive() { [[ -f "$archive" ]] && [[ "$(shasum -a 256 "$archive" | awk '{print $1}')" == "$expected" ]]; }
stage="$(mktemp -d "$preview_root/.data-stage.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
if ! valid_archive; then
  echo "Downloading the full-map data pack (about 75 MB)."
  curl --fail --location --retry 3 --connect-timeout 30 --output "$stage/$archive_name" "$archive_url"
  actual="$(shasum -a 256 "$stage/$archive_name" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "The data download failed its checksum check." >&2
    exit 1
  fi
  mv "$stage/$archive_name" "$archive"
fi
tar -xzf "$archive" -C "$stage"
(cd "$stage" && shasum -a 256 -c "$preview_root/data-files.sha256")
mv "$stage/Data" Data
echo "The full-map data is ready."
