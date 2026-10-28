# Raspberry Pi 5 (ARM64) Build & Deployment Guide

This guide describes how to build the TBScreen Flutter application into a native Linux ARM64 bundle and run it on a Raspberry Pi 5 (custom tablet / touchscreen kiosk).

---

## 1. Architecture Overview

- **Host Machine:** Windows 10/11 with Docker Desktop (WSL2 backend) or Linux x86_64.
- **Build Container:** Emulated `linux/arm64` container (`debian:trixie`) matching Raspberry Pi OS.
- **Output:** Native 64-bit ARM bundle in `dist/bundle/` (`myapp` binary, `lib/`, `data/`).
- **Target Device:** Raspberry Pi 5 running Raspberry Pi OS 64-bit (Debian Bookworm/Trixie) with touchscreen monitor and USB webcam.

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
└── lib/                           # Bundled native shared libraries
```

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

1. **Install Runtime Dependencies (Run Once):**
   ```bash
   bash ~/setup_pi.sh
   ```
   This installs GTK 3, GStreamer (for webcam capture), libsecret, and the `cage` kiosk compositor.

2. **Launch the Application:**
   - **Kiosk / Touchscreen Mode (Without full desktop):**
     ```bash
     cage -- ~/tbscreen-bundle/myapp
     ```
   - **Or using the launcher script:**
     ```bash
     bash ~/run_pi.sh ~/tbscreen-bundle
     ```

---

## 4. Hardware Notes

- **Camera & Webcam:**
  - Standard USB webcams mount as `/dev/video0`.
  - The `camera_desktop` plugin automatically accesses the webcam via GStreamer V4L2.
  - Ensure your user is in the `video` group (`sudo usermod -aG video $USER`).
- **Touchscreen & Virtual Keyboard:**
  - The built-in in-app on-screen virtual keyboard automatically slides up when any text field is tapped on the touch-only screen.
  - A physical USB keyboard can be plugged in simultaneously; pressing "Sembunyikan" docks the virtual keyboard away while preserving text focus.

