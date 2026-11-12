#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
app="$(pwd)/build/显卡开关.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
bash scripts/make-icons.sh
xcrun swiftc -O -target x86_64-apple-macosx12.0 \
    -module-cache-path "$(pwd)/build/module-cache" \
    Sources/GPUModel.swift Sources/main.swift \
    -framework AppKit -o "$app/Contents/MacOS/GPUSwitch"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp build/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp -R Resources/en.lproj Resources/zh-Hans.lproj "$app/Contents/Resources/"
codesign --force --sign - "$app"
printf 'Built: %s\n' "$app"
