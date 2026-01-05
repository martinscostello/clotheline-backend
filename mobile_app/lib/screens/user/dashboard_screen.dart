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

  // Services
  final LaundryService _laundryService = LaundryService();
  final ContentService _contentService = ContentService();
  AppContentModel? _appContent;
  bool _isLoadingContent = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startCarouselTimer();
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _laundryService.fetchServices(),
      StoreService().fetchFeaturedProducts(),
      _fetchAppContent()
    ]);
  }

  Future<void> _fetchAppContent() async {
    final content = await _contentService.getAppContent();
    if (mounted) {
      setState(() {
        _appContent = content;
        _isLoadingContent = false;
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
                     if (_laundryService.isLoading && _laundryService.services.isEmpty) {
                       return const Center(child: CircularProgressIndicator());
                     }
                     
                     if (!_laundryService.isLoading && _laundryService.services.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off, size: 48, color: isDark ? Colors.white54 : Colors.black45),
                              const SizedBox(height: 10),
                              Text("Connection Lost", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: _fetchData, 
                                icon: const Icon(Icons.refresh),
                                label: const Text("Retry"),
                              )
                            ],
                          ),
                        );
                     }
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
          image: NetworkImage(item.imageUrl),
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
          mainAxisSize: MainAxisSize.min, // User commanded: HARD FIX
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

    // Sort: Unlocked first, then locked? Or by name? Default order likely fine.
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
                          image: s.image.startsWith('http') ? NetworkImage(s.image) : AssetImage(s.image) as ImageProvider,
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
                        maxLines: 1, // Reduced to 1 line to prevent overflow title
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                       // Helper text or description? Using description but truncated
                       Expanded( // Wrap in Expanded
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
        child: LiquidGlassContainer(
          radius: 20,
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
               Positioned.fill(
                 child: Stack(
                   fit: StackFit.expand,
                   children: [
                     Container(color: isDark ? Colors.white10 : Colors.grey[200]),
                     ClipRRect(
                       borderRadius: BorderRadius.circular(20),
                       child: product.imageUrls.isNotEmpty 
                          ? Image.network(
                              product.imageUrls.first, 
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null));
                              },
                              errorBuilder: (c,e,s) => const Icon(Icons.broken_image, color: Colors.grey)
                            )
                          : const Icon(Icons.shopping_bag, color: Colors.grey, size: 40),
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
                         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
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
      ),
    );
  }
}
