import 'package:hive_flutter/hive_flutter.dart';
import 'app_config.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class SettingsRepository {
  static const String boxName = 'settingsData';
  static const String keyServerUrl = 'serverUrl';
  static const String keyIsLocalMode = 'isLocalMode';
  static const String keyLocalFolderPath = 'localFolderPath';
  static const String keyIsDarkMode = 'isDarkMode';

  static const String keyHasSelectedMode = 'hasSelectedMode';
  static const String keyHasSeenWelcome = 'hasSeenWelcome';

  final Box _box;

  SettingsRepository() : _box = Hive.box(boxName);

  bool get hasSeenWelcome => _box.get(keyHasSeenWelcome, defaultValue: false);

  Future<void> setHasSeenWelcome(bool value) async {
    await _box.put(keyHasSeenWelcome, value);
  }

  bool get hasSelectedMode => _box.get(keyHasSelectedMode, defaultValue: false);

  Future<void> setHasSelectedMode(bool value) async {
    await _box.put(keyHasSelectedMode, value);
  }

  String get serverUrl {
    String url = _box.get(keyServerUrl, defaultValue: AppConfig.apiUrl);
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          if (url.contains('localhost')) {
            url = url.replaceAll('localhost', '10.0.2.2');
          } else if (url.contains('127.0.0.1')) {
            url = url.replaceAll('127.0.0.1', '10.0.2.2');
          }
        }
      } catch (_) {}
    }
    return url;
  }
  
  Future<void> setServerUrl(String url) async {
    await _box.put(keyServerUrl, url);
  }

  bool get isLocalMode => _box.get(keyIsLocalMode, defaultValue: false);

  Future<void> setLocalMode(bool isLocal) async {
    await _box.put(keyIsLocalMode, isLocal);
  }

  String? get localFolderPath => _box.get(keyLocalFolderPath);

  Future<void> setLocalFolderPath(String path) async {
    await _box.put(keyLocalFolderPath, path);
  }

  bool get isDarkMode => _box.get(keyIsDarkMode, defaultValue: true);

  Future<void> setIsDarkMode(bool isDark) async {
    await _box.put(keyIsDarkMode, isDark);
  }
}
