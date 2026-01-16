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
import 'dart:convert';
import '../../../widgets/custom_cached_image.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import 'chat/chat_screen.dart';
import 'notifications/notifications_screen.dart';
import '../../providers/branch_provider.dart';
import '../common/branch_selection_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSwitchToStore;

  const DashboardScreen({super.key, this.onSwitchToStore});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  // Hero Carousel State
  final PageController _pageController = PageController();
  int _currentHeroIndex = 0;
  Timer? _carouselTimer;

  // Services
  final LaundryService _laundryService = LaundryService();
  final ContentService _contentService = ContentService();
  
  AppContentModel? _appContent;
  bool _isHydrated = false; // The Hydration Gate

  Timer? _rotationTimer;

  // Throttling State
  static DateTime? _lastSyncTime;
  static const Duration _syncThrottle = Duration(seconds: 15); // Faster refresh (15s)
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Track Lifecycle
    _hydrateAndSync();
    _startCarouselTimer();
    
    // Rotate featured products every 60s
    _rotationTimer = Timer.periodic(const Duration(seconds: 60), (_) {
       if (mounted) StoreService().rotateFeaturedProducts();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _carouselTimer?.cancel();
    _rotationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // Monitor App Lifecycle to prevent "Too much work on resume"
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // iOS Strict Resume Policy:
      // Do NOT trigger sync on resume. Cache is sufficient.
      // This prevents resource watchdog kills on physical devices.
      debugPrint("App Resumed. Staying with cached data.");
    }
  }

  // 1. HYDRATION: Load Cache -> Render UI
  Future<void> _hydrateAndSync() async {
    // A. Load Content Cache
    final cachedContent = await _contentService.loadFromCache();
    
    // B. Load Laundry Cache (Wait for it to populate service list)
    await _laundryService.loadFromCache();

    // C. Load Store Cache (Internal cache load)
    // STRICT: Cache Only. Do not hit network yet.
    await StoreService().fetchFeaturedProducts(onlyCache: true); 

    if (mounted) {
      setState(() {
        _appContent = cachedContent;
        _isHydrated = true; // GATE OPEN: Render UI
      });
    }

    // 2. SILENT SYNC: Fetch Fresh Data in Background
    // DELAYED to avoid "heavy work" during initial frame rendering (Resume/Launch crash protection)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _performSilentSync();
    });
  }

  Future<void> _performSilentSync({bool isResume = false}) async {
    // Throttling Check
    // If we passed the check, update the timestamp
    final now = DateTime.now();
    if (_lastSyncTime != null && now.difference(_lastSyncTime!) < _syncThrottle) {
      // Check if we REALLY need to force it (e.g. pull to refresh bypasses this call usually)
      if (isResume) {
         debugPrint("Resume Sync Throttled. Last sync was ${_lastSyncTime?.toIso8601String()}");
         return; 
      }
    }
    
    _lastSyncTime = now;
    debugPrint("Starting Silent Sync... (isResume: $isResume)");

    // A. Sync Content
    _contentService.fetchFromApi().then((updatedContent) {
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

    // B. Sync Laundry (Service handles diffing internally)
    _laundryService.fetchFromApi();

    // C. Sync Store (Service handles diffing internally)
    StoreService().fetchFeaturedProducts();
  }
  
  // Pull-to-Refresh action
  Future<void> _handleRefresh() async {
     // Bypass throttle for user-initiated refresh
     _lastSyncTime = null; 
     await _performSilentSync();
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

    // HYDRATION GATE
    if (!_isHydrated) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: _buildDashboardSkeleton(isDark),
      );
    }

    return ScrollConfiguration(
      behavior: ScrollBehavior().copyWith(overscroll: false),
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _handleRefresh,
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
                   // Content Body
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

  
                  // Dynamic Service Grid Layout
                  ListenableBuilder(
                    listenable: _laundryService,
                    builder: (context, child) {
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

  // SKELETON LOADER (Shown only during cold launch)
  Widget _buildDashboardSkeleton(bool isDark) {
    Color color = isDark ? Colors.white10 : Colors.grey.shade200;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // Hero Skeleton
           Container(
             height: 200, 
             width: double.infinity,
             margin: const EdgeInsets.symmetric(horizontal: 20),
             decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
           ),
           const SizedBox(height: 30),
           // Title Skeleton
           Container(height: 20, width: 100, margin: const EdgeInsets.only(left: 20), color: color),
           const SizedBox(height: 15),
           // Grid Skeleton
           GridView.count(
             crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
             padding: const EdgeInsets.symmetric(horizontal: 20),
             crossAxisSpacing: 15, mainAxisSpacing: 15,
             childAspectRatio: 0.85,
             children: List.generate(4, (index) => Container(
               decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
             )),
           )
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
              Consumer<AuthService>(
                builder: (context, auth, _) {
                  final name = auth.currentUser?['name']?.toString().split(" ").first ?? "Friend";
                  return Text(
                    "Hi $name,",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                      shadows: [
                        if (isDark) const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                  );
                }
              ),
              Consumer<BranchProvider>(
                builder: (context, branchProvider, _) {
                  final branchName = branchProvider.selectedBranch?.name ?? "Select City";
                  return GestureDetector(
                    onTap: () {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchSelectionScreen(isModal: true)));
                    },
                    child: Text(
                      "Clotheline · $branchName",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                        shadows: [
                          if (isDark) const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  );
                }
              ),
            ],
          ),
          
          // Header Actions (Capsule)
          LiquidGlassContainer(
            radius: 30, // Capsule Shape
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chat Support
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen()));
                  },
                  child: Icon(Icons.support_agent_rounded, color: isDark ? Colors.white : Colors.black87, size: 24),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(width: 1, height: 20, color: isDark ? Colors.white24 : Colors.black12),
                ),
                
                // Notifications
                GestureDetector(
                   onTap: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen()));
                   },
                   child: Stack(
                     clipBehavior: Clip.none,
                     children: [
                       Icon(Icons.notifications_outlined, color: isDark ? Colors.white : Colors.black87, size: 24),
                       // Consumer for badge could go here
                       Consumer<NotificationService>(
                         builder: (context, ns, _) {
                           if (ns.unreadCount > 0) {
                             return Positioned(
                               top: -2, right: -2,
                               child: Container(
                                 width: 10, height: 10,
                                 decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                               ),
                             );
                           }
                           return const SizedBox();
                         }
                       )
                     ],
                   ),
                )
              ],
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
      ),
      child: Stack(
        children: [
            Positioned.fill(
              child: CustomCachedImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                borderRadius: 24,
              ),
            ),
            Positioned.fill(
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
            ),

          ],
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
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 1.1, // More compact (was 0.85)
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
                          borderRadius: BorderRadius.circular(16), 
                        ),
                        child: CustomCachedImage(
                            imageUrl: s.image,
                            fit: BoxFit.cover,
                            borderRadius: 16,
                        ),
                      ),
                    // Discount / Status Badge
                     if (s.isLocked)
                      Positioned(
                        top: 8, right: 8,
                        child: _buildBadge(s.lockedLabel, Colors.blueAccent),
                      )
                     else if (s.discountPercentage > 0)
                      Positioned(
                        top: 8, right: 8,
                        child: _buildBadge(s.discountLabel.isNotEmpty ? s.discountLabel : "${s.discountPercentage.toStringAsFixed(0)}% OFF", Colors.pinkAccent),
                      )
                  ],
                ),
              ),
              // Text Bottom
              Expanded(
                flex: 2, // Reducing text space
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
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
                          fontSize: 13,
                        ),
                      ),
                       // Hide description for compactness if needed, or keep it small
                       if (s.description.isNotEmpty)
                         Text(
                            s.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 10,
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
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2C) : Colors.white, // Solid dark for dark mode
                borderRadius: BorderRadius.circular(20),
                border: isDark ? Border.all(color: Colors.white10) : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                  if (!isDark)
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
                     child: CustomCachedImage(
                       imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : "",
                       fit: BoxFit.cover,
                       borderRadius: 20,
                       // handles fallback
                     ),
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
