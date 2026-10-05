#!/bin/bash
# Build, install and launch the watchOS render spike on the simulator.
set -euo pipefail
cd "$(dirname "$0")"

SIM="${SIM:-5D229200-DC77-432C-94B2-EEDB0644469A}"   # Apple Watch Series 11 (46mm), watchOS 26.5
BUNDLE_ID="com.uno.watchrenderspike"
APP="build/WatchRenderSpike.app"
SDK="$(xcrun --sdk watchsimulator --show-sdk-path)"

rm -rf build && mkdir -p "$APP"

xcrun swiftc \
  -target arm64-apple-watchos26.5-simulator \
  -sdk "$SDK" \
  -parse-as-library -O \
  -o "$APP/WatchRenderSpike" \
  Sources/Renderer.swift Sources/App.swift

cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>WatchRenderSpike</string>
  <key>CFBundleDisplayName</key><string>Uno Spike</string>
  <key>CFBundleExecutable</key><string>WatchRenderSpike</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>26.5</string>
  <key>UIDeviceFamily</key><array><integer>4</integer></array>
  <key>WKApplication</key><true/>
  <key>WKWatchOnly</key><true/>
  <key>CFBundleSupportedPlatforms</key><array><string>WatchSimulator</string></array>
</dict></plist>
PLIST

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"
echo "installed -> $BUNDLE_ID on $SIM"
