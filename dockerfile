# Use the official n8n image as base
FROM docker.n8n.io/n8nio/n8n:latest

# Install WebKit and Chromium dependencies for Playwright
USER root
RUN apk add --no-cache \
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
    freetype \
    mesa-gbm \
    glib \
    harfbuzz \
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
    font-liberation \
    font-noto-emoji \
    ttf-dejavu \
    chromium \
    firefox \
    nss \
    xvfb \
    dbus \
    udev

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
