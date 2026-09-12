#!/bin/bash
set -euo pipefail
royale_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$royale_root"
../full-map/scripts/fetch-data.sh
version="$(tr -d '\r\n' < VERSION)"
case "${1:-}" in
  "") architectures=("$(uname -m)"); label="${architectures[0]}" ;;
  --universal) architectures=(arm64 x86_64); label=universal ;;
  *) echo "Usage: ./scripts/build.sh [--universal]" >&2; exit 1 ;;
esac
stage="$(mktemp -d "${TMPDIR:-/tmp}/fruitfly-royale-build.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/Fruitfly Royale.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$royale_root/../../dist"
binaries=()
for arch in "${architectures[@]}"; do
  swift build -c release --product FruitflyRoyale --triple "$arch-apple-macosx14.0" --disable-local-rpath
  bin_path="$(swift build -c release --triple "$arch-apple-macosx14.0" --show-bin-path)"
  binaries+=("$bin_path/FruitflyRoyale")
done
if [[ "${#binaries[@]}" -eq 1 ]]; then
  cp "${binaries[0]}" "$app/Contents/MacOS/FruitflyRoyale"
else
  lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/FruitflyRoyale"
fi
strip -x "$app/Contents/MacOS/FruitflyRoyale"
cp -R ../full-map/Data "$app/Contents/Resources/"
cp ../../LICENSE "$app/Contents/Resources/LICENSE.txt"
cp README.md "$app/Contents/Resources/Read-me.md"
cp ../full-map/THIRD_PARTY.md "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Fruitfly Royale</string>
<key>CFBundleDisplayName</key><string>Fruitfly Royale</string>
<key>CFBundleExecutable</key><string>FruitflyRoyale</string>
<key>CFBundleIdentifier</key><string>io.github.onequbitaway.fruitfly.royale</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>$version</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleIconFile</key><string>FruitflyRoyale</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
"$app/Contents/MacOS/FruitflyRoyale" --export-icon "$stage/FruitflyRoyale.iconset"
iconutil -c icns "$stage/FruitflyRoyale.iconset" -o "$app/Contents/Resources/FruitflyRoyale.icns"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
plutil -lint "$app/Contents/Info.plist"
output="$royale_root/../../dist/Fruitfly Royale.app"
if [[ -d "$output" ]]; then rm -rf "$output"; fi
mv "$app" "$output"
archive="Fruitfly-Royale-$version-macos-$label.zip"
(cd ../../dist && ditto -c -k --keepParent 'Fruitfly Royale.app' "$archive" && shasum -a 256 "$archive" > "$archive.sha256")
echo "Built dist/$archive"
