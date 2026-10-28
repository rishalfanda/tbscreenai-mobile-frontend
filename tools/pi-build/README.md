# Raspberry Pi 5 (ARM64) Build & Deployment Guide

This guide describes how to build the TBScreen Flutter application into a native Linux ARM64 bundle and run it on a Raspberry Pi 5 (custom tablet / touchscreen kiosk).

---

## 1. Architecture Overview

- **Host Machine:** Windows 10/11 with Docker Desktop (WSL2 backend) or Linux x86_64.
- **Build Container:** Emulated `linux/arm64` container (`debian:trixie`) matching Raspberry Pi OS.
- **Output:** Native 64-bit ARM bundle in `dist/bundle/` (`myapp` binary, `lib/`, `data/`).
- **Target Device:** Raspberry Pi 5 running Raspberry Pi OS 64-bit (Debian Bookworm/Trixie) with touchscreen monitor and USB webcam.
- **Bundled Runtimes:** Includes official Microsoft ONNX Runtime 1.28.3, Flutter engine, GTK 3, and GStreamer camera pipeline.

---

## 2. Prerequisites

1. **Docker Desktop on Windows:**
   - Enable the WSL 2 based engine in Docker Desktop Settings.
   - Multi-platform emulation is supported out of the box via QEMU / binfmt in Docker Desktop.
2. **Flutter Code Generation:**
   - Run drift code generation before building:
     ```sh
     dart run build_runner build
     ```
   - Ensure generated `.g.dart` files are committed.

---

## 3. Step-by-Step Instructions

### Step 1: Build the Docker Builder Image (Run Once)

From the project root, build the ARM64 builder container image:

**On Windows (PowerShell):**
```powershell
docker build --platform linux/arm64 --build-arg FLUTTER_VERSION=3.47.1 -t tbscreen-builder tools/pi-build
```

**On Linux / macOS / WSL (Bash):**
```sh
docker build --platform linux/arm64 --build-arg FLUTTER_VERSION=3.47.1 -t tbscreen-builder tools/pi-build
```

*(Note: The first build will take several minutes to download packages and clone the Flutter SDK under ARM64 emulation. Subsequent builds will reuse cached layers).*

---

### Step 2: Compile the ARM64 Release Bundle

**On Windows (PowerShell):**
```powershell
.\tools\pi-build\build.ps1
```

You can optionally override environment parameters:
```powershell
.\tools\pi-build\build.ps1 -Flavor demo -AppEnv demo -ApiBaseUrl "https://3rgcn2lx-8000.asse.devtunnels.ms/v1"
```

**On Linux / macOS / WSL (Bash):**
```sh
./tools/pi-build/build.sh
```

Or with custom parameters:
```sh
FLAVOR=demo APP_ENV=demo API_BASE_URL="https://3rgcn2lx-8000.asse.devtunnels.ms/v1" ./tools/pi-build/build.sh
```

The compiled output will be generated in:
```
dist/bundle/
├── myapp                          # Native ARM64 executable
├── data/                          # Flutter assets, ICU data, fonts
└── lib/                           # Bundled native shared libraries (ONNX Runtime, SQLite, Plugins)
```

The build script automatically ensures the matching `libonnxruntime.so.1` and library dependencies are bundled in `dist/bundle/lib/`.

You can verify the architecture if `file` is available:
```sh
file dist/bundle/myapp
# Expected output: ELF 64-bit LSB executable, ARM aarch64 ...
```

---

### Step 3: Transfer to Raspberry Pi 5

Copy the `dist/bundle` directory to your Raspberry Pi 5 using `scp` or a USB flash drive:

```sh
scp -r dist/bundle pi@<RASPBERRY_PI_IP>:~/tbscreen-bundle
```

Copy the helper scripts as well:
```sh
scp tools/pi-build/setup_pi.sh tools/pi-build/run_pi.sh pi@<RASPBERRY_PI_IP>:~/
```

---

### Step 4: Run on Raspberry Pi 5

SSH into the Raspberry Pi 5 (or open a terminal):

1. **Install Runtime Dependencies & Fonts (Run Once):**
   ```bash
   bash ~/setup_pi.sh
   ```
   This script performs the following setup:
   - Installs GTK 3, GStreamer (for webcam capture), libsecret, and `cage` kiosk compositor.
   - Installs TrueType fonts (`fonts-dejavu-core`, `fonts-liberation`, `fonts-roboto`) and refreshes the font cache so text characters render properly.
   - Cleans up incompatible system ONNX Runtime packages (e.g. Debian 1.21 packages) that conflict with ONNX Runtime 1.28.3.
   - Registers `~/tbscreen-bundle/lib` in `/etc/ld.so.conf.d/tbscreen.conf`.
   - Adds current user to `video` and `render` groups.

2. **Launch the Application:**
   - **Recommended — Using the launcher script (Auto-detects display or Cage):**
     ```bash
     bash ~/run_pi.sh ~/tbscreen-bundle
     ```
   - **Kiosk / Touchscreen Mode (CLI / Console mode without full desktop):**
     ```bash
     cage -- ~/tbscreen-bundle/myapp
     ```
   - **From SSH onto an active Desktop screen:**
     ```bash
     WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/$(id -u) ~/tbscreen-bundle/myapp
     ```

---

## 4. Operational & Troubleshooting Notes

### Exiting Cage Kiosk
Cage is designed as a kiosk compositor that manages a single full-screen application:
- **From SSH:** Press `Ctrl + C` in the running terminal session, or run `killall cage`.
- **From physical keyboard:** Switch to a text console with `Ctrl + Alt + F2` (or `F1`-`F6`).
- **Application Exit:** Closing the Flutter application will automatically terminate Cage.

### Shared Library Resolution (`libonnxruntime.so.1`)
- TBScreen bundles official Microsoft ONNX Runtime 1.28.3 in `~/tbscreen-bundle/lib/`.
- `setup_pi.sh` registers `~/tbscreen-bundle/lib` in `/etc/ld.so.conf.d/tbscreen.conf`.
- `run_pi.sh` exports `LD_LIBRARY_PATH="$BUNDLE_DIR/lib:${LD_LIBRARY_PATH:-}"` for reliable sub-dependency loading across plugins.

### Font Rendering ("Tofu" Square Boxes)
- If characters render as squares, verify font packages and font cache:
  ```bash
  sudo apt-get install -y fontconfig fonts-dejavu-core fonts-liberation fonts-roboto
  sudo fc-cache -f
  ```

---

## 5. Hardware Notes

- **Camera & Webcam:**
  - Standard USB webcams mount as `/dev/video0`.
  - The `camera_desktop` plugin automatically accesses the webcam via GStreamer V4L2.
  - Ensure your user is in the `video` group (`sudo usermod -aG video $USER`).
- **Touchscreen & In-App Virtual Keyboard:**
  - The built-in in-app on-screen virtual keyboard automatically slides up when any text field is tapped on the touch-only screen.
  - Tapping keys on the virtual keyboard preserves active text field focus using `TextFieldTapRegion`.
  - A physical USB keyboard can be plugged in simultaneously; pressing "Sembunyikan" docks the virtual keyboard away while preserving text focus.
