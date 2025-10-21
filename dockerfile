# Use the official n8n image as base
FROM docker.n8n.io/n8nio/n8n:latest

# Browser compatibility approach inspired by https://github.com/jlandure/alpine-chrome
# Uses system-installed browsers with Playwright instead of downloading incompatible binaries

# Install browser dependencies for Playwright with Alpine compatibility
USER root

# Install Chromium with SwiftShader for graphics compatibility
# and Firefox with all necessary dependencies
RUN apk add --no-cache \
    chromium \
    chromium-swiftshader \
    firefox \
    firefox-esr \
    nss \
    freetype \
    freetype-dev \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    font-noto-emoji \
    font-liberation \
    ttf-dejavu \
    # Additional dependencies for browser automation
    opus \
    libwebp \
    enchant2 \
    eudev-libs \
    libsecret \
    hyphen \
    gdk-pixbuf \
    mesa-egl \
    libnotify \
    libxslt \
    libevent \
    mesa-gles \
    libvpx \
    libxcomposite \
    at-spi2-core \
    cairo \
    libepoxy \
    fontconfig \
    mesa-gbm \
    glib \
    icu-libs \
    libjpeg-turbo \
    pango \
    pixman \
    libpng \
    wayland-libs-client \
    wayland-libs-egl \
    wayland-libs-server \
    libx11 \
    dbus-glib \
    libxt \
    libxcb \
    libxext \
    libxfixes \
    pciutils-libs \
    alsa-lib \
    libxi \
    libxkbcommon \
    libxrandr \
    libxrender \
    libxshmfence \
    gtk+3.0 \
    xvfb \
    dbus \
    udev \
    # Process management
    tini

# Pre-create browsers directory structure to prevent n8n-nodes-playwright from downloading
# The postinstall script checks for this directory and skips download if it exists
RUN mkdir -p /home/node/.cache/ms-playwright && \
    # Create dummy browser directories to satisfy the setup script
    mkdir -p /home/node/.cache/ms-playwright/chromium-1140 && \
    mkdir -p /home/node/.cache/ms-playwright/firefox-1491 && \
    mkdir -p /home/node/.cache/ms-playwright/webkit-2104 && \
    # Also pre-create the n8n nodes directory where the package expects browsers
    mkdir -p /home/node/.n8n/nodes/node_modules/n8n-nodes-playwright/dist/nodes/browsers && \
    # Create symlinks to system browsers in the expected locations
    ln -s /usr/bin/chromium-browser /home/node/.cache/ms-playwright/chromium-1140/chrome-linux && \
    ln -s /usr/bin/firefox /home/node/.cache/ms-playwright/firefox-1491/firefox && \
    # Set proper ownership
    chown -R node:node /home/node/.cache /home/node/.n8n

# Switch back to node user
USER node

# Set working directory
WORKDIR /home/node/.n8n

# Create a volume for persistent data
VOLUME /home/node/.n8n

# Expose port 5678
EXPOSE 5678

# Set environment variables for Playwright to use system browsers
ENV NODE_ENV=production
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PLAYWRIGHT_FIREFOX_EXECUTABLE_PATH=/usr/bin/firefox

# Chrome/Chromium flags for better headless performance
ENV CHROMIUM_FLAGS="--disable-software-rasterizer --disable-dev-shm-usage --disable-gpu --no-sandbox"

# Fix: Use just "start" instead of "n8n start" to prevent command duplication
CMD ["start"]