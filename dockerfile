# Use the official n8n image as base
FROM docker.io/n8nio/n8n:latest

# Install browser dependencies for Playwright
USER root

# Install dependencies with fallback for platform-specific packages
RUN apt-get update && \
    # Core dependencies that should be available on all platforms
    apt-get install -y --no-install-recommends \
    ca-certificates \
    fonts-liberation \
    fonts-noto-color-emoji \
    ttf-ubuntu-font-family \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libdbus-glib-1-2 \
    libdrm2 \
    libegl1 \
    libepoxy0 \
    libfontconfig1 \
    libfreetype6 \
    libgbm1 \
    libgdk-pixbuf2.0-0 \
    libgles2 \
    libglib2.0-0 \
    libgtk-3-0 \
    libgudev-1.0-0 \
    libharfbuzz0b \
    libhyphen0 \
    libnotify4 \
    libnspr4 \
    libnss3 \
    libopus0 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libpangoft2-1.0-0 \
    libpci3 \
    libpixman-1-0 \
    libsecret-1-0 \
    libwayland-client0 \
    libwayland-server0 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcb-dri3-0 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxkbcommon0 \
    libxrandr2 \
    libxrender1 \
    libxshmfence1 \
    libxslt1.1 \
    libxt6 \
    xvfb && \
    # Try to install version-specific packages, ignore if not available on current platform
    (apt-get install -y --no-install-recommends libicu66 || \
     apt-get install -y --no-install-recommends libicu67 || \
     apt-get install -y --no-install-recommends libicu72 || true) && \
    (apt-get install -y --no-install-recommends libjpeg8 || \
     apt-get install -y --no-install-recommends libjpeg-turbo8 || \
     apt-get install -y --no-install-recommends libjpeg62-turbo || true) && \
    (apt-get install -y --no-install-recommends libwebp6 || \
     apt-get install -y --no-install-recommends libwebp7 || true) && \
    (apt-get install -y --no-install-recommends libwebpdemux2 || true) && \
    (apt-get install -y --no-install-recommends libenchant1c2a || \
     apt-get install -y --no-install-recommends libenchant-2-2 || true) && \
    (apt-get install -y --no-install-recommends libevent-2.1-7 || \
     apt-get install -y --no-install-recommends libevent-2.1-6 || true) && \
    (apt-get install -y --no-install-recommends libvpx6 || \
     apt-get install -y --no-install-recommends libvpx7 || true) && \
    (apt-get install -y --no-install-recommends libpng16-16 || true) && \
    (apt-get install -y --no-install-recommends libwayland-egl1 || true) && \
    (apt-get install -y --no-install-recommends libwoff1 || true) && \
    # Cleanup
    rm -rf /var/lib/apt/lists/*

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
