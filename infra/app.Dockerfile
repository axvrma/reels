# Stage 1: Build the Flutter web app
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app
COPY . .
# Get dependencies and build for web
RUN flutter pub get

# Define the base href and API URL for the deployment
ARG API_URL=/api
RUN flutter build web --base-href /app/ --dart-define=API_URL=$API_URL

# Stage 2: Serve the app with NGINX
FROM nginx:alpine

# Copy the built web app from the builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

# Update nginx configuration to handle routing if necessary (SPA behavior)
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html index.htm; \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
