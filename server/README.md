# Vibes Backend Server (Node.js)

The core engine powering the Vibes application. It's built on Express.js and utilizes `better-sqlite3` for a lightning-fast, zero-configuration local database.

## Features
- **Video Storage & Streaming**: Uses native OS streams and FFmpeg to handle video uploads, thumbnails, and optimized streaming.
- **JWT Authentication**: Secures administrative dashboard routes and private endpoints.
- **SQLite Database**: Persists videos, categories, settings, and user metadata directly to disk with exceptional read performance.

## Local Development

### 1. Installation
Ensure you have Node.js 20+ installed.
```bash
npm install
```

### 2. Environment Variables
Copy the `.env.example` file (if available) or create a new `.env` file in the `server` directory:
```env
PORT=3000
HOST=0.0.0.0
DATA_DIR=./data
DATABASE_PATH=./data/sqlite.db
MAX_UPLOAD_MB=1024
CORS_ORIGIN=*
```

### 3. Initialize Admin Account
To create a fresh admin user to log into the Angular dashboard:
```bash
npm run create-admin
```

### 4. Run the Server
Start the server in development mode with automatic restarts:
```bash
npm run dev
```

## Production Deployment (Docker)

When deploying via the `infra` docker-compose stack, this server is bundled with FFmpeg and runs behind an NGINX API Gateway. A Docker volume (`vibes_data`) securely mounts to `/app/data` to persist your SQLite database and video uploads across container restarts.

*(See the `infra` folder for more details on running the entire stack!)*
