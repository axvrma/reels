# Vibes Application (Flutter)

A modern, high-performance TikTok-style video application built using Flutter. This app features vertical scrolling, likes, interactive notes, and fully seamless auto-play logic with background audio support. 

It is completely cross-platform and natively supports **Mobile (Android/iOS)**, **Web**, and **Desktop (macOS, Windows, Linux)**.

## Key Architecture Choices
- **Video Playback**: Powered by the highly performant `media_kit` library.
- **State & Local Storage**: Managed using `Hive` for blistering fast local caching and offline capabilities.
- **Routing**: Built using Flutter's native declarative routing architecture.

## Local Development

### Running the App
1. Install dependencies:
```bash
flutter pub get
```

2. Run on your desired platform:

**Web (Chrome):**
```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api
```

**Mobile:**
```bash
flutter run -d ios      # iOS Simulator / Device
flutter run -d android  # Android Emulator / Device
```

**Desktop:**
```bash
flutter run -d macos    # macOS
flutter run -d windows  # Windows
flutter run -d linux    # Linux
```
*(When running natively on Mobile/Desktop, ensure your backend server is accessible and update `API_URL` if needed, defaults to `http://localhost:3000/api`)*

## Production Deployment (Web)

For the Dockerized Web deployment, the app is compiled with specific build arguments to ensure it routes cleanly through the NGINX API Gateway:
```bash
flutter build web --base-href /app/ --dart-define=API_URL=/api
```
By defining `API_URL=/api`, the Flutter web application sends API calls to its own origin (e.g. `http://localhost/api`), gracefully bypassing any restrictive browser CORS policies.

*(See the `infra` folder for more details on running the entire stack!)*
