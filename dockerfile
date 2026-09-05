# N8N_VERSION / BASE_IMAGE must be declared here, before the FIRST FROM, to be
# global -- an ARG declared between FROM instructions is scoped to the
# preceding stage only and goes out of scope at the next FROM (Docker clears
# ARG scope at each stage boundary). Declaring them here, unused by the first
# stage, is fine; what matters is they're visible to the SECOND FROM below.
#
# Matches n8n's own official guidance (github.com/n8n-io/n8n-hosting README:
# "Pin a specific image tag for production rather than relying on
# `stable`/`latest`"). This also happens to be what caused this whole file's
# other fixes to be needed in the first place: an unpinned `:latest` silently
# bumped n8n's version, which re-triggered n8n-nodes-playwright's
# install/download path at boot. Pinning means that only happens when WE
# deliberately bump this ARG (Dependabot's docker ecosystem update will open a
# PR when a new release is out, giving a chance to test before merging,
# instead of it happening silently on every container recreate).
#
# 2.0.3 matches what was actually running when this pin was introduced -- bump
# deliberately.
#
# Uses Docker Hub (docker.io) rather than n8n's own docker.n8n.io -- confirmed
# identical digest for this pinned tag on both registries (they're mirrors of
# the same image), and docker.n8n.io was persistently rate-limiting CI builds
# (429 Too Many Requests) while Docker Hub wasn't. Docker Hub's `:latest` tag
# is NOT equivalent (confirmed to be a different, non-Alpine image) -- this
# only holds for the pinned version tag, which is exactly what we use.
ARG N8N_VERSION=2.0.3
ARG BASE_IMAGE=docker.io/n8nio/n8n:${N8N_VERSION}

# ---- Stage: chromium (Alpine base, independent of the n8n image/version) ----
# Installed into an isolated root (apk --root) rather than this stage's own OS,
# so it can be copied wholesale into the final stage below with `COPY --from`.
# This stage's cache key depends ONLY on this alpine tag + the apk package
# list -- NOT on N8N_VERSION -- so bumping the n8n version (which changes the
# FROM below) no longer forces re-running this whole apk install every time;
# BuildKit reuses this stage's cached layers as long as the package list here
# is unchanged. Firefox was dropped (Chromium-only) to shrink the image; if it
# comes back, add it as its own apk package + `firefox-alpine-system` symlink
# below (see git history for the removed pieces).
#
# NOTE: pin this to whatever Alpine minor version the n8n base image
# (N8N_VERSION above) actually uses -- confirmed 3.22 as of n8n 2.0.3. Musl/
# shared-library ABI is stable across nearby Alpine minors in practice, but if
# n8n's own Alpine version drifts noticeably from this pin, re-verify.
FROM alpine:3.22 AS chromium

RUN mkdir -p /chromium-root/etc/apk && \
    cp -r /etc/apk/* /chromium-root/etc/apk/ && \
    apk add --no-cache --root /chromium-root --initdb \
    chromium \
    chromium-swiftshader \
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
    tini && \
    # apk's own db/cache bookkeeping isn't useful merged into the final image
    rm -rf /chromium-root/etc/apk /chromium-root/lib/apk /chromium-root/var/cache/apk

# ---- Use the official n8n image as base ----
FROM ${BASE_IMAGE}

# Browser compatibility approach inspired by https://github.com/jlandure/alpine-chrome
# Uses system-installed Chromium with Playwright instead of downloading an
# incompatible (glibc) binary.
USER root

COPY --from=chromium /chromium-root/ /

# ---- Pre-install n8n-nodes-playwright + configure browsers at BUILD time ----
# Installing via npm directly into an image-baked path (not n8n's own community-
# node auto-installer, which writes into the persistent /home/node/.n8n volume)
# means:
#   - n8n loads it via N8N_CUSTOM_EXTENSIONS instead of the community-node
#     mechanism, so it never re-installs/re-downloads at boot as a result of
#     n8n's own community-node lifecycle
#   - we deterministically replace whatever browser directory structure the
#     package ships with a symlink to Alpine's own system Chromium, in the
#     SAME immutable image layer
#
# --ignore-scripts skips the package's `preinstall` (`npx only-allow pnpm`,
# which would otherwise abort a plain `npm install`) - we don't need it since
# the published npm tarball already ships prebuilt `dist` files.
#
# CRITICAL: --ignore-scripts does NOT stop n8n itself from invoking this
# package's browser-setup script -- confirmed live: n8n 2.0.3 runs
# dist/nodes/scripts/setup-browsers.js at EVERY startup regardless of how the
# package was installed (community-node or N8N_CUSTOM_EXTENSIONS), and that
# script unconditionally deletes the entire browsers directory and re-runs
# `npx playwright install` (chromium+firefox+webkit, ~400MB, incompatible
# glibc builds on this musl image) every single time -- completely undoing
# the symlink below on every container restart. Exactly how n8n invokes it
# wasn't determined (it isn't going through npm's own lifecycle, since
# --ignore-scripts had no effect on it), but the script self-invokes
# unconditionally at module load (`setupBrowsers().catch(...)` at file scope,
# not guarded by `require.main === module`), so overwriting its *content*
# with a no-op is a robust fix regardless of the exact call path. Also strips
# package.json's own `postinstall` field as defense in depth, in case
# whatever invokes this reads that field directly rather than executing the
# file by path.
#
# Pinned to 0.2.16 to match what was already deployed when this fix was made -
# bump deliberately, not as a side effect of rebuilding this image.
#
# The symlink directory name (`chromium-alpine-system`) doesn't need to match
# any specific Playwright revision number - n8n-nodes-playwright's own
# getBrowserExecutablePath() just scans its browsers directory for any entry
# starting with "chromium" (see nodes/playwright/utils.js) - but it must be
# the ONLY entry present, which this build-time approach guarantees by
# construction.
RUN mkdir -p /opt/n8n-custom-nodes && \
    cd /opt/n8n-custom-nodes && \
    npm init -y >/dev/null 2>&1 && \
    npm install --ignore-scripts --omit=dev n8n-nodes-playwright@0.2.16 && \
    PKG_DIR=/opt/n8n-custom-nodes/node_modules/n8n-nodes-playwright && \
    BROWSERS_DIR="$PKG_DIR/dist/nodes/browsers" && \
    rm -rf "$BROWSERS_DIR"/chromium-* "$BROWSERS_DIR"/chromium_headless_shell-* "$BROWSERS_DIR"/firefox-* "$BROWSERS_DIR"/webkit-* 2>/dev/null || true && \
    mkdir -p "$BROWSERS_DIR/chromium-alpine-system/chrome-linux" && \
    ln -s /usr/bin/chromium-browser "$BROWSERS_DIR/chromium-alpine-system/chrome-linux/chrome" && \
    printf '"use strict";\nObject.defineProperty(exports, "__esModule", { value: true });\n// Neutered at image build time -- see the RUN block above this file'"'"'s\n// installation for why. Browsers are baked in via the chromium-alpine-system\n// symlink; this used to unconditionally wipe that symlink and re-download\n// all three browsers (chromium/firefox/webkit) on every container start.\nexports.installBrowser = async function installBrowser() {};\n' > "$PKG_DIR/dist/nodes/scripts/setup-browsers.js" && \
    node -e "const fs=require('fs'); const p='$PKG_DIR/package.json'; const j=JSON.parse(fs.readFileSync(p)); delete j.scripts.postinstall; fs.writeFileSync(p, JSON.stringify(j,null,2));" && \
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

# Chrome/Chromium flags for better headless performance
ENV CHROMIUM_FLAGS="--disable-software-rasterizer --disable-dev-shm-usage --disable-gpu --no-sandbox"

# Fix: Use just "start" instead of "n8n start" to prevent command duplication
CMD ["start"]
