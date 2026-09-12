#!/bin/bash
set -euo pipefail
preview_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$preview_root"
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Build the preview on a Mac with macOS 14 or later." >&2
  exit 1
fi
./scripts/fetch-data.sh
version="$(tr -d '\r\n' < VERSION)"
case "${1:-}" in
  "") architectures=("$(uname -m)"); label="${architectures[0]}" ;;
  --universal) architectures=(arm64 x86_64); label=universal ;;
  *) echo "Usage: ./scripts/build.sh [--universal]" >&2; exit 1 ;;
esac
stage="$(mktemp -d "${TMPDIR:-/tmp}/fruitfly-preview-build.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/Fruitfly Preview.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$preview_root/../../dist"
binaries=()
for arch in "${architectures[@]}"; do
  swift build -c release --product FruitflyBrainPreview --triple "$arch-apple-macosx14.0" --disable-local-rpath
  bin_path="$(swift build -c release --triple "$arch-apple-macosx14.0" --show-bin-path)"
  binaries+=("$bin_path/FruitflyBrainPreview")
done
if [[ "${#binaries[@]}" -eq 1 ]]; then
  cp "${binaries[0]}" "$app/Contents/MacOS/FruitflyBrainPreview"
else
  lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/FruitflyBrainPreview"
fi
strip -x "$app/Contents/MacOS/FruitflyBrainPreview"
cp -R Data "$app/Contents/Resources/"
cp LICENSE "$app/Contents/Resources/LICENSE.txt"
cp ../../docs/full-map-preview.md "$app/Contents/Resources/Model-notes.md"
cp THIRD_PARTY.md "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Fruitfly Preview</string>
<key>CFBundleDisplayName</key><string>Fruitfly Preview</string>
<key>CFBundleExecutable</key><string>FruitflyBrainPreview</string>
<key>CFBundleIdentifier</key><string>io.github.onequbitaway.fruitfly.preview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>$version</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleIconFile</key><string>Fruitfly</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
"$app/Contents/MacOS/FruitflyBrainPreview" --export-icon "$stage/Fruitfly.iconset"
iconutil -c icns "$stage/Fruitfly.iconset" -o "$app/Contents/Resources/Fruitfly.icns"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
plutil -lint "$app/Contents/Info.plist"
output="$preview_root/../../dist/Fruitfly Preview.app"
# This path is the generated preview bundle, never the installed desktop app.
if [[ -d "$output" ]]; then rm -rf "$output"; fi
mv "$app" "$output"
archive="Fruitfly-Full-Map-Preview-$version-macos-$label.zip"
(cd ../../dist && ditto -c -k --keepParent 'Fruitfly Preview.app' "$archive" && shasum -a 256 "$archive" > "$archive.sha256")
echo "Built dist/$archive"
