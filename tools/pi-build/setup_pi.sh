#!/usr/bin/env bash
# Run this setup script directly on your Raspberry Pi 5 to install runtime dependencies.
set -euo pipefail

echo "=== Installing TBScreen Runtime Dependencies on Raspberry Pi 5 ==="

sudo apt-get update

# Determine jsoncpp package name (Debian 12 Bookworm uses libjsoncpp25, Debian 13 Trixie uses libjsoncpp26)
JSONCPP_PKG="libjsoncpp26"
if ! apt-cache show "$JSONCPP_PKG" >/dev/null 2>&1; then
  JSONCPP_PKG="libjsoncpp25"
  if ! apt-cache show "$JSONCPP_PKG" >/dev/null 2>&1; then
    JSONCPP_PKG="libjsoncpp-dev"
  fi
fi

echo "Selected JSON library: $JSONCPP_PKG"

sudo apt-get install -y --no-install-recommends \
  libgtk-3-0 \
  libsecret-1-0 \
  "$JSONCPP_PKG" \
  libsqlite3-0 \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-libav \
  gstreamer1.0-tools \
  gstreamer1.0-gl \
  libv4l-0 \
  cage

echo "=== Configuring Video & GPU Access Permissions ==="
sudo usermod -aG video,render "$USER" || true

echo "=== Configuring ONNX Runtime Symlinks ==="
SYS_ONNX=$(find /usr/lib/aarch64-linux-gnu -name "libonnxruntime.so.1*" 2>/dev/null | head -n 1)
if [ -n "$SYS_ONNX" ] && [ ! -f /usr/lib/aarch64-linux-gnu/libonnxruntime.so.1 ]; then
  echo "Linking $SYS_ONNX -> /usr/lib/aarch64-linux-gnu/libonnxruntime.so.1"
  sudo ln -sf "$SYS_ONNX" /usr/lib/aarch64-linux-gnu/libonnxruntime.so.1
  sudo ldconfig
fi

echo "=== Setup Complete! ==="
echo "You can now run the app via ./tools/pi-build/run_pi.sh or cage ./dist/bundle/myapp"
