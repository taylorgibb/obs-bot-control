#!/bin/bash
set -euo pipefail

name="OBS Bot Control"
executable="OBSBotControl"
identifier="io.github.taylorgibb.obs-bot-control"
minimum_macos="14.0"
version="${VERSION:-0.0.0}"

root="$(cd "$(dirname "$0")/.." && pwd)"
output="$root/build"
bundle="$output/$name.app"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"

slices=()
for architecture in arm64 x86_64; do
  swiftc -swift-version 5 -O \
    -target "$architecture-apple-macos$minimum_macos" \
    -o "$work/$architecture" \
    "$root"/Sources/*.swift
  slices+=("$work/$architecture")
done
lipo -create "${slices[@]}" -output "$bundle/Contents/MacOS/$executable"
strip -x "$bundle/Contents/MacOS/$executable"

cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$identifier</string>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundleExecutable</key><string>$executable</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$version</string>
  <key>LSMinimumSystemVersion</key><string>$minimum_macos</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

swiftc -O -o "$work/render-icon" "$root/scripts/render-icon.swift"
"$work/render-icon" "$work/icon-1024.png"
iconset="$work/AppIcon.iconset"
mkdir "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$work/icon-1024.png" --out "$iconset/icon_${size}x${size}.png" > /dev/null
  sips -z "$((size * 2))" "$((size * 2))" "$work/icon-1024.png" --out "$iconset/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$iconset" -o "$bundle/Contents/Resources/AppIcon.icns"

codesign --force --sign - --options runtime "$bundle"
codesign --verify --strict "$bundle"
echo "built $bundle"
