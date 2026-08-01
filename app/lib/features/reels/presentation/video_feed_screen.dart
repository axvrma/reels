import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hugeicons/hugeicons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/config/settings_repository.dart';
import '../domain/video_item.dart';
import '../domain/video_repository.dart';
import '../data/server_video_repository.dart';
import '../data/local_video_repository.dart';
import '../domain/video_state.dart';
import 'settings_screen.dart';
import 'package:dio/dio.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_screen.dart';
import 'player/adaptive_video_player.dart';
class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  VideoRepository _repository = ServerVideoRepository();
  List<VideoItem> _allVideos = [];
  List<VideoItem> _videos = [];
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';
  bool _isLoading = true;
  String? _error;
  
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _autoPlayBackground = false;
  
  late AnimationController _pulseController;
  final Box box = Hive.box('videoData');

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _initApp();
  }
  
  Future<void> _initApp() async {
    final settings = SettingsRepository();
    if (settings.isLocalMode) {
      _repository = LocalVideoRepository();
    } else {
      _repository = ServerVideoRepository();
    }
    
    if (_repository is ServerVideoRepository) {
      await (_repository as ServerVideoRepository).cleanStaleFiles();
    }
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final settings = SettingsRepository();
      List<String> categories = ['All'];
      if (!settings.isLocalMode) {
        final dio = Dio();
        final token = await AuthRepository().getAccessToken();
        if (token != null) {
          dio.options.headers['Authorization'] = 'Bearer $token';
        }
        
        final catsRes = await dio.get('${settings.serverUrl}/categories');
        final List catsJson = catsRes.data;
        categories.addAll(catsJson.map((c) => c['name'].toString()));
      }

      final videos = await _repository.getVideos();
      videos.shuffle();
      setState(() {
        _allVideos = videos;
        _categories = categories;
        _isLoading = false;
        _applyCategoryFilter();
      });
      _syncPendingStates();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyCategoryFilter() {
    setState(() {
      if (_selectedCategory == 'All') {
        _videos = _allVideos;
      } else {
        _videos = _allVideos.where((v) => v.category?.name == _selectedCategory).toList();
      }
      _currentIndex = 0;
      if (_videos.isNotEmpty && _pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }
  
  Future<void> _syncPendingStates() async {
    final settings = SettingsRepository();
    if (settings.isLocalMode) return;
    
    // Basic offline sync logic: sync any states saved while offline
    final dio = Dio();
    for (var key in box.keys) {
      if (key.toString().endsWith('_state')) {
        final stateJson = box.get(key);
        if (stateJson != null && stateJson['syncPending'] == true) {
          try {
            await dio.put(
              '${settings.serverUrl}/videos/${stateJson['videoId']}/state',
              data: {
                'liked': stateJson['liked'],
                'note': stateJson['note'],
                'progress_seconds': stateJson['progressSeconds'],
              }
            );
            // Mark synced
            stateJson['syncPending'] = false;
            box.put(key, stateJson);
          } catch (e) {
            // Ignore, will retry next time
          }
        }
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).appBarTheme.backgroundColor,
              ),
              child: const Text(
                'vibes',
                style: TextStyle(
                  color: Color(0xFFE040FB),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ),
            ListTile(
              leading: HugeIcon(icon: HugeIcons.strokeRoundedSettings01, color: Theme.of(context).iconTheme.color ?? Colors.white, size: 24.0),
              title: Text('Settings', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              onTap: () async {
                Navigator.pop(context); // close drawer
                final changed = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
                if (changed == true) {
                  _initApp();
                }
              },
            ),
            ListTile(
              leading: const HugeIcon(icon: HugeIcons.strokeRoundedLogout01, color: Colors.redAccent, size: 24.0),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context); // close drawer
                await AuthRepository().logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          _buildBody(),
          _buildTopBar(),
        ],
      ),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE040FB)));
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const HugeIcon(icon: HugeIcons.strokeRoundedAlert01, color: Colors.red, size: 64.0),
              const SizedBox(height: 16),
              const Text('An error occurred while loading the feed.', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadVideos, child: const Text('Retry')),
              const SizedBox(height: 32),
              Card(
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: const Text('More details'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_videos.isEmpty) {
      return Center(
        child: Text('No videos available on the server.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 18)),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: (idx) => setState(() => _currentIndex = idx),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        return VideoPlayerScreen(
          key: ValueKey(_videos[index].id),
          video: _videos[index],
          repository: _repository,
          autoPlayMode: _autoPlayBackground,
          onNavigateUp: index > 0 
              ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
              : null,
          onNavigateDown: index < _videos.length - 1 
              ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
              : null,
        );
      },
    );
  }

  Widget _buildTopBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8);
    final shadows = [
      Shadow(color: shadowColor, blurRadius: 2.0),
      Shadow(color: shadowColor, blurRadius: 6.0),
      Shadow(color: shadowColor, blurRadius: 12.0),
    ];

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: IconTheme(
          data: IconTheme.of(context).copyWith(shadows: shadows),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: HugeIcon(icon: HugeIcons.strokeRoundedMenu01, color: Theme.of(context).iconTheme.color ?? Colors.white, size: 24.0),
                          onPressed: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "vibes",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE040FB),
                            letterSpacing: -1,
                            shadows: shadows,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedHeadphones, 
                            color: _autoPlayBackground ? const Color(0xFFE040FB) : (Theme.of(context).iconTheme.color ?? Colors.white), 
                            size: 24.0,
                          ),
                          onPressed: () {
                            setState(() {
                              _autoPlayBackground = !_autoPlayBackground;
                            });
                          },
                        ),
                        IconButton(
                          icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, color: Theme.of(context).iconTheme.color ?? Colors.white, size: 24.0),
                          onPressed: _loadVideos,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (!SettingsRepository().isLocalMode && _categories.length > 1)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = category == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected && _selectedCategory != category) {
                            setState(() {
                              _selectedCategory = category;
                              _applyCategoryFilter();
                            });
                          }
                        },
                        selectedColor: const Color(0xFFE040FB),
                        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                        labelStyle: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          shadows: isSelected ? [] : shadows,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final VideoItem video;
  final VideoRepository repository;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  final bool autoPlayMode;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    required this.repository,
    this.autoPlayMode = false,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with SingleTickerProviderStateMixin {
  AdaptiveVideoController? _controller;
  bool _isPlaying = false;
  bool _hasError = false;
  String _errorMessage = '';
  Object? _cachedFile;
  
  late VideoState _videoState;
  final Box box = Hive.box('videoData');
  late AnimationController _likeAnimController;
  bool _showPlayPauseIcon = false;
  String? _stateKey;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _videoState = VideoState(
      videoId: widget.video.id,
      updatedAt: DateTime.now(),
    );
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadState();
    _initializeVideo();
  }

  void _loadState() async {
    final authRepo = AuthRepository();
    final userId = await authRepo.getUserId() ?? 'unknown';
    _stateKey = '${userId}_${widget.video.id}_state';

    final stateJson = box.get(_stateKey);
    if (stateJson != null) {
      if (mounted) {
        setState(() {
          _videoState = VideoState(
            videoId: widget.video.id,
            liked: stateJson['liked'],
            note: stateJson['note'],
            progressSeconds: stateJson['progressSeconds'],
            updatedAt: DateTime.parse(stateJson['updatedAt']),
            syncPending: stateJson['syncPending'],
          );
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _videoState = VideoState(
            videoId: widget.video.id,
            updatedAt: DateTime.now(),
          );
        });
      }
    }
  }

  void _saveState() {
    if (_stateKey == null) return;
    _videoState = _videoState.copyWith(
      updatedAt: DateTime.now(),
      syncPending: true,
    );
    
    box.put(_stateKey, {
      'videoId': _videoState.videoId,
      'liked': _videoState.liked,
      'note': _videoState.note,
      'progressSeconds': _videoState.progressSeconds,
      'updatedAt': _videoState.updatedAt.toIso8601String(),
      'syncPending': _videoState.syncPending,
    });
    
    // Attempt async save to API
    final settings = SettingsRepository();
    if (!settings.isLocalMode) {
      widget.repository.saveProgress(widget.video.id, _videoState.progressSeconds);
      widget.repository.saveNote(widget.video.id, _videoState.note);
      if (_videoState.liked) {
        widget.repository.likeVideo(widget.video.id);
      } else {
        widget.repository.unlikeVideo(widget.video.id);
      }
      
      _videoState = _videoState.copyWith(syncPending: false);
      box.put(_stateKey, {
        'videoId': _videoState.videoId,
        'liked': _videoState.liked,
        'note': _videoState.note,
        'progressSeconds': _videoState.progressSeconds,
        'updatedAt': _videoState.updatedAt.toIso8601String(),
        'syncPending': _videoState.syncPending,
      });
    }
  }

  Future<void> _initializeVideo() async {
    _cachedFile = await widget.repository.getCachedVideo(widget.video.id);
    
    _controller = createAdaptiveVideoController();
    _controller!.addListener(_videoListener);

    try {
      if (_cachedFile != null) {
        await _controller!.initialize(widget.video.streamUrl, file: _cachedFile);
      } else {
        if (widget.video.streamUrl.scheme == 'file') {
          // File from dart:io is avoided here for web safety
          await _controller!.initialize(widget.video.streamUrl, file: null);
        } else {
          final token = await AuthRepository().getAccessToken();
          final headers = <String, String>{};
          Uri streamUri = widget.video.streamUrl;
          
          if (token != null) {
            headers['Authorization'] = 'Bearer $token';
            if (kIsWeb) {
              final queryParams = Map<String, dynamic>.from(streamUri.queryParameters);
              queryParams['token'] = token;
              streamUri = streamUri.replace(queryParameters: queryParams);
            }
          }
          await _controller!.initialize(streamUri, headers: headers);
        }
      }

      if (mounted) {
        setState(() => _isPlaying = true);
        await _controller!.setLooping(!widget.autoPlayMode);
        if (_videoState.progressSeconds > 0 && _videoState.progressSeconds < _controller!.duration.inSeconds) {
          await _controller!.seekTo(Duration(seconds: _videoState.progressSeconds.toInt()));
        }
        await _controller!.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _videoListener() {
    if (mounted && _controller != null) {
      final isPlaying = _controller!.isPlaying;
      if (isPlaying != _isPlaying) {
        setState(() => _isPlaying = isPlaying);
      }

      if (_controller!.hasError && !_hasError) {
        setState(() {
          _hasError = true;
          _errorMessage = _controller!.errorDescription ?? 'Playback error';
        });
      }
      
      // Save progress periodically
      if (_isPlaying && _controller!.position.inSeconds % 5 == 0) {
        _videoState = _videoState.copyWith(progressSeconds: _controller!.position.inSeconds.toDouble());
        _saveState();
      }

      // Auto-advance logic
      if (widget.autoPlayMode && 
          !_hasNavigated && 
          _controller!.duration.inMilliseconds > 0 &&
          _controller!.position.inMilliseconds >= _controller!.duration.inMilliseconds - 300) {
        _hasNavigated = true;
        widget.onNavigateDown?.call();
      }
    }
  }

  @override
  void didUpdateWidget(VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlayMode != widget.autoPlayMode) {
      _controller?.setLooping(!widget.autoPlayMode);
      if (!widget.autoPlayMode) {
        _hasNavigated = false;
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _likeAnimController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_hasError || _controller == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _showPlayPauseIcon = true;
      if (_controller!.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showPlayPauseIcon = false);
    });
  }

  void _toggleLike() {
    HapticFeedback.mediumImpact();
    setState(() {
      _videoState = _videoState.copyWith(liked: !_videoState.liked);
    });
    _saveState();
    
    if (_videoState.liked) {
      _likeAnimController.forward().then((_) => _likeAnimController.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = isDark ? Colors.black : Colors.white;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_hasError) _buildErrorWidget()
        else if (_controller == null) _buildLoadingWidget()
        else _buildVideoPlayer(),
        
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [shadowColor.withValues(alpha: 0.8), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 240,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [shadowColor.withValues(alpha: 0.8), Colors.transparent],
              ),
            ),
          ),
        ),

        _buildPlayPauseOverlay(),
        _buildSideActions(),
        _buildVideoInfo(),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Center(child: CircularProgressIndicator(color: const Color(0xFFE040FB)));
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24.0),
        color: Colors.black.withValues(alpha: 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(icon: HugeIcons.strokeRoundedAlert01, color: Colors.red, size: 48.0),
            const SizedBox(height: 16),
            const Text('Could not play this video.', style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Card(
              color: Colors.white.withValues(alpha: 0.05),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white70,
                  title: const Text('More details', style: TextStyle(color: Colors.white70)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _toggleLike,
      child: Center(
        child: AdaptiveVideoPlayerWidget(
          controller: _controller!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
  
  Widget _buildPlayPauseOverlay() {
    if (!_showPlayPauseIcon) return const SizedBox.shrink();
    return Center(
      child: HugeIcon(
        icon: _isPlaying ? HugeIcons.strokeRoundedPause : HugeIcons.strokeRoundedPlay,
        size: 80.0,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildSideActions() {
    if (SettingsRepository().isLocalMode) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8);
    final shadows = [
      Shadow(color: shadowColor, blurRadius: 2.0),
      Shadow(color: shadowColor, blurRadius: 6.0),
      Shadow(color: shadowColor, blurRadius: 12.0),
    ];
    return Positioned(
      right: 16,
      bottom: 140,
      child: IconTheme(
        data: IconTheme.of(context).copyWith(shadows: shadows),
        child: Column(
          children: [
            IconButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedFavourite, 
                color: _videoState.liked ? Colors.red : (Theme.of(context).iconTheme.color ?? Colors.white), 
                size: 36.0,
              ),
              onPressed: _toggleLike,
            ),
            const SizedBox(height: 16),
            if (widget.onNavigateUp != null)
              IconButton(
                icon: Icon(LucideIcons.arrowUp, color: Theme.of(context).iconTheme.color ?? Colors.white, size: 36.0),
                onPressed: widget.onNavigateUp,
              ),
            if (widget.onNavigateDown != null)
              IconButton(
                icon: Icon(LucideIcons.arrowDown, color: Theme.of(context).iconTheme.color ?? Colors.white, size: 36.0),
                onPressed: widget.onNavigateDown,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8);
    final shadows = [
      Shadow(color: shadowColor, blurRadius: 2.0),
      Shadow(color: shadowColor, blurRadius: 6.0),
      Shadow(color: shadowColor, blurRadius: 12.0),
    ];
    return Positioned(
      left: 16,
      bottom: 40,
      right: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.video.title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color, 
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              shadows: shadows,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.video.tags.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(int.parse(t.color.replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(t.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
