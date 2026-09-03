#!/bin/zsh
# Builds a release binary and wraps it in a double-clickable macOS app bundle at dist/Farkle Optimizer.app
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product FarkleOptimizer
APP="dist/Farkle Optimizer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/FarkleOptimizer "$APP/Contents/MacOS/FarkleOptimizer"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Farkle Optimizer</string>
    <key>CFBundleDisplayName</key><string>Farkle Optimizer</string>
    <key>CFBundleIdentifier</key><string>tech.dougmason.farkle-optimizer</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleExecutable</key><string>FarkleOptimizer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>
PLIST
if [[ -f scripts/make-icon.swift ]]; then
  swift scripts/make-icon.swift "$APP/Contents/Resources/AppIcon.icns" || echo "icon generation skipped"
fi
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
