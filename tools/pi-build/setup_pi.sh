#!/usr/bin/env bash
# Run this setup script directly on your Raspberry Pi 5 to install runtime dependencies.
set -euo pipefail

echo "=== Installing TBScreen Runtime Dependencies on Raspberry Pi 5 ==="

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  libgtk-3-0 \
  libsecret-1-0 \
  libjsoncpp25 \
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

echo "=== Setup Complete! ==="
echo "You can now run the app via ./tools/pi-build/run_pi.sh or cage ./dist/bundle/myapp"

