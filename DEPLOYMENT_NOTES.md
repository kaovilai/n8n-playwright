# n8n-playwright Deployment Notes

## Key Learnings from Production Deployment

### Critical Fixes

#### 1. Command Override
The most important discovery during deployment was that the container fails to start with the error `Command "n8n" not found` if the CMD in the Dockerfile is `["n8n", "start"]`.

**Solution:** Override the command in docker-compose.yml to just `["start"]`:
```yaml
command: ["start"]
```

This prevents the docker-entrypoint.sh script from trying to execute `n8n "n8n start"` which causes the failure.

#### 2. Browser Compatibility on Alpine Linux
n8n-nodes-playwright downloads browsers compiled with glibc which are incompatible with Alpine's musl libc, causing "posix_fallocate64: symbol not found" errors.

**Solution:**
- Install system browsers (chromium, firefox) from Alpine packages
- Install `n8n-nodes-playwright` at **build time** (`--ignore-scripts`, into
  `/opt/n8n-custom-nodes`) instead of letting n8n's own community-node
  auto-installer pull it into the persistent `/home/node/.n8n` volume at
  container boot, and load it via `N8N_CUSTOM_EXTENSIONS` instead
- Replace the downloaded browser directory with a symlink to Alpine's system
  Chromium/Firefox in that same build-time image layer

This used to be done with a runtime entrypoint script (`configure-browsers.sh`)
that raced n8n's own boot sequence to overwrite whatever Playwright had just
downloaded with a symlink to the system browser -- whichever one a directory
listing happened to return first would win, non-deterministically. Baking
everything in at build time removes the race (and the download) entirely. See
the `dockerfile`'s own comments for the full explanation, and the
`n8n-nodes-playwright` version this is pinned to.

### Memory Requirements
- **Development**: 600-800MB recommended
- **Production with heavy browser usage**: 800MB-1GB recommended
- **PostgreSQL (if used)**: 200MB is sufficient

The container includes Chromium, Firefox, and WebKit browsers which increase memory usage compared to standard n8n.

### First Startup Behavior
Browsers and `n8n-nodes-playwright` are baked into the image at build time (see
the "Browser Compatibility on Alpine Linux" section above) -- there is no
browser download or community-node install at container startup anymore.
Startup time is the same as a plain n8n container; the only extra image size
(compared to stock n8n) is Alpine's Chromium/Firefox packages and the
pre-installed node, not a browser download.

### Docker Compose Configuration

#### Minimal Configuration (Development)
```yaml
services:
  n8n:
    build: .
    container_name: n8n
    command: ["start"]  # Critical!
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    restart: unless-stopped
```

#### Production Configuration
- Add PostgreSQL for data persistence
- Set memory limits to prevent resource exhaustion
- Configure environment variables for security
- Use prebuilt image from GitHub Container Registry

### Using Prebuilt Image
Instead of building locally, you can use:
```yaml
image: ghcr.io/kaovilai/n8n-playwright:latest
```

### Troubleshooting

#### Container keeps restarting with "Command not found"
- Ensure `command: ["start"]` is set in docker-compose.yml
- Check logs: `docker logs n8n`

#### High memory usage
- Normal for browser automation workflows
- Consider increasing memory limits if running multiple browser instances
- Monitor with: `docker stats n8n`

### System Requirements
- **Minimum RAM**: 2GB (system + containers) -- this is the container's own
  documented minimum; it has been observed running (with real, if tight,
  headroom concerns) on hosts with as little as 1.6GB total RAM shared across
  other services. Below 2GB, watch for OOM under concurrent browser workflows.
- **Recommended RAM**: 4GB for comfortable operation
- **Disk Space**: ~1GB for container + browsers

### Security Notes
- Always change default passwords in production
- Set `N8N_ENCRYPTION_KEY` for credential encryption
- Use HTTPS in production (`N8N_PROTOCOL=https`)
- Configure `N8N_TRUST_PROXY=true` if behind a reverse proxy
