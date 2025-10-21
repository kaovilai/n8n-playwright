# n8n-playwright Deployment Notes

## Key Learnings from Production Deployment

### Critical Fix: Command Override
The most important discovery during deployment was that the container fails to start with the error `Command "n8n" not found` if the CMD in the Dockerfile is `["n8n", "start"]`.

**Solution:** Override the command in docker-compose.yml to just `["start"]`:
```yaml
command: ["start"]
```

This prevents the docker-entrypoint.sh script from trying to execute `n8n "n8n start"` which causes the failure.

### Memory Requirements
- **Development**: 600-800MB recommended
- **Production with heavy browser usage**: 800MB-1GB recommended
- **PostgreSQL (if used)**: 200MB is sufficient

The container includes Chromium, Firefox, and WebKit browsers which increase memory usage compared to standard n8n.

### First Startup Behavior
On first startup, the container will:
1. Download Playwright browsers (~375MB total)
   - Chromium: ~174MB
   - Chromium Headless Shell: ~104MB
   - Firefox: ~97MB
   - WebKit: Included in image
2. Cache browsers in `/home/node/.cache/ms-playwright`
3. This process takes 1-2 minutes on first run
4. Subsequent startups are much faster

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

#### Service not responding immediately after startup
- Wait 1-2 minutes for browsers to download on first run
- Check progress: `docker logs -f n8n`

### System Requirements
- **Minimum RAM**: 2GB (system + containers)
- **Recommended RAM**: 4GB for comfortable operation
- **Disk Space**: ~1GB for container + browsers

### Security Notes
- Always change default passwords in production
- Set `N8N_ENCRYPTION_KEY` for credential encryption
- Use HTTPS in production (`N8N_PROTOCOL=https`)
- Configure `N8N_TRUST_PROXY=true` if behind a reverse proxy