# n8n-playwright Docker Image

n8n Docker image with Playwright browsers pre-installed for web automation workflows.

## Features

- Based on official n8n Alpine image for minimal size
- Includes Chromium and Firefox browsers compatible with Alpine Linux
- Playwright configured to use system-installed browsers
- Browser compatibility approach inspired by [alpine-chrome](https://github.com/jlandure/alpine-chrome) project

## Quick Start

### Using Docker Compose

```bash
docker-compose up -d
```

### Using Docker

```bash
docker build -t n8n-playwright .
docker run -d -p 5678:5678 -v n8n_data:/home/node/.n8n n8n-playwright
```

### Using Prebuilt Image

```bash
docker pull ghcr.io/kaovilai/n8n-playwright:latest
docker run -d -p 5678:5678 -v n8n_data:/home/node/.n8n ghcr.io/kaovilai/n8n-playwright:latest
```

## Technical Details

### Alpine Compatibility

This image solves the common "posix_fallocate64: symbol not found" error when running Playwright on Alpine Linux by:

1. Using system-installed browsers instead of Playwright's downloaded binaries
2. Including `chromium-swiftshader` for graphics compatibility
3. Setting environment variables to point Playwright to system browsers:
   - `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`
   - `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser`
   - `PLAYWRIGHT_FIREFOX_EXECUTABLE_PATH=/usr/bin/firefox`

### Included Browsers

- **Chromium**: Alpine's native Chromium package with SwiftShader
- **Firefox**: Both regular and ESR versions
- **WebKit**: Not included (requires glibc)

### Memory Requirements

- Minimum: 600MB
- Recommended: 800MB (for concurrent browser instances)
- With PostgreSQL: Add 200MB

## Environment Variables

```yaml
NODE_ENV: production
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD: 1
PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH: /usr/bin/chromium-browser
PLAYWRIGHT_FIREFOX_EXECUTABLE_PATH: /usr/bin/firefox
```

## Credits

Browser compatibility solution inspired by the [alpine-chrome](https://github.com/jlandure/alpine-chrome) project by Julien Landuré.

## License

MIT