FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

# 1. Divert ldconfig.real to ensure immunity from QEMU emulation crashes
RUN dpkg-divert --local --rename --add /usr/sbin/ldconfig.real \
    && ln -s /bin/true /usr/sbin/ldconfig.real

# 2. Install native compilation tools and libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    libglu1-mesa \
    liblzma-dev \
    libsecret-1-dev \
    libjsoncpp-dev \
    libsqlite3-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-good \
    && rm -rf /var/lib/apt/lists/*

# 3. Restore ldconfig.real and refresh dynamic linker cache
RUN rm -f /usr/sbin/ldconfig.real \
    && dpkg-divert --local --rename --remove /usr/sbin/ldconfig.real \
    && /usr/sbin/ldconfig || true

# Install Flutter SDK (stable channel)
RUN git clone -b stable --depth 1 https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && git config --global --add safe.directory '*' \
    && flutter config --no-analytics \
    && flutter config --enable-linux-desktop \
    && flutter precache --linux

# Create build directory
WORKDIR /app

# Copy entrypoint build script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

