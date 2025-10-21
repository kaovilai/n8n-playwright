#!/bin/sh
# Configure Playwright to use system-installed browsers on Alpine Linux

# Function to setup browser symlinks in background
setup_browsers_async() {
    # Wait a bit for n8n to start
    sleep 10

    echo "Setting up browser symlinks in background..."

    # Create the browsers directory structure if it doesn't exist
    BROWSERS_DIR="/home/node/.n8n/nodes/node_modules/n8n-nodes-playwright/dist/nodes/browsers"

    # Wait for n8n-nodes-playwright to be installed
    counter=0
    while [ ! -d "/home/node/.n8n/nodes/node_modules/n8n-nodes-playwright" ]; do
        echo "Waiting for n8n-nodes-playwright to be installed..."
        sleep 5
        counter=$((counter + 1))
        if [ $counter -gt 60 ]; then
            echo "Timeout waiting for n8n-nodes-playwright"
            break
        fi
    done

    if [ -d "/home/node/.n8n/nodes/node_modules/n8n-nodes-playwright" ]; then
        # Create browsers directory if needed
        mkdir -p "$BROWSERS_DIR"

        # Remove any downloaded browsers and create symlinks
        rm -rf "$BROWSERS_DIR/chromium-"* 2>/dev/null
        rm -rf "$BROWSERS_DIR/firefox-"* 2>/dev/null

        # Create symlinks for chromium (version 1194 is what n8n-nodes-playwright expects)
        mkdir -p "$BROWSERS_DIR/chromium-1194/chrome-linux"
        ln -sf /usr/bin/chromium-browser "$BROWSERS_DIR/chromium-1194/chrome-linux/chrome"
        echo "Created symlink for Chromium"

        # Create symlinks for firefox (version 1491 is what n8n-nodes-playwright expects)
        mkdir -p "$BROWSERS_DIR/firefox-1491/firefox"
        ln -sf /usr/bin/firefox "$BROWSERS_DIR/firefox-1491/firefox/firefox"
        echo "Created symlink for Firefox"

        # Also populate the cache directory to prevent downloads
        CACHE_DIR="/home/node/.cache/ms-playwright"
        mkdir -p "$CACHE_DIR"

        rm -rf "$CACHE_DIR/chromium-"* 2>/dev/null
        rm -rf "$CACHE_DIR/firefox-"* 2>/dev/null

        mkdir -p "$CACHE_DIR/chromium-1194/chrome-linux"
        ln -sf /usr/bin/chromium-browser "$CACHE_DIR/chromium-1194/chrome-linux/chrome"

        mkdir -p "$CACHE_DIR/firefox-1491/firefox"
        ln -sf /usr/bin/firefox "$CACHE_DIR/firefox-1491/firefox/firefox"

        echo "Browser configuration complete!"
    fi
}

# Check if we're in a container with system browsers
if [ -f /usr/bin/chromium-browser ] && [ -f /usr/bin/firefox ]; then
    echo "System browsers detected, will configure Playwright to use them..."

    # Run browser setup in background
    setup_browsers_async &
else
    echo "System browsers not detected, Playwright will download its own browsers"
fi

# Start n8n
exec n8n "$@"