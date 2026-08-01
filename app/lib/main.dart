import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/config/settings_repository.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/auth/presentation/mode_selection_screen.dart';
import 'features/reels/presentation/video_feed_screen.dart';
import 'package:media_kit/media_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('videoData');
  await Hive.openBox('settingsData');
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0A0F),
  ));
  
  runApp(const VibesApp());
}

class VibesApp extends StatelessWidget {
  const VibesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        primaryColor: const Color(0xFFE040FB),
      ),
      home: const InitialRouteWidget(),
    );
  }
}

class InitialRouteWidget extends StatefulWidget {
  const InitialRouteWidget({super.key});

  @override
  State<InitialRouteWidget> createState() => _InitialRouteWidgetState();
}

class _InitialRouteWidgetState extends State<InitialRouteWidget> {
  final _settings = SettingsRepository();
  final _authRepo = AuthRepository();

  @override
  Widget build(BuildContext context) {
    if (!_settings.hasSeenWelcome) {
      return const WelcomeScreen();
    }
    
    if (!_settings.hasSelectedMode) {
      return const ModeSelectionScreen();
    }

    if (_settings.isLocalMode) {
      return const VideoFeedScreen();
    }

    return FutureBuilder<bool>(
      future: _authRepo.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data == true) {
          return const VideoFeedScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
