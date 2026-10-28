#!/usr/bin/env bash
set -euo pipefail

# Change to project root
cd "$(dirname "$0")/../.."

mkdir -p dist

FLAVOR="${FLAVOR:-demo}"
APP_ENV="${APP_ENV:-demo}"
API_BASE_URL="${API_BASE_URL:-https://3rgcn2lx-8000.asse.devtunnels.ms/v1}"
IMAGE_TAG="${IMAGE_TAG:-tbscreen-builder}"

HOST_UID="$(id -u 2>/dev/null || echo 1000)"
HOST_GID="$(id -g 2>/dev/null || echo 1000)"

echo "Building TBScreen for Linux ARM64 (Raspberry Pi 5)..."
echo "  Flavor:       $FLAVOR"
echo "  APP_ENV:      $APP_ENV"
echo "  API_BASE_URL: $API_BASE_URL"

docker run --rm --platform linux/arm64 \
  -e HOST_UID="$HOST_UID" -e HOST_GID="$HOST_GID" \
  -e FLAVOR="$FLAVOR" \
  -e APP_ENV="$APP_ENV" \
  -e API_BASE_URL="$API_BASE_URL" \
  -v "$PWD":/src:ro \
  -v "$PWD/dist":/out \
  -v tbscreen-pub-cache:/root/.pub-cache \
  "$IMAGE_TAG" bash -c '
    set -e
    rsync -a --delete --exclude build --exclude .dart_tool /src/ /work/
    cd /work
    flutter pub get
    flutter build linux --release \
      --flavor "$FLAVOR" \
      --dart-define=APP_ENV="$APP_ENV" \
      --dart-define=API_BASE_URL="$API_BASE_URL"
    
    BUNDLE_SRC="build/linux/arm64/$FLAVOR/release/bundle"
    if [ ! -d "$BUNDLE_SRC" ]; then
      BUNDLE_SRC="build/linux/arm64/release/bundle"
    fi

    rm -rf /out/bundle
    cp -r "$BUNDLE_SRC" /out/bundle
    if [ -n "${HOST_UID:-}" ]; then
      chown -R "$HOST_UID:$HOST_GID" /out/bundle || true
    fi
  '

echo "Build complete! Output bundle located at: dist/bundle"
