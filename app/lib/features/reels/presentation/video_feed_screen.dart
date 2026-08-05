
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_screen.dart';
import 'player/adaptive_video_player.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
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
  bool _isRefreshingToken = false;
  
  late AnimationController _pulseController;
  final Box box = Hive.box('videoData');

  final Map<int, AdaptiveVideoController> _controllers = {};
  final Map<int, VideoState> _videoStates = {};
  final Map<int, bool> _hasNavigatedMap = {};
  
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    
    if (SettingsRepository().isLocalMode) {
      _repository = LocalVideoRepository();
    }
    _loadVideos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _pulseController.dispose();
    _pageController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _lifecycleState = state;
    });
    _manageControllers();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final videos = await _repository.getVideos();
      final Set<String> uniqueCategories = {'All'};
      for (var v in videos) {
        if (v.category != null) {
          uniqueCategories.add(v.category!.name);
        }
      }
      
      setState(() {
        _allVideos = videos;
        _categories = uniqueCategories.toList()..sort((a, b) => a == 'All' ? -1 : a.compareTo(b));
        _isLoading = false;
        _applyCategoryFilter();
      });
      _manageControllers();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyCategoryFilter() {
    if (_selectedCategory == 'All') {
      _videos = List.from(_allVideos);
    } else {
      _videos = _allVideos.where((v) => v.category?.name == _selectedCategory).toList();
    }
    
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _videoStates.clear();
    _hasNavigatedMap.clear();
    
    _currentIndex = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _manageControllers();
  }
  
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _manageControllers();
  }

  void _manageControllers() {
    if (_videos.isEmpty) return;
    final prev = _currentIndex - 1;
    final current = _currentIndex;
    final next = _currentIndex + 1;
    
    // Initialize required
    for (int i in [prev, current, next]) {
      if (i >= 0 && i < _videos.length) {
        if (!_controllers.containsKey(i)) {
          _initializeController(i);
        }
      }
    }
    
    // Dispose unused
    final keysToRemove = _controllers.keys.where((k) => k < prev || k > next).toList();
    for (int k in keysToRemove) {
      _controllers[k]?.dispose();
      _controllers.remove(k);
    }
    
    // Play/Pause logic
    _controllers.forEach((index, controller) {
      if (index == current) {
        final isBackground = _lifecycleState == AppLifecycleState.paused || _lifecycleState == AppLifecycleState.detached || _lifecycleState == AppLifecycleState.hidden;
        if (!isBackground || _autoPlayBackground) {
           controller.play();
        } else {
           controller.pause();
        }
      } else {
        controller.pause();
      }
    });
  }

  Future<void> _initializeController(int index) async {
    final video = _videos[index];
    
    AdaptiveVideoController controller;
    bool isNew = false;
    if (_controllers.containsKey(index)) {
      controller = _controllers[index]!;
    } else {
      controller = createAdaptiveVideoController();
      _controllers[index] = controller;
      isNew = true;
    }
    
    // Load VideoState
    VideoState vState = VideoState(videoId: video.id, updatedAt: DateTime.now());
    final cached = box.get('video_${video.id}');
    if (cached != null) {
      try {
        final map = Map<String, dynamic>.from(cached);
        vState = VideoState(
          videoId: video.id,
          liked: map['liked'] ?? false,
          note: map['note'] ?? '',
          progressSeconds: map['progressSeconds'] ?? 0.0,
          updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
        );
      } catch (_) {}
    }
    _videoStates[index] = vState;
    if (isNew) {
      _hasNavigatedMap[index] = false;
      controller.addListener(() {
        _videoListener(index);
      });
    }
    
    // Construct URI and Headers logic from original code
    Uri streamUri = video.streamUrl;
    final headers = <String, String>{};
    
    if (streamUri.scheme != 'file') {
      final token = await AuthRepository().getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        final queryParams = Map<String, dynamic>.from(streamUri.queryParameters);
        queryParams['token'] = token;
        streamUri = streamUri.replace(queryParameters: queryParams);
      }
    }
    
    // We try to get cached file using the repository
    Object? cachedFile;
    try {
      cachedFile = await _repository.getCachedVideo(video.id);
    } catch (_) {}

    
    await controller.initialize(streamUri, file: cachedFile, headers: headers);
    controller.setLooping(!_autoPlayBackground);
    
    if (vState.progressSeconds > 0) {
      controller.seekTo(Duration(seconds: vState.progressSeconds.toInt()));
    }
    
    if (mounted) setState(() {});
  }

  void _videoListener(int index) {
    if (!mounted) return;
    final controller = _controllers[index];
    if (controller == null) return;
    
    // Auto-refresh token if a stream error occurs (token expired)
    if (controller.hasError && !_isRefreshingToken) {
      _isRefreshingToken = true;
      AuthRepository().refresh().then((newToken) {
        if (!mounted) return;
        _isRefreshingToken = false;
        if (newToken != null) {
          // Re-initialize all active controllers since their tokens likely expired too
          for (final key in _controllers.keys.toList()) {
             _initializeController(key).then((_) {
                if (key == _currentIndex && mounted) {
                   _manageControllers();
                }
             });
          }
        }
      });
    }
    
    if (index == _currentIndex) {
      if (controller.position.inSeconds > 0 && controller.position.inSeconds % 5 == 0) {
        setState(() {
          _videoStates[index] = _videoStates[index]!.copyWith(progressSeconds: controller.position.inSeconds.toDouble());
        });
        _saveState(index);
      }
      
      // Auto-advance logic
      if (_autoPlayBackground && 
          !(_hasNavigatedMap[index] ?? false) &&
          controller.duration.inMilliseconds > 0 &&
          controller.position.inMilliseconds >= controller.duration.inMilliseconds - 300) {
        
        _hasNavigatedMap[index] = true;
        if (index < _videos.length - 1) {
          _advanceToNextVideo();
        }
      }
    }
  }

  void _advanceToNextVideo() {
    if (_currentIndex < _videos.length - 1) {
      final newIndex = _currentIndex + 1;
      final isBackground = _lifecycleState == AppLifecycleState.paused || _lifecycleState == AppLifecycleState.hidden || _lifecycleState == AppLifecycleState.detached;
      
      if (isBackground) {
         setState(() {
           _currentIndex = newIndex;
         });
         _manageControllers();
         if (_pageController.hasClients) {
            _pageController.jumpToPage(newIndex);
         }
      } else {
         if (_pageController.hasClients) {
            _pageController.animateToPage(newIndex, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
         }
      }
    }
  }

  void _saveState(int index) {
    final state = _videoStates[index];
    final video = _videos[index];
    if (state != null) {
      box.put('video_${video.id}', {
        'liked': state.liked,
        'note': state.note,
        'progressSeconds': state.progressSeconds,
        'updatedAt': state.updatedAt.toIso8601String(),
      });
    }
  }
  
  void _toggleLike(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      final state = _videoStates[index] ?? VideoState(videoId: _videos[index].id, updatedAt: DateTime.now());
      _videoStates[index] = state.copyWith(liked: !state.liked);
    });
    _saveState(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? Colors.black : Colors.white,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('vibes', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
                  const SizedBox(height: 8),
                  Text('Find your vibe', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16)),
                ],
              ),
            ),
            ListTile(
              leading: const HugeIcon(icon: HugeIcons.strokeRoundedSettings01, color: Colors.black54, size: 24.0),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            ListTile(
              leading: const HugeIcon(icon: HugeIcons.strokeRoundedLogout01, color: Colors.redAccent, size: 24.0),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
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
      onPageChanged: _onPageChanged,
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final controller = _controllers[index];
        final state = _videoStates[index] ?? VideoState(videoId: _videos[index].id, updatedAt: DateTime.now());
        
        return VideoPlayerScreen(
          key: ValueKey(_videos[index].id),
          video: _videos[index],
          controller: controller,
          videoState: state,
          autoPlayMode: _autoPlayBackground,
          onToggleLike: () => _toggleLike(index),
          onNavigateUp: index > 0 
              ? () {
                  if (_pageController.hasClients) {
                    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                }
              : null,
          onNavigateDown: index < _videos.length - 1 
              ? () {
                  if (_pageController.hasClients) {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                }
              : null,
          pauseUponEnteringBackgroundMode: !_autoPlayBackground,
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
                          icon: Icon(
                            LucideIcons.playCircle, 
                            color: _autoPlayBackground ? const Color(0xFFE040FB) : (Theme.of(context).iconTheme.color ?? Colors.white), 
                            size: 24.0,
                          ),
                          onPressed: () {
                            setState(() {
                              _autoPlayBackground = !_autoPlayBackground;
                              for (var controller in _controllers.values) {
                                controller.setLooping(!_autoPlayBackground);
                              }
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
  final AdaptiveVideoController? controller;
  final VideoState videoState;
  final VoidCallback onToggleLike;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  final bool autoPlayMode;
  final bool pauseUponEnteringBackgroundMode;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    required this.controller,
    required this.videoState,
    required this.onToggleLike,
    this.autoPlayMode = false,
    this.pauseUponEnteringBackgroundMode = true,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with SingleTickerProviderStateMixin {
  bool _showPlayPauseIcon = false;
  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnim;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _likeScaleAnim = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(parent: _likeAnimController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = widget.controller;
    if (controller == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _showPlayPauseIcon = true;
    });
    
    if (controller.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showPlayPauseIcon = false);
    });
  }

  void _onDoubleTapLike() {
    widget.onToggleLike();
    if (!widget.videoState.liked) {
      // It's about to be liked (state hasn't bubbled down yet fully, but we assume it does)
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
        if (widget.controller == null) _buildLoadingWidget()
        else if (widget.controller!.hasError) _buildErrorWidget()
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
        
        // Like Animation Overlay
        Center(
          child: ScaleTransition(
            scale: _likeScaleAnim,
            child: const HugeIcon(icon: HugeIcons.strokeRoundedFavourite, color: Colors.red, size: 120.0),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(child: CircularProgressIndicator(color: Color(0xFFE040FB)));
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
                      child: Text(widget.controller!.errorDescription ?? "Unknown error", style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
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
      onDoubleTap: _onDoubleTapLike,
      child: Center(
        child: AdaptiveVideoPlayerWidget(
          controller: widget.controller!,
          fit: BoxFit.contain,
          pauseUponEnteringBackgroundMode: widget.pauseUponEnteringBackgroundMode,
        ),
      ),
    );
  }
  
  Widget _buildPlayPauseOverlay() {
    if (!_showPlayPauseIcon || widget.controller == null) return const SizedBox.shrink();
    return Center(
      child: HugeIcon(
        icon: widget.controller!.isPlaying ? HugeIcons.strokeRoundedPause : HugeIcons.strokeRoundedPlay,
        size: 80.0,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildSideActions() {
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
                color: widget.videoState.liked ? Colors.red : (Theme.of(context).iconTheme.color ?? Colors.white), 
                size: 36.0,
              ),
              onPressed: widget.onToggleLike,
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
