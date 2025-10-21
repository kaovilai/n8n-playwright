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

# Switch back to node user
USER node

# Set working directory
WORKDIR /home/node/.n8n

# Create a volume for persistent data
VOLUME /home/node/.n8n

# Copy the browser configuration script
COPY --chown=node:node configure-browsers.sh /usr/local/bin/configure-browsers.sh
RUN chmod +x /usr/local/bin/configure-browsers.sh

# Expose port 5678
EXPOSE 5678

# Set environment variables for Playwright to use system browsers
ENV NODE_ENV=production
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PLAYWRIGHT_FIREFOX_EXECUTABLE_PATH=/usr/bin/firefox

# Chrome/Chromium flags for better headless performance
ENV CHROMIUM_FLAGS="--disable-software-rasterizer --disable-dev-shm-usage --disable-gpu --no-sandbox"

# Override the entrypoint to run our configuration script
ENTRYPOINT ["/usr/local/bin/configure-browsers.sh"]

# Fix: Use just "start" instead of "n8n start" to prevent command duplication
CMD ["start"]