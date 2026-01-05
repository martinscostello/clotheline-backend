import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/booking/booking_sheet.dart';
import 'package:liquid_glass_ui/liquid_glass_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/models/app_content_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Hero Carousel State
  final PageController _pageController = PageController();
  int _currentHeroIndex = 0;
  Timer? _carouselTimer;

  // Hero Data
  final List<Map<String, String>> _heroItems = [
    {
      "image": "assets/images/hero_offer.png",
      "title": "15% Off First Order",
      "subtitle": "Use code FRESH15 for your first laundry booking.",
    },
    {
      "image": "assets/images/service_shoes.png", 
      "title": "Premium Sneaker Care",
      "subtitle": "Bring your kicks back to life with our detailed cleaning.",
    },
    {
      "image": "assets/images/service_laundry.png",
      "title": "Express 24h Delivery",
      "subtitle": "Need it fast? We deliver clean clothes in 24 hours.",
    },
  ];

  // Service Grid Data
  final List<Map<String, dynamic>> _serviceCategories = [
    {
      "name": "Regular & Bulk Laundry",
      "subtitle": "Shirt, Trouser, Duvet, Blanket",
      "image": "assets/images/service_laundry.png",
      "badge": "15% Off",
      "badgeColor": Colors.pinkAccent
    },
    {
      "name": "Footwears",
      "subtitle": "Shoes, Canvas, Boots, etc",
      "image": "assets/images/service_shoes.png",
      "badge": "10% Off",
      "badgeColor": Colors.redAccent
    },
    {
      "name": "Rug Cleaning",
      "subtitle": "Rug & Carpet",
      "image": "assets/images/service_rug.png",
      "badge": "Coming Soon",
      "badgeColor": Colors.blueAccent
    },
    {
      "name": "House Cleaning",
      "subtitle": "All House Cleaning Service",
      "image": "assets/images/service_house_cleaning.png",
      "badge": "Coming Soon",
      "badgeColor": Colors.blueAccent
    },
  ];

  // Dynamic Content State
  final ContentService _contentService = ContentService();
  AppContentModel? _appContent;
  bool _isLoadingContent = true;

  @override
  void initState() {
    super.initState();
    _fetchAppContent();
    _startCarouselTimer();
  }


  Future<void> _fetchAppContent() async {
    final content = await _contentService.getAppContent();
    if (mounted) {
      setState(() {
        _appContent = content;
        _isLoadingContent = false;
        // If content loaded, reset carousel to 0 just in case
        _currentHeroIndex = 0;
      });
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<dynamic> _getItems() {
    if (_appContent != null && _appContent!.heroCarousel.isNotEmpty) {
      return _appContent!.heroCarousel;
    }
    return _heroItems;
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final items = _getItems();
      if (items.isEmpty) return;

      if (_currentHeroIndex < items.length - 1) {
        _currentHeroIndex++;
      } else {
        _currentHeroIndex = 0;
      }
      
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentHeroIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark, 
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light, 
    ));

    return ScrollConfiguration(
      behavior: ScrollBehavior().copyWith(overscroll: false),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 80, 
              bottom: 120
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCarousel(),
                const SizedBox(height: 30),
                
                // Categories Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Categories",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // New Service Grid Layout
                _buildServiceGrid(context, isDark),
                const SizedBox(height: 30),

                // Featured
                _buildFeaturedHeader(isDark),
                const SizedBox(height: 15),
                _buildFeaturedProductsList(isDark),
              ],
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.8),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Good Morning",
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                  shadows: [
                    if (isDark) const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              ),
              Text(
                "DirectorM",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                  shadows: [
                    if (isDark) const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ],
          ),
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: LiquidGlassContainer(
              radius: 50,
              padding: EdgeInsets.zero,
              child: Center(
                child: Icon(Icons.notifications_none_rounded, color: isDark ? Colors.white : Colors.black87),
              ), 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCarousel() {
    final items = _getItems();
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      width: double.infinity,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentHeroIndex = index),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            margin: const EdgeInsets.only(right: 10, left: 20),
            child: _buildHeroCard(item, items.length),
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(dynamic item, int totalItems) {
    String image, title, subtitle;
    
    if (item is HeroCarouselItem) {
      image = item.imageUrl;
      title = item.title ?? "";
      subtitle = item.actionUrl ?? ""; // Using actionUrl as subtitle placeholder for now or ""
    } else {
      image = item['image']!;
      title = item['title']!;
      subtitle = item['subtitle']!;
    }

    // Determine Image Source (Asset vs Network)
    final imageProvider = image.startsWith('assets') 
        ? AssetImage(image) as ImageProvider
        : NetworkImage(image);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: List.generate(totalItems, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _currentHeroIndex == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: _currentHeroIndex == index ? Colors.white : Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceGrid(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 0.85, 
        ),
        itemCount: _serviceCategories.length,
        itemBuilder: (context, index) {
          final cat = _serviceCategories[index];
          
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Top - [FIX] Rounded 4 Sides
              Expanded(
                flex: 4,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        // [FIX] Full Rounding as requested
                        borderRadius: BorderRadius.circular(20), 
                        image: DecorationImage(
                          image: AssetImage(cat['image']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Badge
                     if (cat['badge'] != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cat['badgeColor'],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cat['badge'],
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Text Bottom
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          cat['name'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          cat['subtitle'] ?? "",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

          return GestureDetector(
            onTap: () {
              if (cat['badge'] == "Coming Soon") {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${cat['name']} is coming soon!"),
                    backgroundColor: isDark ? Colors.white10 : Colors.black87,
                    behavior: SnackBarBehavior.floating,
                  )
                );
                return;
              }

               showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => BookingSheet(categoryName: cat['name']),
              );
            },
            child: isDark 
              // Dark Mode: Glass Card
              ? LiquidGlassContainer(
                  radius: 20,
                  opacity: 0.1, // Glass Effect Opacity (not content)
                  padding: EdgeInsets.zero,
                  child: content, 
                ).animate().scale(delay: (100 * index).ms, duration: 400.ms)
              // Light Mode: White Card
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: content
                  ),
                ).animate().scale(delay: (100 * index).ms, duration: 400.ms),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedHeader(bool isDark) {
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 20),
       child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Featured Products", 
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold, 
              color: isDark ? Colors.white : Colors.black87
            )
          ),
          TextButton(
            onPressed: () {},
            child: Row(
              children: const [
                Text("View All", style: TextStyle(color: Colors.blueAccent)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.blueAccent),
              ],
            ),
          ),
        ],
       ),
    );
  }

  Widget _buildFeaturedProductsList(bool isDark) {
    return SizedBox(
      height: 160,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none, 
        padding: const EdgeInsets.only(left: 20),
        children: [
          _buildProductCard('assets/images/product_pods.png', 'Detergent Pods', isDark),
          _buildProductCard('assets/images/product_softener.png', 'Fabric Softener', isDark),
          _buildProductCard('assets/images/product_basket.png', 'Laundry Basket', isDark),
        ],
      ),
    );
  }

  Widget _buildProductCard(String imagePath, String label, bool isDark) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 15),
      child: LiquidGlassContainer(
        radius: 20,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
             Positioned.fill(
               child: ClipRRect(
                 // [FIX] Full Rounding in all corners
                 borderRadius: BorderRadius.circular(20),
                 child: Image.asset(imagePath, fit: BoxFit.cover)
               ),
             ),
             // [FIX] Removed heavy black background/gradient for Dark Mode visibility issue
             // Only small bottom shade for text
             Positioned(
               bottom: 0,
               left: 0,
               right: 0,
               height: 60,
               child: Container(
                 decoration: BoxDecoration(
                   borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                   gradient: LinearGradient(
                     begin: Alignment.topCenter,
                     end: Alignment.bottomCenter,
                     colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                   ),
                 ),
               ),
             ),
             Align(
               alignment: Alignment.bottomCenter,
               child: Padding(
                 padding: const EdgeInsets.all(12.0),
                 child: Text(
                   label, 
                   textAlign: TextAlign.center,
                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                 ),
               ),
             ),
          ],
        ),
      ),
    );
  }
}
