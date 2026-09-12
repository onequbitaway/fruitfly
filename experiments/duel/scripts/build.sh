#!/bin/bash
set -euo pipefail
duel_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$duel_root"
../full-map/scripts/fetch-data.sh
version="$(tr -d '\r\n' < VERSION)"
case "${1:-}" in
  "") architectures=("$(uname -m)"); label="${architectures[0]}" ;;
  --universal) architectures=(arm64 x86_64); label=universal ;;
  *) echo "Usage: ./scripts/build.sh [--universal]" >&2; exit 1 ;;
esac
stage="$(mktemp -d "${TMPDIR:-/tmp}/fruitfly-duel-build.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/Fruitfly Duel.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$duel_root/../../dist"
binaries=()
for arch in "${architectures[@]}"; do
  swift build -c release --scratch-path ".build/package-$arch" --product FruitflyDuel --triple "$arch-apple-macosx14.0" --disable-local-rpath
  bin_path="$(swift build -c release --scratch-path ".build/package-$arch" --triple "$arch-apple-macosx14.0" --show-bin-path)"
  binaries+=("$bin_path/FruitflyDuel")
done
if [[ "${#binaries[@]}" -eq 1 ]]; then
  cp "${binaries[0]}" "$app/Contents/MacOS/FruitflyDuel"
else
  lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/FruitflyDuel"
fi
strip -x "$app/Contents/MacOS/FruitflyDuel"
cp -R "$bin_path/FruitflyDuel_DuelCore.bundle" "$app/Contents/Resources/"
cp Engine/vendor/LICENSE "$app/Contents/Resources/Super-Bash-Folds-LICENSE.txt"
cp Engine/vendor/UPSTREAM.json "$app/Contents/Resources/Super-Bash-Folds-source.json"
cp -R ../full-map/Data "$app/Contents/Resources/"
cp ../../LICENSE "$app/Contents/Resources/LICENSE.txt"
cp README.md "$app/Contents/Resources/Read-me.md"
cp ../full-map/THIRD_PARTY.md "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Fruitfly Duel</string>
<key>CFBundleDisplayName</key><string>Fruitfly Duel</string>
<key>CFBundleExecutable</key><string>FruitflyDuel</string>
<key>CFBundleIdentifier</key><string>io.github.onequbitaway.fruitfly.duel</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>$version</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleIconFile</key><string>FruitflyDuel</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
"$app/Contents/MacOS/FruitflyDuel" --export-icon "$stage/FruitflyDuel.iconset"
iconutil -c icns "$stage/FruitflyDuel.iconset" -o "$app/Contents/Resources/FruitflyDuel.icns"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
plutil -lint "$app/Contents/Info.plist"
output="$duel_root/../../dist/Fruitfly Duel.app"
if [[ -d "$output" ]]; then rm -rf "$output"; fi
mv "$app" "$output"
archive="Fruitfly-Duel-$version-macos-$label.zip"
(cd ../../dist && ditto -c -k --keepParent 'Fruitfly Duel.app' "$archive" && shasum -a 256 "$archive" > "$archive.sha256")
echo "Built dist/$archive"
