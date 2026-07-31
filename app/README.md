# Vibes Mobile & Web App (Flutter)

A modern, high-performance TikTok-style video application built using Flutter. This app features vertical scrolling, likes, interactive notes, and fully seamless auto-play logic with background audio support.

## Key Architecture Choices
- **Video Playback**: Powered by the highly performant `media_kit` library.
- **State & Local Storage**: Managed using `Hive` for blistering fast local caching and offline capabilities.
- **Routing**: Built using Flutter's native declarative routing architecture.

## Local Development (Mobile / Web)

### Running the App
1. Install dependencies:
```bash
flutter pub get
```

2. Run on Chrome (or a mobile emulator):
```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api
```
*(Make sure your backend server is running on port 3000)*

## Production Deployment (Web)

For the Dockerized Web deployment, the app is compiled with specific build arguments to ensure it routes cleanly through the NGINX API Gateway:
```bash
flutter build web --base-href /app/ --dart-define=API_URL=/api
```
By defining `API_URL=/api`, the Flutter web application sends API calls to its own origin (e.g. `http://localhost/api`), gracefully bypassing any restrictive browser CORS policies.

*(See the `infra` folder for more details on running the entire stack!)*
