import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('videoData');
  runApp(const InspireReelsApp());
}

class InspireReelsApp extends StatelessWidget {
  const InspireReelsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reels',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const VideoListScreen(),
    );
  }
}

class VideoListScreen extends StatefulWidget {
  const VideoListScreen({super.key});

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  List<FileSystemEntity> _originalVideos = [];
  List<FileSystemEntity> _shuffledVideos = [];
  String? _selectedFolder;
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final Box box = Hive.box('videoData');

  @override
  void initState() {
    super.initState();
    _loadSavedFolder();
  }

  Future<void> _loadSavedFolder() async {
    String? savedPath = box.get('saved_folder');
    if (savedPath != null && Directory(savedPath).existsSync()) {
      setState(() => _selectedFolder = savedPath);
      _loadVideos(savedPath);
    }
  }

  Future<void> _pickFolder() async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Storage permission not granted")),
          );
          return;
        }
      }
    }

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _selectedFolder = selectedDirectory;
        box.put('saved_folder', selectedDirectory);
      });
      _loadVideos(selectedDirectory);
    }
  }

  Future<void> _loadVideos(String path) async {
    Directory dir = Directory(path);
    if (await dir.exists()) {
      final files = dir.listSync().where((f) => f.path.endsWith('.mp4')).toList();
      setState(() {
        _originalVideos = files;
        _shuffledVideos = _shuffleVideos(files);
        _currentIndex = 0;
      });
    }
  }

  List<FileSystemEntity> _shuffleVideos(List<FileSystemEntity> videos) {
    final shuffled = List<FileSystemEntity>.from(videos);
    shuffled.shuffle(Random());
    return shuffled;
  }

  void _nextVideo() {
    setState(() {
      _currentIndex++;
      if (_currentIndex >= _shuffledVideos.length) {
        _shuffledVideos = _shuffleVideos(_originalVideos);
        _currentIndex = 0;
      }
      _pageController.jumpToPage(_currentIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _shuffledVideos.isEmpty
              ? const Center(child: Text("No videos loaded. Tap folder icon to select folder."))
              : PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemBuilder: (context, index) {
              if (index >= _shuffledVideos.length - 1) _nextVideo();
              return VideoPlayerScreen(
                filePath: _shuffledVideos[index % _shuffledVideos.length].path,
              );
            },
          ),
          Positioned(
            top: 50,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.folder_open, size: 28),
              onPressed: _pickFolder,
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String filePath;
  const VideoPlayerScreen({super.key, required this.filePath});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isLiked = false;
  String _note = '';
  final box = Hive.box('videoData');

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        setState(() {
          _controller.setLooping(false);
          _controller.play();
        });
      });

    _isLiked = box.get('${widget.filePath}_liked', defaultValue: false);
    _note = box.get('${widget.filePath}_note', defaultValue: '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() => _isLiked = !_isLiked);
    box.put('${widget.filePath}_liked', _isLiked);
  }

  void _addNote() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController(text: _note);
        return AlertDialog(
          title: const Text("Add Note"),
          content: TextField(controller: controller, maxLines: 5),
          actions: [
            TextButton(
              child: const Text("Save"),
              onPressed: () => Navigator.of(context).pop(controller.text),
            )
          ],
        );
      },
    );
    if (result != null) {
      setState(() => _note = result);
      box.put('${widget.filePath}_note', _note);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _controller.value.isPlaying ? _controller.pause() : _controller.play();
            });
          },
          child: _controller.value.isInitialized
              ? Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          )
              : const Center(child: CircularProgressIndicator()),
        ),
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              IconButton(
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                    color: Colors.white, size: 32),
                onPressed: _toggleLike,
              ),
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(Icons.comment, color: Colors.white, size: 32),
                onPressed: _addNote,
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          left: 16,
          child: Text(
            _note,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
