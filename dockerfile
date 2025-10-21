# Use the official n8n image as base
FROM docker.io/n8nio/n8n:latest

# Install Playwright dependencies for Alpine Linux
# Note: n8n uses Alpine Linux (not Debian), so we use apk instead of apt-get
# Only Chromium is supported on Alpine due to glibc/musl incompatibility
USER root

# Install Chromium and required dependencies for Playwright
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    freetype-dev \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    font-noto-emoji \
    wqy-zenhei \
    libstdc++ \
    libgcc \
    libx11 \
    libxcomposite \
    libxdamage \
    libxext \
    libxfixes \
    libxrandr \
    mesa-gbm \
    gtk+3.0 \
    pango \
    cairo \
    glib \
    alsa-lib \
    at-spi2-core \
    cups-libs \
    libdrm \
    expat \
    libxkbcommon \
    wayland-libs-client \
    wayland-libs-server

# Set environment variables to use system Chromium
# This tells Playwright to skip downloading browsers and use the system-installed Chromium
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser

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

# Use the default n8n command to start the application
CMD ["n8n", "start"]
