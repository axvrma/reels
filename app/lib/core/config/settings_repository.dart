import 'package:hive_flutter/hive_flutter.dart';
import 'app_config.dart';

class SettingsRepository {
  static const String boxName = 'settingsData';
  static const String keyServerUrl = 'serverUrl';
  static const String keyIsLocalMode = 'isLocalMode';
  static const String keyLocalFolderPath = 'localFolderPath';

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

  String get serverUrl => _box.get(keyServerUrl, defaultValue: AppConfig.apiUrl);
  
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
}
