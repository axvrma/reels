import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/config/settings_repository.dart';

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthRepository({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<String?> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final webBrowserInfo = await deviceInfo.webBrowserInfo;
        return webBrowserInfo.userAgent;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.utsname.machine;
      }
    } catch (_) {}
    return null;
  }

  Future<void> login(String email, String password) async {
    final settings = SettingsRepository();
    final apiUrl = settings.serverUrl;

    try {
      final deviceName = await _getDeviceName();
      final response = await _dio.post(
        '$apiUrl/auth/login',
        data: {
          'email': email,
          'password': password,
          'clientType': 'mobile',
          if (deviceName != null) 'deviceName': deviceName,
        },
      );

      final token = response.data['accessToken'];
      final refreshToken = response.data['refreshToken'];
      final user = response.data['user'];

      await _storage.write(key: 'accessToken', value: token);
      await _storage.write(key: 'refreshToken', value: refreshToken);
      await _storage.write(key: 'userId', value: user['id']);
      await _storage.write(key: 'userRole', value: user['role']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['error']['message'] ?? 'Login failed');
    }
  }

  Future<void> signup(String email, String password) async {
    final settings = SettingsRepository();
    final apiUrl = settings.serverUrl;

    try {
      final deviceName = await _getDeviceName();
      final response = await _dio.post(
        '$apiUrl/auth/signup',
        data: {
          'email': email,
          'password': password,
          'clientType': 'mobile',
          if (deviceName != null) 'deviceName': deviceName,
        },
      );

      final token = response.data['accessToken'];
      final refreshToken = response.data['refreshToken'];
      final user = response.data['user'];

      await _storage.write(key: 'accessToken', value: token);
      await _storage.write(key: 'refreshToken', value: refreshToken);
      await _storage.write(key: 'userId', value: user['id']);
      await _storage.write(key: 'userRole', value: user['role']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['error']['message'] ?? 'Signup failed');
    }
  }

  Future<void> logout() async {
    final settings = SettingsRepository();
    final apiUrl = settings.serverUrl;
    final token = await _storage.read(key: 'accessToken');

    try {
      await _dio.post(
        '$apiUrl/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}

    await _clearTokens();
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'accessToken');
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: 'userId');
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    if (token != null) {
      refresh(); // Background refresh on startup
      return true;
    }
    return false;
  }

  Future<String?> refresh() async {
    final settings = SettingsRepository();
    final apiUrl = settings.serverUrl;
    final refreshToken = await _storage.read(key: 'refreshToken');

    if (refreshToken == null) {
      await _clearTokens();
      return null;
    }

    try {
      final response = await _dio.post(
        '$apiUrl/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final newToken = response.data['accessToken'];
      final newRefresh = response.data['refreshToken'];
      
      if (newToken != null) {
        await _storage.write(key: 'accessToken', value: newToken);
        if (newRefresh != null) {
          await _storage.write(key: 'refreshToken', value: newRefresh);
        }
        return newToken;
      }
    } catch (e) {
      await _clearTokens();
    }
    return null;
  }

  Future<void> _clearTokens() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
    await _storage.delete(key: 'userId');
    await _storage.delete(key: 'userRole');
  }
}
