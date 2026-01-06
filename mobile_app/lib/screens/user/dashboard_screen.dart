import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/booking/booking_sheet.dart';
import 'package:liquid_glass_ui/liquid_glass_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/models/app_content_model.dart';
import 'package:laundry_app/services/laundry_service.dart';
import 'package:laundry_app/services/store_service.dart';
import 'package:laundry_app/models/store_product.dart';
import 'package:laundry_app/screens/user/products/product_detail_screen.dart';
import 'package:laundry_app/utils/currency_formatter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:laundry_app/screens/user/products/products_screen.dart';
import 'dart:convert'; // For robust comparison check

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSwitchToStore;

  const DashboardScreen({super.key, this.onSwitchToStore});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Hero Carousel State
  final PageController _pageController = PageController();
  int _currentHeroIndex = 0;
  Timer? _carouselTimer;

  // Services
  final LaundryService _laundryService = LaundryService();
  final ContentService _contentService = ContentService();
  AppContentModel? _appContent;
  bool _isLoadingContent = true;

  Timer? _rotationTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startCarouselTimer();
    
    // Rotate featured products every 60s
    _rotationTimer = Timer.periodic(const Duration(seconds: 60), (_) {
       StoreService().rotateFeaturedProducts();
    });
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _laundryService.fetchServices(),
      StoreService().fetchFeaturedProducts(),
      _fetchAppContent()
    ]);
  }

  Future<void> _fetchAppContent() async {
    // 1. Fast Load (Cache or Defaults) - Instant
    if (_appContent == null) {
      final content = await _contentService.getAppContent();
      if (mounted) {
        setState(() {
          _appContent = content;
          _isLoadingContent = false;
        });
      }
    }

    // 2. Background Refresh (Silent)
    _contentService.refreshAppContent().then((updatedContent) {
      if (updatedContent != null && mounted) {
        final currentJson = jsonEncode(_appContent?.toJson());
        final newJson = jsonEncode(updatedContent.toJson());

        if (currentJson != newJson) {
           debugPrint("Content updated from server. Refreshing UI.");
           setState(() {
            _appContent = updatedContent;
          });
        }
      }
    });
  }


  @override
  void dispose() {
    _carouselTimer?.cancel();
    _rotationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<HeroCarouselItem> _getItems() {
    if (_appContent != null && _appContent!.heroCarousel.isNotEmpty) {
      return _appContent!.heroCarousel;
    }
    return [];
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
          RefreshIndicator(
            onRefresh: _fetchData,
            color: isDark ? Colors.white : AppTheme.primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(), // Ensure scroll even if empty
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
                      "Services",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
  
                  // Dynamic Service Grid Layout
                  ListenableBuilder(
                    listenable: _laundryService,
                    builder: (context, child) {
                       // Never show spinner, always show grid (defaults handle the content)
                       return _buildServiceGrid(context, isDark);
                    }
                  ),
                  const SizedBox(height: 30),
  
                  // Featured
                  _buildFeaturedHeader(isDark),
                  const SizedBox(height: 15),
                  _buildFeaturedProductsList(isDark),
                ],
              ),
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
                _appContent?.brandText ?? "Good Morning",
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                  shadows: [
                    if (isDark) const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              ),
              Text(
                "Clotheline",
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

  Widget _buildHeroCard(HeroCarouselItem item, int totalItems) {
    // Parse Colors
    Color titleClr = Colors.white;
    Color tagClr = Colors.white70;
    try {
      if (item.titleColor != null) {
         String hex = item.titleColor!.replaceAll("0x", "").replaceAll("#", "");
         if (hex.length == 6) hex = "FF$hex";
         titleClr = Color(int.parse(hex, radix: 16));
      }
       if (item.tagLineColor != null) {
         String hex = item.tagLineColor!.replaceAll("0x", "").replaceAll("#", "");
         if (hex.length == 6) hex = "FF$hex";
         tagClr = Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}

    return Container(
      key: ValueKey("${item.imageUrl}${item.titleColor}${item.tagLineColor}${item.tagLine}"), // Force rebuild on any property change
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: DecorationImage(
          image: (item.imageUrl.isNotEmpty && item.imageUrl.startsWith('http'))
              ? CachedNetworkImageProvider(item.imageUrl)
              : const AssetImage('assets/images/error_placeholder.png') as ImageProvider,
          fit: BoxFit.cover,
          onError: (exception, stackTrace) {
             debugPrint("Image Load Error: $exception");
          } 
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.0)],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.title ?? "",
              style: TextStyle(
                color: titleClr,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (item.tagLine != null && item.tagLine!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.tagLine!,
                  style: TextStyle(
                    color: tagClr,
                    fontSize: 14,
                  ),
                ),
              ),
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
    if (_laundryService.services.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text("No services available.", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
      );
    }

    var services = _laundryService.services;
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
        itemCount: services.length,
        itemBuilder: (context, index) {
          final s = services[index];
          
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Top
              Expanded(
                flex: 4,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20), 
                        image: DecorationImage(
                          image: s.image.startsWith('http') 
                            ? CachedNetworkImageProvider(s.image)
                            : AssetImage(s.image) as ImageProvider,
                          fit: BoxFit.cover,
                          onError: (_,__) {} 
                        ),
                      ),
                    ),
                    // Discount / Status Badge
                     if (s.isLocked)
                      Positioned(
                        top: 10, right: 10,
                        child: _buildBadge(s.lockedLabel, Colors.blueAccent),
                      )
                     else if (s.discountPercentage > 0)
                      Positioned(
                        top: 10, right: 10,
                        child: _buildBadge(s.discountLabel.isNotEmpty ? s.discountLabel : "${s.discountPercentage.toStringAsFixed(0)}% OFF", Colors.pinkAccent),
                      )
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
                      Text(
                        s.name,
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                       Expanded( 
                         child: Text(
                            s.description,
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
              if (s.isLocked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${s.name} is coming soon!"),
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
                builder: (context) => BookingSheet(serviceModel: s),
              );
            },
            child: isDark 
              ? LiquidGlassContainer(
                  radius: 20,
                  opacity: 0.1,
                  padding: EdgeInsets.zero,
                  child: content, 
                ).animate().scale(delay: (100 * index).ms, duration: 400.ms)
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.05),
                        blurRadius: 5,
                        spreadRadius: 0,
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

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
            onPressed: () {
              if (widget.onSwitchToStore != null) {
                widget.onSwitchToStore!();
              } else {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const ProductsScreen())
                );
              }
            },
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
    return ListenableBuilder(
      listenable: StoreService(),
      builder: (context, _) {
        final products = StoreService().featuredProducts;
        final isLoading = StoreService().isLoading;

        if (isLoading && products.isEmpty) {
          return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
        }

        if (products.isEmpty) {
          return SizedBox(
            height: 100, 
            child: Center(
              child: Text("No newly added products", style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
            )
          );
        }

        return SizedBox(
          height: 180, // Increased slightly for better layout
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none, 
            padding: const EdgeInsets.only(left: 20),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(products[index], isDark);
            },
          ),
        );
      },
    );
  }
  Widget _buildProductCard(StoreProduct product, bool isDark) {
    return GestureDetector(
      onTap: () {
         Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: product),
            ),
          );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
           color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
           borderRadius: BorderRadius.circular(16),
           boxShadow: [
             if (!isDark)
             BoxShadow(
               color: Colors.black.withOpacity(0.1),
               blurRadius: 10,
               offset: const Offset(0, 4),
             )
           ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
             Positioned.fill(
               child: Stack(
                 fit: StackFit.expand,
                 children: [
                   Container(color: isDark ? Colors.white10 : Colors.grey[100]),
                   ClipRRect(
                     borderRadius: BorderRadius.circular(20),
                     child: product.imageUrls.isNotEmpty 
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrls.first, 
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[300])),
                            errorWidget: (context, url, error) => Image.asset('assets/images/error_placeholder.png', fit: BoxFit.cover),
                          )
                        : Image.asset('assets/images/error_placeholder.png', fit: BoxFit.cover),
                   ),
                 ],
               ),
             ),
             // Discount Badge
             if (product.discountPercentage > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "-${product.discountPercentage.toStringAsFixed(0)}%",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
             Positioned(
               bottom: 0,
               left: 0,
               right: 0,
               height: 70,
               child: Container(
                 decoration: BoxDecoration(
                   borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                   gradient: LinearGradient(
                     begin: Alignment.topCenter,
                     end: Alignment.bottomCenter,
                     colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                   ),
                 ),
               ),
             ),
             Align(
               alignment: Alignment.bottomCenter,
               child: Padding(
                 padding: const EdgeInsets.all(12.0),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Text(
                       product.name, 
                       textAlign: TextAlign.center,
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                       style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                     ),
                     const SizedBox(height: 4),
                     Text(
                       CurrencyFormatter.format(product.price),
                       style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 12),
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
}
