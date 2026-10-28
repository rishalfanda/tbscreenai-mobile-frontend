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

# Clean up any incompatible system ONNX Runtime symlinks (e.g. Debian 1.21 packages)
if [ -L /usr/lib/aarch64-linux-gnu/libonnxruntime.so.1 ] || [ -L /lib/aarch64-linux-gnu/libonnxruntime.so.1 ]; then
  sudo rm -f /usr/lib/aarch64-linux-gnu/libonnxruntime.so.1 /lib/aarch64-linux-gnu/libonnxruntime.so.1 2>/dev/null || true
  sudo ldconfig 2>/dev/null || true
fi

# Ensure libonnxruntime.so.1 is present in the bundle lib directory
if [ -f "$BUNDLE_DIR/lib/libonnxruntime.so" ] && [ ! -e "$BUNDLE_DIR/lib/libonnxruntime.so.1" ]; then
  echo "Linking bundle libonnxruntime.so -> libonnxruntime.so.1..."
  ln -sf libonnxruntime.so "$BUNDLE_DIR/lib/libonnxruntime.so.1"
fi
# Ensure bundle's lib directory is in LD_LIBRARY_PATH for sub-dependencies
export LD_LIBRARY_PATH="$BUNDLE_DIR/lib:${LD_LIBRARY_PATH:-}"

# Detect display server when launching from SSH
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
  USER_RUNTIME="/run/user/$(id -u)"
  if [ -S "$USER_RUNTIME/wayland-0" ]; then
    export XDG_RUNTIME_DIR="$USER_RUNTIME"
    export WAYLAND_DISPLAY="wayland-0"
  elif [ -e "/tmp/.X11-unix/X0" ]; then
    export DISPLAY=":0"
  fi
fi

# If a display is available, launch directly onto it
if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
  echo "Starting TBScreen on active display (${WAYLAND_DISPLAY:-$DISPLAY})..."
  exec "$EXECUTABLE"
elif command -v cage >/dev/null 2>&1; then
  echo "No active display found; starting TBScreen inside Cage kiosk compositor..."
  exec cage -- "$EXECUTABLE"
else
  echo "Error: No display server found (WAYLAND_DISPLAY or DISPLAY not set) and 'cage' is not installed."
  echo "If launching over SSH with an active desktop on the screen, try:"
  echo "  WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/\$(id -u) $EXECUTABLE"
  exit 1
fi
