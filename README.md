# Vibes

A modern, private media ecosystem featuring a TikTok-style vertical scrolling video player app, an Angular web dashboard, and a Node.js backend.

## Project Structure

This repository is organized into four main components:

- **`app/`**: A Flutter mobile application designed for a modern video viewing experience with vertical scrolling, likes, and notes.
- **`dashboard/`**: An Angular-based web administration dashboard for content management and uploads.
- **`server/`**: A robust Node.js Express API using `better-sqlite3` and JWT authentication to securely serve private media and handle metadata.
- **`infra/`**: Docker and Docker Compose configuration files for simplified, consistent deployment.

## Getting Started

### Prerequisites

To run this project locally without Docker, ensure you have the following installed:
- [Node.js](https://nodejs.org/) & npm
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Docker & Docker Compose](https://www.docker.com/) (for containerized deployment)

---

### Running via Docker (Recommended)

The easiest way to get the backend and dashboard running is using the provided Docker Compose configuration.

1. Navigate to the `infra` directory:
   ```bash
   cd infra
   ```
2. Build and start the containers:
   ```bash
   docker-compose up -d --build
   ```

**Services started:**
- **Server API**: Available at `http://localhost:3000`
- **Dashboard**: Available at `http://localhost:80` (or your mapped port)
- **App (Web)**: Available at `http://localhost:8080` (or your mapped port)
- *Note: Application data (like sqlite database and media files) is persisted in a local Docker volume (`vibes_data`).*

---

### Local Development Setup

If you wish to run the components independently for development, follow the instructions below:

#### 1. Server API
The backend requires some initial setup, including environment variables.
```bash
cd server
npm install

# (Optional) Check .env.example to set up your local .env file
# Provide the necessary config (like JWT_SECRET, ports, etc.)

# Run in development mode with hot-reloading
npm run dev
```
> *You can also create an admin user using `npm run create-admin` if configured.*

#### 2. Angular Dashboard
```bash
cd dashboard
npm install

# Start the Angular development server
npm run start
```
The dashboard will be available at `http://localhost:4200` (default) or the port specified by Angular.

#### 3. Flutter App
```bash
cd app
flutter pub get

# Run on an attached device or emulator
flutter run
```
