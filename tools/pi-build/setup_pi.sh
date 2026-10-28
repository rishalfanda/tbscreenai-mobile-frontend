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
  fontconfig \
  fonts-dejavu-core \
  fonts-liberation \
  fonts-roboto \
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

echo "=== Cleaning Up Incompatible System ONNX Runtime Symlinks ==="
# Remove any system-wide symlink that points to an older system onnxruntime (such as 1.21).
# TBScreen bundles its own matching ONNX Runtime (1.28.3) inside bundle/lib.
if [ -L /usr/lib/aarch64-linux-gnu/libonnxruntime.so.1 ] || [ -L /lib/aarch64-linux-gnu/libonnxruntime.so.1 ]; then
  echo "Removing incompatible system ONNX Runtime symlinks..."
  sudo rm -f /usr/lib/aarch64-linux-gnu/libonnxruntime.so.1 /lib/aarch64-linux-gnu/libonnxruntime.so.1 2>/dev/null || true
  sudo ldconfig 2>/dev/null || true
fi
echo "=== Configuring Library Search Path for TBScreen Bundle ==="
BUNDLE_LIB_DIR="$HOME/tbscreen-bundle/lib"
echo "$BUNDLE_LIB_DIR" | sudo tee /etc/ld.so.conf.d/tbscreen.conf >/dev/null
sudo ldconfig 2>/dev/null || true

echo "=== Configuring UTF-8 Locale ==="
sudo locale-gen en_US.UTF-8 2>/dev/null || true

echo "=== Updating Font Cache ==="
sudo fc-cache -f || true

echo "=== Setup Complete! ==="
echo "You can now run the app via ./tools/pi-build/run_pi.sh or cage ./dist/bundle/myapp"
