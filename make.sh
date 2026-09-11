#!/bin/bash
# Builds the release binary and assembles Bezel.app.
#
# Version is derived from git tags (v-prefixed semver):
#   git tag v1.0.0          -> 1.0.0
#   untagged / dirty tree   -> 0.1.0-dev / 0.1.0-dirty
#
# Usage:
#   ./make.sh          build Bezel.app
#   ./make.sh zip      build + package dist/Bezel-<version>.zip
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(git describe --tags --match 'v[0-9]*' --dirty 2>/dev/null | sed -e 's/^v//' || true)
[ -z "${VERSION:-}" ] && VERSION="0.1.0-dev"
SHORT_VERSION=$(echo "$VERSION" | cut -d- -f1)
BUILD_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "none")

swift build -c release

APP="build/Bezel.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Bezel "$APP/Contents/MacOS/"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
for lproj in Resources/*.lproj; do
    cp -R "$lproj" "$APP/Contents/Resources/"
done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleLocalizations</key>
	<array>
		<string>en</string>
		<string>zh-Hans</string>
	</array>
	<key>CFBundleExecutable</key>
	<string>Bezel</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>st.southsea.bezel</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Bezel</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${SHORT_VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${VERSION} (${BUILD_HASH})</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force -s - "$APP"
echo "Built $APP (${SHORT_VERSION} / ${VERSION})"

if [ "${1:-}" = "zip" ]; then
    mkdir -p dist
    ZIP="dist/Bezel-${VERSION}.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "Packaged $ZIP"
fi
