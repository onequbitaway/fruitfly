#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Build Fruitfly on a Mac with macOS 14 or later." >&2
  exit 1
fi
if ! xcrun --find swift >/dev/null 2>&1; then
  echo "Install the Apple build tools: xcode-select --install" >&2
  exit 1
fi

version="$(tr -d '\n\r' < VERSION)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must contain a version such as 0.1.0." >&2
  exit 1
fi

case "${1:-}" in
  "") architectures=("$(uname -m)"); label="${architectures[0]}" ;;
  --universal) architectures=(arm64 x86_64); label=universal ;;
  *) echo "Usage: ./scripts/build.sh [--universal]" >&2; exit 1 ;;
esac

stage="$(mktemp -d "${TMPDIR:-/tmp}/fruitfly-build.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/Fruitfly.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" dist
binaries=()
for arch in "${architectures[@]}"; do
  swift build -c release --triple "$arch-apple-macosx14.0" --disable-local-rpath
  bin_path="$(swift build -c release --triple "$arch-apple-macosx14.0" --show-bin-path)"
  binaries+=("$bin_path/Fruitfly")
done
if [[ "${#binaries[@]}" -eq 1 ]]; then
  cp "${binaries[0]}" "$app/Contents/MacOS/Fruitfly"
else
  lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/Fruitfly"
fi
strip -x "$app/Contents/MacOS/Fruitfly"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Fruitfly</string>
<key>CFBundleDisplayName</key><string>Fruitfly</string>
<key>CFBundleIdentifier</key><string>io.github.onequbitaway.fruitfly</string>
<key>CFBundleExecutable</key><string>Fruitfly</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$version</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
cp LICENSE "$app/Contents/Resources/LICENSE.txt"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
plutil -lint "$app/Contents/Info.plist"
# Replace only this script's output. Leave other files in dist alone.
if [[ -d dist/Fruitfly.app ]]; then rm -rf dist/Fruitfly.app; fi
mv "$app" dist/Fruitfly.app
archive="dist/Fruitfly-$version-macos-$label.zip"
ditto -c -k --keepParent dist/Fruitfly.app "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
echo "Built $archive"
echo "Start the app: open dist/Fruitfly.app"
