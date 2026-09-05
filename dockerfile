# Use the official n8n image as base. Pinned via a build-arg (resolved + cached
# for up to 1h in CI, see docker-build.yml) rather than a bare `FROM ...:latest`
# -- docker.n8n.io rate-limits the manifest-resolution HEAD request that a
# floating tag needs on every build, which was breaking CI when several builds
# ran in quick succession.
ARG BASE_IMAGE=docker.n8n.io/n8nio/n8n:latest
FROM ${BASE_IMAGE}

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

# ---- Pre-install n8n-nodes-playwright + configure browsers at BUILD time ----
# Installing via npm directly into an image-baked path (not n8n's own community-
# node auto-installer, which writes into the persistent /home/node/.n8n volume
# and re-runs the package's postinstall on every boot) means:
#   - the ~300-400MB Playwright browser download (if it happens at all - the
#     package's own postinstall script is skipped entirely below via
#     --ignore-scripts) happens once, at `docker build`, not on every container
#     boot/recreate
#   - we deterministically replace whatever browser directory structure the
#     package ships with a symlink to Alpine's own system Chromium/Firefox, in
#     the SAME immutable image layer -- no runtime process can ever write a
#     competing browser directory alongside it, so there's no race
#   - n8n loads it via N8N_CUSTOM_EXTENSIONS instead of the community-node
#     mechanism, so it never re-installs/re-downloads at boot
#
# --ignore-scripts skips BOTH the package's `preinstall` (`npx only-allow
# pnpm`, which would otherwise abort a plain `npm install`) and its `postinstall`
# (`setup-browsers.js`, which is what actually triggers the browser download
# on every plain `npm install`) - we don't need either since the published
# npm tarball already ships prebuilt `dist` files.
#
# Pinned to 0.2.16 to match what was already deployed when this fix was made -
# bump deliberately, not as a side effect of rebuilding this image.
#
# The symlink directory names (`chromium-alpine-system`, `firefox-alpine-
# system`) don't need to match any specific Playwright revision number -
# n8n-nodes-playwright's own getBrowserExecutablePath() just scans its browsers
# directory for any entry starting with "chromium"/"firefox" (see
# nodes/playwright/utils.js) - but they must be the ONLY entries present, which
# this build-time approach guarantees by construction.
RUN mkdir -p /opt/n8n-custom-nodes && \
    cd /opt/n8n-custom-nodes && \
    npm init -y >/dev/null 2>&1 && \
    npm install --ignore-scripts --omit=dev n8n-nodes-playwright@0.2.16 && \
    BROWSERS_DIR=/opt/n8n-custom-nodes/node_modules/n8n-nodes-playwright/dist/nodes/browsers && \
    rm -rf "$BROWSERS_DIR"/chromium-* "$BROWSERS_DIR"/chromium_headless_shell-* "$BROWSERS_DIR"/firefox-* "$BROWSERS_DIR"/webkit-* 2>/dev/null || true && \
    mkdir -p "$BROWSERS_DIR/chromium-alpine-system/chrome-linux" && \
    ln -s /usr/bin/chromium-browser "$BROWSERS_DIR/chromium-alpine-system/chrome-linux/chrome" && \
    mkdir -p "$BROWSERS_DIR/firefox-alpine-system/firefox" && \
    ln -s /usr/bin/firefox "$BROWSERS_DIR/firefox-alpine-system/firefox/firefox" && \
    chown -R node:node /opt/n8n-custom-nodes

# Switch back to node user
USER node

# Set working directory
WORKDIR /home/node/.n8n

# Create a volume for persistent data
VOLUME /home/node/.n8n

# Expose port 5678
EXPOSE 5678

# Set environment variables
ENV NODE_ENV=production
ENV N8N_CUSTOM_EXTENSIONS=/opt/n8n-custom-nodes

# Vestigial - n8n-nodes-playwright's own code doesn't actually read these (it
# resolves browsers relative to its own package dir, not via env vars) but
# harmless to leave set for any other tooling that might look for them.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PLAYWRIGHT_FIREFOX_EXECUTABLE_PATH=/usr/bin/firefox

# Chrome/Chromium flags for better headless performance
ENV CHROMIUM_FLAGS="--disable-software-rasterizer --disable-dev-shm-usage --disable-gpu --no-sandbox"

# Fix: Use just "start" instead of "n8n start" to prevent command duplication
CMD ["start"]
