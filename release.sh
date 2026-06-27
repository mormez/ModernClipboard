#!/bin/bash
set -e

# Full Developer ID release pipeline for Modern Clipboard.
#
# Builds Release -> signs every nested Sparkle component (hardened runtime) ->
# notarizes + staples the .app -> builds a drag-to-Applications .dmg ->
# signs + notarizes + staples the .dmg -> regenerates docs/appcast.xml
# (signed with the Sparkle EdDSA key) so existing users auto-update.
#
# Usage: ./release.sh <marketing-version> <build-number>
# Example: ./release.sh 1.1.0 2
#
# Prereqs (one-time, already done):
#   - Developer ID Application cert in the login keychain
#   - notarytool profile "ModernClipboard-notary" stored in the keychain
#   - Sparkle EdDSA private key in the login keychain (public key in Info.plist)

VERSION=$1
BUILD=$2

if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
  echo "Usage: ./release.sh <marketing-version> <build-number>"
  echo "Example: ./release.sh 1.1.0 2"
  exit 1
fi

IDENTITY="Developer ID Application: MOR MEZRICH (XW9JVVTBT8)"
NOTARY_PROFILE="ModernClipboard-notary"
GITHUB_REPO="https://github.com/mormez/ModernClipboard"

# --- Bump version numbers -------------------------------------------------
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Sources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" Sources/Info.plist

# --- Build Release --------------------------------------------------------
echo "Building Modern Clipboard $VERSION ($BUILD) — Release configuration..."
xcodebuild \
  -project "Modern Clipboard.xcodeproj" \
  -scheme "Modern Clipboard" \
  -configuration Release \
  -derivedDataPath build/ReleaseDerivedData \
  build

APP=$(find build/ReleaseDerivedData -name "Modern Clipboard.app" -type d -path "*Release*" | head -1)
if [ -z "$APP" ]; then
  echo "Build failed: app not found"
  exit 1
fi

# --- Sign every nested Sparkle component, inside-out ----------------------
# Xcode signs the framework shell but not Sparkle's nested executables;
# notarization rejects the build unless each one is signed with hardened runtime.
echo "Signing nested Sparkle components..."
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
sign() { codesign -f -o runtime --timestamp -s "$IDENTITY" "$1"; }
sign "$SPARKLE/XPCServices/Downloader.xpc"
sign "$SPARKLE/XPCServices/Installer.xpc"
sign "$SPARKLE/Updater.app/Contents/MacOS/Updater"
sign "$SPARKLE/Updater.app"
sign "$SPARKLE/Autoupdate"
sign "$APP/Contents/Frameworks/Sparkle.framework"
codesign -f -o runtime --timestamp \
  --entitlements Sources/ModernClipboard.entitlements -s "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
echo "✓ Signed and verified"

# --- Notarize + staple the .app ------------------------------------------
echo "Notarizing the app (this can take a few minutes)..."
APP_ZIP="/tmp/ModernClipboard-app-$VERSION.zip"
rm -f "$APP_ZIP"
ditto -c -k --keepParent "$APP" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
echo "✓ App notarized and stapled"

# --- Build the styled drag-to-Applications .dmg --------------------------
# Uses create-dmg (brew install create-dmg) for a polished window: HiDPI
# background image (packaging/dmg-background.tiff, an arrow pointing app ->
# Applications), positioned icons, larger icon size, and the Applications drop
# link. Source folder holds ONLY the app — create-dmg adds the Applications
# shortcut via --app-drop-link. To tweak the background, edit and re-run
# packaging/make_dmg_background.py, then rebuild the tiff with tiffutil.
RELEASE_DIR="releases/v$VERSION"
mkdir -p "$RELEASE_DIR"
DMG_PATH="$RELEASE_DIR/ModernClipboard.dmg"

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "create-dmg not found. Install it with: brew install create-dmg"
  exit 1
fi

STAGE="/tmp/mc_dmg_stage_$VERSION"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
rm -f "$DMG_PATH"
create-dmg \
  --volname "Modern Clipboard" \
  --background "packaging/dmg-background.tiff" \
  --window-pos 200 120 \
  --window-size 600 460 \
  --icon-size 128 \
  --icon "Modern Clipboard.app" 150 205 \
  --app-drop-link 450 205 \
  --no-internet-enable \
  "$DMG_PATH" \
  "$STAGE"

# --- Sign + notarize + staple the .dmg -----------------------------------
codesign -f --timestamp -s "$IDENTITY" "$DMG_PATH"
echo "Notarizing the dmg (this can take a few minutes)..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
echo "✓ DMG built, notarized, and stapled: $DMG_PATH"

# --- Regenerate the appcast (signs the dmg with the Sparkle key) ----------
GEN=$(find build/ReleaseDerivedData -name "generate_appcast" -path "*sparkle*" | head -1)
if [ -z "$GEN" ]; then
  echo "Could not find generate_appcast. Run ./build.sh once to fetch Sparkle."
  exit 1
fi
"$GEN" \
  --download-url-prefix "$GITHUB_REPO/releases/download/v$VERSION/" \
  --link "$GITHUB_REPO" \
  "$RELEASE_DIR/"
cp "$RELEASE_DIR/appcast.xml" docs/appcast.xml
echo "✓ docs/appcast.xml regenerated"

echo ""
echo "==========================================================="
echo "Release $VERSION ($BUILD) is ready. To publish:"
echo ""
echo "1. Create a GitHub Release tagged v$VERSION and upload:"
echo "   $DMG_PATH"
echo "   $GITHUB_REPO/releases/new"
echo ""
echo "2. Commit and push docs/appcast.xml (GitHub Pages serves the feed)."
echo "   Existing users will be offered the update automatically."
echo "==========================================================="
