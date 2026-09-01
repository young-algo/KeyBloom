#!/bin/zsh
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "KeyBloom must be built on macOS because it uses AppKit and SwiftUI."
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="KeyBloom"
BINARY_NAME="KeyBloom"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"
INSTALL_APP="$INSTALL_DIR/$APP_NAME.app"

# Prefer the compatible SDK on Macs whose Command Line Tools default to a
# mismatched beta SDK. Keep module caches in a writable temporary location.
if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi

CACHE_BASE="${TMPDIR:-/tmp}/keybloom-module-cache"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$CACHE_BASE/clang}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$CACHE_BASE/swiftpm}"

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift was not found. Install Apple's command-line developer tools with:"
  echo "  xcode-select --install"
  exit 1
fi

cd "$ROOT_DIR"
echo "Building KeyBloom…"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

ICON_FILE="$ROOT_DIR/Assets/AppIcon.icns"
if [[ ! -f "$ICON_FILE" ]]; then
  echo "ERROR: app icon not found at $ICON_FILE"
  echo "       Restore Assets/AppIcon.icns before building."
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BIN_DIR/$BINARY_NAME" "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"
cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
chmod +x "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>KeyBloom</string>
    <key>CFBundleExecutable</key>
    <string>KeyBloom</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.kevinturner.keybloom</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>KeyBloom</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSMultipleInstancesProhibited</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Personal-use software</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

# macOS ties the Accessibility (TCC) grant to the bundle's code requirement.
# An ad-hoc signature has no stable identity, so the requirement collapses to the
# exact cdhash and every rebuild silently revokes the permission the user granted.
# Signing with a real (even self-signed) certificate keeps the requirement stable.
SIGN_IDENTITY="${KEYBLOOM_SIGN_IDENTITY:-}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  # Lines look like:  1) <40-hex-hash> "Identity Name"
  # Prefer a self-signed/local identity over "Apple Development:" profiles, which
  # expire and are tied to a provisioning profile.
  IDENTITY_LIST="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  SIGN_IDENTITY="$(printf '%s\n' "$IDENTITY_LIST" \
    | sed -n 's/^[[:space:]]*[0-9][0-9]*)[[:space:]]*[0-9A-Fa-f][0-9A-Fa-f]*[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' \
    | grep -v '^Apple Development:' \
    | sed -n '1p' || true)"
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "Signing with identity: $SIGN_IDENTITY"
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
  echo "WARNING: no stable code-signing identity found; falling back to ad-hoc."
  echo "         You will have to re-grant Accessibility permission after every build."
  echo "         Create one in Keychain Access → Certificate Assistant → Create a Certificate"
  echo "         (type: Code Signing), then re-run this script."
  codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "Built: $APP_BUNDLE"

if [[ "${1:-}" == "--install" ]]; then
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALL_APP"
  ditto "$APP_BUNDLE" "$INSTALL_APP"
  echo "Installed: $INSTALL_APP"
  open "$INSTALL_APP"
elif [[ "${1:-}" == "--open" ]]; then
  open "$APP_BUNDLE"
else
  echo "Open it with:"
  echo "  open \"$APP_BUNDLE\""
  echo "Or install it in ~/Applications with:"
  echo "  ./build_app.sh --install"
fi
