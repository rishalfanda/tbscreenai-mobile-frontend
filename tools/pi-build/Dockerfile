FROM debian:trixie

ARG FLUTTER_VERSION=3.47.1

# Install toolchain and native library headers for GTK 3, GStreamer (camera_desktop),
# libsecret (flutter_secure_storage), jsoncpp, and SQLite3.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils zip file rsync \
      clang cmake ninja-build pkg-config \
      libgtk-3-dev liblzma-dev libstdc++-14-dev \
      libsecret-1-dev libjsoncpp-dev libsqlite3-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
      gstreamer1.0-plugins-good \
    && rm -rf /var/lib/apt/lists/*

# Clone the pinned Flutter SDK matching the host development environment
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
      https://github.com/flutter/flutter.git /opt/flutter

ENV PATH="/opt/flutter/bin:${PATH}"

RUN git config --global --add safe.directory /opt/flutter \
 && flutter config --no-analytics --enable-linux-desktop \
 && flutter precache --linux \
 && flutter --version

