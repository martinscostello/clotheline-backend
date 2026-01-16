import 'package:flutter/material.dart';
import 'custom_cached_image.dart'; // Unified image handler

class FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenGallery({
    super.key, 
    required this.imageUrls, 
    this.initialIndex = 0
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}



class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main Swipable Gallery
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final url = widget.imageUrls[index];
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CustomCachedImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          
          // Close Button
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Bottom Thumbnails
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.imageUrls.length,
                itemBuilder: (context, index) {
                  final url = widget.imageUrls[index];
                  final isSelected = _currentIndex == index;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index, 
                        duration: const Duration(milliseconds: 300), 
                        curve: Curves.easeInOut
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 60,
                      decoration: BoxDecoration(
                        border: isSelected ? Border.all(color: const Color(0xFFFF5722), width: 2) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CustomCachedImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          borderRadius: 6,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}
