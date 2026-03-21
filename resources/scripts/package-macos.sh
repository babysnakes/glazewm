#!/usr/bin/env bash
# Usage: ./resources/scripts/package-macos.sh <version_number>
#
# Builds a GlazeWM.app bundle for local use on the current Mac.
# Does NOT sign, notarize, or create a DMG — suitable for local testing
# on the same machine the binaries were compiled on.
set -euo pipefail

VERSION="${1:?Usage: $0 <version_number>}"

OUT_DIR="out"
TEMP_DIR="$OUT_DIR/temp"

# Build universal binaries from per-arch release artifacts.
# Assumes `cargo build --release` has already been run for both targets.
build_universal_binaries() {
  mkdir -p "$TEMP_DIR"

  for binary in glazewm glazewm-cli; do
    local x86="target/x86_64-apple-darwin/release/$binary"
    local arm="target/aarch64-apple-darwin/release/$binary"

    if [[ ! -f "$x86" || ! -f "$arm" ]]; then
      echo "Build artifact not found for '$binary'. Building now..."
      VERSION_NUMBER="$VERSION" cargo build --locked --release \
        --target x86_64-apple-darwin \
        --target aarch64-apple-darwin
    fi

    lipo -create "$x86" "$arm" -output "$TEMP_DIR/$binary"
    chmod +x "$TEMP_DIR/$binary"
  done
}

# Convert icon.png to an ICNS file.
convert_icon() {
  local iconset_dir="$TEMP_DIR/icon.iconset"
  mkdir -p "$iconset_dir"

  sips -z 16   16   resources/assets/icon.png --out "$iconset_dir/icon_16x16.png"
  sips -z 32   32   resources/assets/icon.png --out "$iconset_dir/icon_16x16@2x.png"
  sips -z 32   32   resources/assets/icon.png --out "$iconset_dir/icon_32x32.png"
  sips -z 64   64   resources/assets/icon.png --out "$iconset_dir/icon_32x32@2x.png"
  sips -z 128  128  resources/assets/icon.png --out "$iconset_dir/icon_128x128.png"
  sips -z 256  256  resources/assets/icon.png --out "$iconset_dir/icon_128x128@2x.png"
  sips -z 256  256  resources/assets/icon.png --out "$iconset_dir/icon_256x256.png"
  sips -z 512  512  resources/assets/icon.png --out "$iconset_dir/icon_256x256@2x.png"
  sips -z 512  512  resources/assets/icon.png --out "$iconset_dir/icon_512x512.png"
  sips -z 1024 1024 resources/assets/icon.png --out "$iconset_dir/icon_512x512@2x.png"

  iconutil -c icns "$iconset_dir" -o "$TEMP_DIR/icon.icns"
}

# Assemble the .app bundle structure.
create_app_bundle() {
  local contents_dir="$TEMP_DIR/GlazeWM.app/Contents"
  mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"

  cp "$TEMP_DIR/glazewm"     "$contents_dir/MacOS/"
  cp "$TEMP_DIR/glazewm-cli" "$contents_dir/MacOS/"
  cp "$TEMP_DIR/icon.icns"   "$contents_dir/Resources/icon.icns"
  chmod +x "$contents_dir/MacOS/"*

  sed "s/\${VERSION}/$VERSION/g" resources/Info.plist > "$contents_dir/Info.plist"
  printf 'APPL????' > "$contents_dir/PkgInfo"
}

# Copy the finished .app bundle to the output directory.
copy_output() {
  mkdir -p "$OUT_DIR"
  cp -R "$TEMP_DIR/GlazeWM.app" "$OUT_DIR/GlazeWM.app"
  echo "App bundle created at $OUT_DIR/GlazeWM.app"
  codesign --force --deep --sign - $OUT_DIR/GlazeWM.app
}

echo "Packaging GlazeWM $VERSION for macOS (unsigned, local use only)"
build_universal_binaries
convert_icon
create_app_bundle
copy_output
