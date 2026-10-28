#!/usr/bin/env bash
# Compile l'app Swift et assemble Besom.app.
# UNIVERSAL=1 ./build.sh  -> binaire arm64 + x86_64
set -euo pipefail
cd "$(dirname "$0")"

ROOT="$PWD"
APP="$ROOT/dist/Besom.app"

echo "▸ Compilation Swift"
ARCHS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then ARCHS=(--arch arm64 --arch x86_64); fi
swift build -c release ${ARCHS[@]+"${ARCHS[@]}"}
BIN_DIR="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)"

echo "▸ Assemblage de l'app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Besom" "$APP/Contents/MacOS/Besom"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

echo "▸ Signature ad hoc"
codesign --force --deep --sign - "$APP"

echo "✓ $APP"
lipo -info "$APP/Contents/MacOS/Besom"
