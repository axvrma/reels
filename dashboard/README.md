# Vibes Admin Dashboard (Angular)

This is the central web dashboard for managing the Vibes platform. Built with Angular 18, it allows platform administrators to upload videos, view platform statistics, and configure platform settings.

## Local Development

To run the Angular application locally in a development environment:

1. Install dependencies:
```bash
npm install
```

2. Start the development server:
```bash
npm run start
```
The application will be accessible at `http://localhost:4200/`. The development server is usually configured to proxy local `/api` calls to `http://localhost:3000` via a `proxy.conf.json` file.

## Production Deployment (Docker)

When deploying via the `infra` docker-compose stack, the application is built using:
```bash
npm run build -- --base-href /dashboard/
```

This ensures that Angular expects to be served from `http://<server-ip>/dashboard/`. The deployment architecture seamlessly routes all API requests back to the Node.js backend through a central NGINX Gateway, avoiding any CORS constraints.

*(See the `infra` folder for more details on running the entire stack!)*
