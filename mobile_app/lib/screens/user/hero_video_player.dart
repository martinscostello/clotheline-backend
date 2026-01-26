import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HeroVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool isActive; // Controls Play/Pause
  
  const HeroVideoPlayer({
    super.key, 
    required this.videoUrl,
    this.thumbnailUrl,
    required this.isActive,
  });

  @override
  State<HeroVideoPlayer> createState() => _HeroVideoPlayerState();
}

class _HeroVideoPlayerState extends State<HeroVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..initialize().then((_) {
        if (mounted) {
          _controller.setLooping(true);
          _controller.setVolume(0.0);
          
          setState(() {
            _initialized = true;
          });
          
          if (widget.isActive) {
            _controller.play();
          }
        }
      });
  }

  @override
  void didUpdateWidget(HeroVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle URL Change
    if (widget.videoUrl != oldWidget.videoUrl) {
      _initialized = false;
      _controller.dispose();
      _initializeController();
      return; 
    }

    // Handle Active State Change
    if (_initialized) {
      if (widget.isActive && !oldWidget.isActive) {
        _controller.play();
      } else if (!widget.isActive && oldWidget.isActive) {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Helper: Derive Thumbnail URL (Cloudinary assumption: .mp4 -> .jpg)
  String _getThumbnailUrl(String videoUrl) {
    if (videoUrl.contains("cloudinary.com")) {
      // Replace file extension with .jpg
      return videoUrl.replaceAll(RegExp(r'\.(mp4|mov|avi)$', caseSensitive: false), '.jpg');
    }
    // Fallback: Return original (Image widget might fail or try to load it, handling error is key)
    return videoUrl; 
  }

  @override
  Widget build(BuildContext context) {
    final String? thumbnailUrl = widget.thumbnailUrl ?? _getThumbnailUrl(widget.videoUrl);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Thumbnail (Always visible initially, stays behind video)
        CachedNetworkImage(
           imageUrl: thumbnailUrl ?? "",
           fit: BoxFit.cover,
           errorWidget: (context, url, error) => Container(color: Colors.black26), // Fallback
           fadeInDuration: Duration.zero, // Instant
        ),

        // 2. Video Player (Fades in when ready)
        AnimatedOpacity(
          opacity: _initialized ? 1.0 : 0.0, 
          duration: const Duration(milliseconds: 500), // Slightly longer for smoothness
          child: _initialized 
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                       width: _controller.value.size.width,
                       height: _controller.value.size.height,
                       child: VideoPlayer(_controller),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
          
        // 3. Loading (Optional, if thumbnail fails or takes time, but usually unnecessary with thumbnail)
      ],
    );
  }
}
