#!/usr/bin/env bash
set -e

echo "=== TBScreen Linux Desktop Build Container ==="

if [ ! -d "/workspace" ]; then
  echo "Error: /workspace is not mounted. Run container with -v \$(pwd):/workspace"
  exit 1
fi

echo "Copying source files to internal fast container storage..."
mkdir -p /app
# Sync workspace files, excluding host caches and other platform dirs
tar -C /workspace \
    --exclude='.git' \
    --exclude='.dart_tool' \
    --exclude='.pub-cache' \
    --exclude='build' \
    --exclude='android' \
    --exclude='ios' \
    --exclude='windows' \
    --exclude='macos' \
    --exclude='web' \
    -cf - . | tar -C /app -xf -

cd /app

echo "Flutter doctor:"
flutter doctor

echo "Fetching dependencies..."
flutter pub get

echo "Building Linux desktop release bundle..."
flutter build linux --release

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
  BUILD_ARCH="arm64"
else
  BUILD_ARCH="x64"
fi

echo "Detected target architecture: $ARCH (Flutter: $BUILD_ARCH)"

echo "Verifying build output..."
BUNDLE_DIR=$(find /app/build/linux -type d -name "bundle" | head -n 1)
if [ -z "$BUNDLE_DIR" ] || [ ! -d "$BUNDLE_DIR" ]; then
  echo "Build failed: bundle directory not found!"
  exit 1
fi

echo "Found release bundle at: $BUNDLE_DIR"

HOST_OUT_DIR="/workspace/build/linux/${BUILD_ARCH}/release"
mkdir -p "$HOST_OUT_DIR"
rm -rf "$HOST_OUT_DIR/bundle"
cp -r "$BUNDLE_DIR" "$HOST_OUT_DIR/bundle"

echo "Creating tarball archive..."
TARBALL_NAME="tbscreen-linux-${BUILD_ARCH}.tar.gz"
cd "$(dirname "$BUNDLE_DIR")"
tar -czvf "/workspace/build/linux/${TARBALL_NAME}" bundle/

echo "=== Build Complete! ==="
echo "Bundle location: build/linux/${BUILD_ARCH}/release/bundle"
echo "Tarball location: build/linux/${TARBALL_NAME}"
ls -lh "/workspace/build/linux/${TARBALL_NAME}"

