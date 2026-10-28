#!/usr/bin/env bash
# Launcher script to run the TBScreen ARM64 bundle on Raspberry Pi 5.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BUNDLE_DIR="${1:-$PROJECT_ROOT/dist/bundle}"
EXECUTABLE="$BUNDLE_DIR/myapp"

if [ ! -f "$EXECUTABLE" ]; then
  echo "Error: Executable not found at $EXECUTABLE"
  echo "Usage: $0 [path/to/bundle]"
  echo "Make sure you have copied the 'dist/bundle' folder to your Raspberry Pi 5."
  exit 1
fi

chmod +x "$EXECUTABLE"

# Ensure libonnxruntime.so.1 is resolved for flutter_onnxruntime plugin
if [ ! -f "$BUNDLE_DIR/lib/libonnxruntime.so.1" ] && [ ! -f /usr/lib/aarch64-linux-gnu/libonnxruntime.so.1 ]; then
  SYS_ONNX=$(find /usr/lib/aarch64-linux-gnu -name "libonnxruntime.so.1*" 2>/dev/null | head -n 1)
  if [ -n "$SYS_ONNX" ]; then
    mkdir -p "$BUNDLE_DIR/lib"
    ln -sf "$SYS_ONNX" "$BUNDLE_DIR/lib/libonnxruntime.so.1" 2>/dev/null || sudo ln -sf "$SYS_ONNX" /usr/lib/aarch64-linux-gnu/libonnxruntime.so.1
  fi
fi

# If cage (kiosk compositor) is installed and no active desktop display is set,
# launch directly into full-screen touch kiosk mode.
if command -v cage >/dev/null 2>&1 && [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
  echo "Starting TBScreen inside Cage kiosk compositor..."
  exec cage -- "$EXECUTABLE"
else
  echo "Starting TBScreen on current display..."
  exec "$EXECUTABLE"
fi
