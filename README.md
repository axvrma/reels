# Vibes

A modern, private media ecosystem featuring a TikTok-style vertical scrolling video player app, an Angular web dashboard, and a Node.js backend.

## Project Structure

This repository is organized into four main components:

- **`app/`**: A Flutter mobile application designed for a modern video viewing experience with vertical scrolling, likes, and notes. (Mobile & Web)
- **`dashboard/`**: An Angular-based web administration dashboard for content management and uploads.
- **`server/`**: A robust Node.js Express API using `better-sqlite3` and JWT authentication to securely serve private media and handle metadata.
- **`infra/`**: Docker and Docker Compose configuration files containing an API Gateway and deployment configurations.

## Getting Started

### Local Development Setup
If you wish to run the components independently for development, check the README inside each respective folder:
- [Backend Server (Node.js)](server/README.md)
- [Admin Dashboard (Angular)](dashboard/README.md)
- [Video Feed App (Flutter)](app/README.md)

### Deployment (Docker)
The easiest way to get the entire ecosystem running seamlessly is using the provided Docker Compose configuration in the `infra` folder. This uses an NGINX API Gateway to serve everything on a single port (Port 80).

Read the [Infra Deployment Guide](infra/README.md) for full instructions on how to deploy this stack from scratch.
