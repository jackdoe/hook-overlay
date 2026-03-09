#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="HookOverlay"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"

echo "==> Building $APP_NAME..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Compile all Swift sources into a single binary
swiftc \
    -O \
    -whole-module-optimization \
    -target arm64-apple-macos13.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -import-objc-header /dev/null \
    -o "$BUILD_DIR/$APP_NAME" \
    "$SCRIPT_DIR"/Sources/*.swift \
    2>&1

# Also build x86_64 variant and create universal binary if possible
if swiftc \
    -O \
    -whole-module-optimization \
    -target x86_64-apple-macos13.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -import-objc-header /dev/null \
    -o "$BUILD_DIR/${APP_NAME}_x86" \
    "$SCRIPT_DIR"/Sources/*.swift \
    2>/dev/null; then

    lipo -create \
        "$BUILD_DIR/$APP_NAME" \
        "$BUILD_DIR/${APP_NAME}_x86" \
        -output "$BUILD_DIR/${APP_NAME}_universal"
    mv "$BUILD_DIR/${APP_NAME}_universal" "$BUILD_DIR/$APP_NAME"
    rm -f "$BUILD_DIR/${APP_NAME}_x86"
    echo "    Built universal binary (arm64 + x86_64)"
else
    echo "    Built arm64 binary"
fi

# Create .app bundle
echo "==> Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

# Bundle font
if [ -f "$SCRIPT_DIR/DepartureMonoNerdFont-Regular.otf" ]; then
    cp "$SCRIPT_DIR/DepartureMonoNerdFont-Regular.otf" "$APP_BUNDLE/Contents/Resources/"
    echo "    Bundled DepartureMono font"
fi

echo "==> Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$INSTALL_DIR/"

echo ""
echo "✅ Built and installed: $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "Next steps:"
echo "  1. Run: open '$INSTALL_DIR/$APP_NAME.app'"
echo "  2. Grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility)"
echo "  3. Run: ./install.sh   to set up the Claude Code hook and auto-launch"
