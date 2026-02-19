import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HeroVideoPlayer extends StatefulWidget {
  final VideoPlayerController? controller;
  final String videoUrl; // Used to derive fallback thumbnail
  final String? thumbnailUrl;
  final bool isActive; // Controls Play/Pause
  
  const HeroVideoPlayer({
    super.key, 
    required this.controller,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.isActive,
  });

  @override
  State<HeroVideoPlayer> createState() => _HeroVideoPlayerState();
}

class _HeroVideoPlayerState extends State<HeroVideoPlayer> {
  VoidCallback? _listener;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    if (widget.controller != null) {
      _listener = () {
        if (mounted) setState(() {});
      };
      widget.controller!.addListener(_listener!);
      _syncPlayState();
    }
  }

  void _syncPlayState() {
     if (widget.controller != null && widget.controller!.value.isInitialized) {
        if (widget.isActive) {
           widget.controller!.play();
        } else {
           widget.controller!.pause();
        }
     }
  }

  @override
  void didUpdateWidget(HeroVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle Controller Change
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller != null && _listener != null) {
        oldWidget.controller!.removeListener(_listener!);
      }
      _setupController();
    } else {
      // Handle Active State Change
      _syncPlayState();
    }
  }

  @override
  void dispose() {
    if (widget.controller != null && _listener != null) {
       widget.controller!.removeListener(_listener!);
    }
    super.dispose();
  }

  // Helper: Derive Thumbnail URL (Cloudinary assumption: .mp4 -> .jpg)
  String _getThumbnailUrl(String videoUrl) {
    if (videoUrl.contains("cloudinary.com")) {
      // Replace file extension with .jpg
      return videoUrl.replaceAll(RegExp(r'\.(mp4|mov|avi)$', caseSensitive: false), '.jpg');
    }
    // Fallback: Return original
    return videoUrl; 
  }

  @override
  Widget build(BuildContext context) {
    final String? thumbnailUrl = widget.thumbnailUrl ?? _getThumbnailUrl(widget.videoUrl);
    final bool isReady = widget.controller != null && widget.controller!.value.isInitialized;

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
          opacity: isReady ? 1.0 : 0.0, 
          duration: const Duration(milliseconds: 500), // Slightly longer for smoothness
          child: isReady
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                       width: widget.controller!.value.size.width,
                       height: widget.controller!.value.size.height,
                       child: VideoPlayer(widget.controller!),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
