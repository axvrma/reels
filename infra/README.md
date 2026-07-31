# Vibes Infra Deployment Guide

This folder contains the Docker Compose configurations required to deploy the complete Vibes ecosystem (App, Dashboard, and Server) smoothly on a local server.

## Architecture
The deployment uses a **Unified NGINX Reverse Proxy (API Gateway)** that sits on port `80`. This architecture securely routes traffic to internal Docker containers without exposing their native ports to the host machine:
- `http://<your-server-ip>/app/` -> Renders the Flutter Web App
- `http://<your-server-ip>/dashboard/` -> Renders the Angular Dashboard
- `http://<your-server-ip>/api/` -> Routes directly to the Node.js Backend Server

## Quick Start (Deploy from Scratch)

### Prerequisites
- Docker Engine installed.
- Docker Compose installed.

### 1. Build and Run the Stack
Navigate to the `infra` directory (if not already there) and run:
```bash
docker-compose up -d --build
```
This command will build the Flutter Web app, Angular Dashboard, and Node.js backend entirely from scratch inside Docker containers. The initial build might take a few minutes as it resolves dependencies for all three environments.

### 2. Verify Services
Check the status of your running containers:
```bash
docker-compose ps
```

You can view the logs in real-time if something fails:
```bash
docker-compose logs -f
```

### 3. Accessing the Application
Once the containers are running, simply open your browser and navigate to:
- **Web App**: `http://localhost/app/`
- **Admin Dashboard**: `http://localhost/dashboard/`

*(Replace `localhost` with your local server's IP address if accessing from another device on the network).*

## Data Persistence
The Node.js server utilizes SQLite and stores media files locally. In `docker-compose.yml`, a persistent Docker Volume named `vibes_data` is mounted to `/app/data` inside the server container.

This ensures that all your user data, uploaded videos, and metadata remain safely persisted even if you stop, rebuild, or destroy the containers!
