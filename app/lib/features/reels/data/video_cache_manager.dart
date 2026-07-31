import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../domain/video_item.dart';

class VideoCacheManager {
  final Dio _dio;

  VideoCacheManager({Dio? dio}) : _dio = dio ?? Dio();

  Future<String> _getCacheDirPath() async {
    if (kIsWeb) throw UnsupportedError('File system access not supported on Web');
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(dir.path, 'videos'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  Future<File?> getCachedVideo(String videoId) async {
    if (kIsWeb) return null;
    final cacheDirPath = await _getCacheDirPath();
    final file = File(p.join(cacheDirPath, '$videoId.mp4'));
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<File> downloadVideo(VideoItem video, {Function(int, int)? onReceiveProgress}) async {
    if (kIsWeb) throw UnsupportedError('File downloads are not supported on Web');
    final cacheDirPath = await _getCacheDirPath();
    final file = File(p.join(cacheDirPath, '${video.id}.mp4'));
    final partFile = File(p.join(cacheDirPath, '${video.id}.mp4.part'));

    if (await file.exists()) {
      return file; // Already cached
    }

    try {
      await _dio.download(
        video.streamUrl.toString(),
        partFile.path,
        onReceiveProgress: onReceiveProgress,
      );

      final stat = await partFile.stat();
      if (video.sizeBytes > 0 && stat.size != video.sizeBytes) {
        throw Exception('File size mismatch: ${stat.size} vs ${video.sizeBytes}');
      }

      await partFile.rename(file.path);
      return file;
    } catch (e) {
      if (await partFile.exists()) {
        await partFile.delete();
      }
      rethrow;
    }
  }

  Future<void> deleteCachedVideo(String videoId) async {
    if (kIsWeb) return;
    final cacheDirPath = await _getCacheDirPath();
    final file = File(p.join(cacheDirPath, '$videoId.mp4'));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> cleanStalePartFiles() async {
    if (kIsWeb) return;
    final cacheDirPath = await _getCacheDirPath();
    final dir = Directory(cacheDirPath);
    if (!await dir.exists()) return;

    final entities = await dir.list().toList();
    for (var entity in entities) {
      if (entity is File && entity.path.endsWith('.part')) {
        await entity.delete();
      }
    }
  }
}
