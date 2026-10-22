#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$HOME/Applications/Wheelshot.app"
pkill -x ScreenshotMouse || true
pkill -x WheelShot || true
rm -rf "$HOME/Applications/Screenshot Mouse.app" "$HOME/Applications/Wheel Shot.app" "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -swift-version 5 -O -framework Cocoa -framework ServiceManagement \
  -o "$APP/Contents/MacOS/WheelShot" main.swift
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.png "$APP/Contents/Resources/AppIcon.png"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16     AppIcon.png --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32     AppIcon.png --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32     AppIcon.png --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64     AppIcon.png --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128   AppIcon.png --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256   AppIcon.png --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   AppIcon.png --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512   AppIcon.png --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   AppIcon.png --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 AppIcon.png --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"
codesign --force --sign - "$APP"
echo "Built $APP"
