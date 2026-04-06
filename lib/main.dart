import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const List<String> supportedVideoExtensions = [
  '.mp4',
  '.mov',
  '.m4v',
  '.mkv',
  '.webm',
  '.avi',
  '.3gp',
];

class AppColors {
  static const primary = Color(0xFFE040FB);
  static const secondary = Color(0xFF7C4DFF);
  static const accent = Color(0xFF00E5FF);
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF1A1A2E);
  static const cardDark = Color(0xFF16213E);
  
  static const gradientPrimary = LinearGradient(
    colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const gradientAccent = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('videoData');
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
  ));
  
  runApp(const InspireReelsApp());
}

class InspireReelsApp extends StatelessWidget {
  const InspireReelsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
        fontFamily: 'SF Pro Display',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      home: const VideoListScreen(),
    );
  }
}

class VideoListScreen extends StatefulWidget {
  const VideoListScreen({super.key});

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen>
    with TickerProviderStateMixin {
  List<FileSystemEntity> _originalVideos = [];
  List<FileSystemEntity> _shuffledVideos = [];
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final Box box = Hive.box('videoData');
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadSavedFolder();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedFolder() async {
    String? savedPath = box.get('saved_folder');
    if (savedPath != null && Directory(savedPath).existsSync()) {
      _loadVideos(savedPath);
    }
  }

  Future<void> _pickFolder() async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          if (mounted) {
            _showSnackBar("Storage permission needed");
          }
          return;
        }
      }
    }

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      box.put('saved_folder', selectedDirectory);
      _loadVideos(selectedDirectory);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _loadVideos(String path) async {
    Directory dir = Directory(path);
    if (await dir.exists()) {
      final files = dir.listSync().where((f) {
        final fileName = f.path.split('/').last;
        if (fileName.startsWith('.')) return false;
        
        final lowerPath = f.path.toLowerCase();
        return supportedVideoExtensions.any((ext) => lowerPath.endsWith(ext));
      }).toList();
      
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
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A2E),
                  AppColors.background,
                  Color(0xFF0F0F1A),
                ],
              ),
            ),
          ),
          _shuffledVideos.isEmpty ? _buildEmptyState() : _buildVideoFeed(),
          _buildTopBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2 + _pulseController.value * 0.2),
                      AppColors.secondary.withValues(alpha: 0.1 + _pulseController.value * 0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 30 + _pulseController.value * 20,
                      spreadRadius: _pulseController.value * 10,
                    ),
                  ],
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => AppColors.gradientPrimary.createShader(bounds),
                  child: const Icon(
                    Icons.play_circle_outline_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            "No vibes yet",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Drop your videos and start scrolling",
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 40),
          _buildGradientButton(
            onTap: _pickFolder,
            icon: Icons.folder_open_rounded,
            label: "Select Folder",
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          gradient: AppColors.gradientPrimary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoFeed() {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemBuilder: (context, index) {
        if (index >= _shuffledVideos.length - 1) _nextVideo();
        return VideoPlayerScreen(
          filePath: _shuffledVideos[index % _shuffledVideos.length].path,
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppColors.gradientPrimary.createShader(bounds),
                child: const Text(
                  "vibes",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
              _buildGlassIconButton(
                icon: Icons.folder_open_rounded,
                onTap: _pickFolder,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String filePath;
  final VoidCallback? onVideoError;

  const VideoPlayerScreen({
    super.key,
    required this.filePath,
    this.onVideoError,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isLiked = false;
  String _note = '';
  final box = Hive.box('videoData');
  bool _hasError = false;
  String _errorMessage = '';
  bool _showPlayPauseIcon = false;
  bool _isPlaying = false;
  late AnimationController _likeAnimController;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializeVideo();
    _isLiked = box.get('${widget.filePath}_liked', defaultValue: false);
    _note = box.get('${widget.filePath}_note', defaultValue: '');
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(File(widget.filePath));
    _controller.addListener(_videoListener);

    try {
      await _controller.initialize();
      if (mounted) {
        setState(() => _isPlaying = true);
        _controller.setLooping(true);
        _controller.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _getErrorMessage(e);
        });
        debugPrint('Video error for ${widget.filePath}: $e');
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('codec') || errorStr.contains('format')) {
      return 'Format not supported';
    } else if (errorStr.contains('permission')) {
      return 'Permission denied';
    } else if (errorStr.contains('not found') || errorStr.contains('no such file')) {
      return 'File not found';
    }
    return 'Can\'t play this one';
  }

  void _videoListener() {
    if (mounted) {
      final isPlaying = _controller.value.isPlaying;
      if (isPlaying != _isPlaying) {
        setState(() => _isPlaying = isPlaying);
      }

      if (_controller.value.hasError && !_hasError) {
        setState(() {
          _hasError = true;
          _errorMessage = _controller.value.errorDescription ?? 'Playback error';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _likeAnimController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_hasError) return;

    HapticFeedback.lightImpact();
    setState(() {
      _showPlayPauseIcon = true;
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showPlayPauseIcon = false);
    });
  }

  void _toggleLike() {
    HapticFeedback.mediumImpact();
    setState(() => _isLiked = !_isLiked);
    box.put('${widget.filePath}_liked', _isLiked);
    
    if (_isLiked) {
      _likeAnimController.forward().then((_) => _likeAnimController.reverse());
    }
  }

  void _addNote() async {
    HapticFeedback.selectionClick();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NoteBottomSheet(initialNote: _note),
    );
    
    if (result != null) {
      setState(() => _note = result);
      box.put('${widget.filePath}_note', _note);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.background),
        if (_hasError)
          _buildErrorWidget()
        else if (!_controller.value.isInitialized)
          _buildLoadingWidget()
        else
          _buildVideoPlayer(),
        _buildPlayPauseOverlay(),
        _buildSideActions(),
        if (!_hasError && _controller.value.isInitialized) _buildProgressSlider(),
        _buildNoteDisplay(),
        _buildVideoInfo(),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sentiment_dissatisfied_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getFileName(widget.filePath),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swipe_up_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "Swipe to skip",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _toggleLike,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }

  Widget _buildPlayPauseOverlay() {
    return AnimatedOpacity(
      opacity: _showPlayPauseIcon ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Center(
        child: AnimatedScale(
          scale: _showPlayPauseIcon ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideActions() {
    return Positioned(
      right: 16,
      bottom: 140,
      child: Column(
        children: [
          _buildActionButton(
            icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            gradient: _isLiked ? AppColors.gradientPrimary : null,
            color: _isLiked ? null : Colors.white,
            onTap: _toggleLike,
            scale: _isLiked ? 1.2 : 1.0,
          ),
          const SizedBox(height: 24),
          _buildActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            gradient: _note.isNotEmpty ? AppColors.gradientAccent : null,
            color: _note.isNotEmpty ? null : Colors.white,
            onTap: _addNote,
          ),
          const SizedBox(height: 24),
          _buildActionButton(
            icon: Icons.bookmark_border_rounded,
            color: Colors.white,
            onTap: () => HapticFeedback.lightImpact(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    LinearGradient? gradient,
    Color? color,
    required VoidCallback onTap,
    double scale = 1.0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 200),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: gradient,
                color: gradient == null ? Colors.white.withValues(alpha: 0.15) : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: gradient != null
                  ? Icon(icon, color: Colors.white, size: 26)
                  : Icon(icon, color: color, size: 26),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSlider() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ValueListenableBuilder(
        valueListenable: _controller,
        builder: (context, VideoPlayerValue value, child) {
          final position = value.position;
          final duration = value.duration;
          final progress = duration.inMilliseconds > 0
              ? position.inMilliseconds / duration.inMilliseconds
              : 0.0;

          return Container(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: AppColors.gradientPrimary,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Positioned(
      left: 20,
      bottom: 100,
      right: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getFileName(widget.filePath).replaceAll(RegExp(r'\.[^.]+$'), ''),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNoteDisplay() {
    if (_note.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 160,
      left: 20,
      right: 80,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surface.withValues(alpha: 0.8),
                  AppColors.cardDark.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppColors.gradientAccent.createShader(bounds),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _note,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteBottomSheet extends StatefulWidget {
  final String initialNote;

  const _NoteBottomSheet({required this.initialNote});

  @override
  State<_NoteBottomSheet> createState() => _NoteBottomSheetState();
}

class _NoteBottomSheetState extends State<_NoteBottomSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => AppColors.gradientPrimary.createShader(bounds),
                      child: const Icon(
                        Icons.sticky_note_2_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Add your thoughts",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: 4,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, _controller.text),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientPrimary,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "Save",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
