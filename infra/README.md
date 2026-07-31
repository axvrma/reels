# Infra Setup

This directory contains the necessary Dockerfiles and docker-compose configurations to deploy the private media platform on a Raspberry Pi (ARM64).

## Prerequisites

1. **Docker & Docker Compose**: Ensure they are installed on your Raspberry Pi.
2. **FFmpeg**: The `server.Dockerfile` installs `ffmpeg` automatically within the Alpine Node container.
3. **External SSD**: Mount your SSD to a known directory, for example, `/mnt/ssd`.

## Deployment

1. Make sure to update your `docker-compose.yml` volumes to map to your SSD mount point instead of the default local volume if needed. E.g.:
   ```yaml
   volumes:
     vibes_data:
       driver: local
       driver_opts:
         type: none
         o: bind
         device: /mnt/ssd/vibes_data
   ```

2. Start the services:
   ```bash
   docker compose up -d --build
   ```

## Tailscale Serve Configuration

We want to expose the services privately over Tailscale without using Funnel (which makes it public). Tailscale Serve allows us to route traffic to the local container securely over your tailnet.

1. Install Tailscale on the Raspberry Pi and authenticate.
2. To serve the API, the Dashboard, and the Flutter Web App over Tailscale:

```bash
# Serve the NGINX dashboard on HTTPS
tailscale serve --bg 80

# Serve the Flutter Web App on HTTPS under /app
tailscale serve --bg --set-path /app http://127.0.0.1:8080/

# Serve the Express API on HTTPS under /api
tailscale serve --bg --set-path /api http://127.0.0.1:3000/api
```

This ensures everything is served securely on your private Tailscale network. Your tailnet URL (e.g., `https://raspberrypi.tailnet-xyz.ts.net`) will serve the Angular app at `/`, the Flutter app at `/app`, and the API at `/api`.
