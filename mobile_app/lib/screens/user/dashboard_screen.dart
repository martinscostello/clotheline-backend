import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/booking/booking_sheet.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/models/app_content_model.dart';
import 'package:laundry_app/services/laundry_service.dart';
import 'package:laundry_app/services/store_service.dart';
import 'package:laundry_app/models/store_product.dart';
import 'package:laundry_app/screens/user/products/product_detail_screen.dart';
import 'package:laundry_app/utils/currency_formatter.dart';
import 'package:provider/provider.dart';
import 'package:laundry_app/screens/user/products/products_screen.dart';
import 'dart:convert';
import '../../../widgets/custom_cached_image.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import 'notifications/notifications_screen.dart';
import '../../providers/branch_provider.dart';
import '../common/branch_selection_screen.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import 'hero_video_player.dart'; // Added Import

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSwitchToStore;
  final ValueNotifier<int>? tabNotifier;

  const DashboardScreen({super.key, this.onSwitchToStore, this.tabNotifier});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  // Hero Carousel State
  final PageController _pageController = PageController();
  int _currentHeroIndex = 0;
  Timer? _carouselTimer;

  // Services
  late LaundryService _laundryService;
  late ContentService _contentService;
  
  AppContentModel? _appContent;
  bool _isHydrated = false; // The Hydration Gate
  bool _isTabActive = true; 

  Timer? _rotationTimer;

  // Throttling State
  static DateTime? _lastSyncTime;
  static const Duration _syncThrottle = Duration(seconds: 15); // Faster refresh (15s)
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Track Lifecycle
    
    // Defer provider access to next frame or didChangeDependencies, 
    // BUT we need to start hydration ASAP.
    // Provider access in initState is allowed if listen: false.
    _laundryService = Provider.of<LaundryService>(context, listen: false);
    _contentService = Provider.of<ContentService>(context, listen: false);

    // [HYDRATION-FIRST] Data is ALREADY here via Bootstrap.
    // We just render cache immediately.
    _isHydrated = true; 
    
    // Attempt to load content cache if not bootstrapped (ContentService wasn't strictly bootstrapped yet)
    _contentService.loadFromCache().then((content) {
       if (content != null && mounted) {
          setState(() { _appContent = content; });
       }
    });

    _scheduleNextSlide();
    
    // Rotate featured products every 60s
    _rotationTimer = Timer.periodic(const Duration(seconds: 60), (_) {
       if (mounted) {
         final branchId = Provider.of<BranchProvider>(context, listen: false).selectedBranch?.id;
         StoreService().fetchFeaturedProducts(branchId: branchId);
       }
    });
    
    // Listen to Tab Changes
    widget.tabNotifier?.addListener(_handleTabChange);
    
    // Silent Sync after render
    Future.microtask(() => _performSilentSync());
  }
  

  void _handleTabChange() {
    if (widget.tabNotifier == null) return;
    final isActive = widget.tabNotifier!.value == 0; // 0 is Dashboard
    if (isActive != _isTabActive) {
      if (mounted) {
         setState(() => _isTabActive = isActive);
      }
    }
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
          // [FIX] Kickstart carousel if it was waiting for data
          _scheduleNextSlide();
        }
      }
    });

    // B. Sync Laundry (Service handles diffing internally)
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    _laundryService.fetchFromApi(branchId: branchProvider.selectedBranch?.id);

    // C. Sync Store (Service handles diffing internally)
    StoreService().fetchFeaturedProducts(branchId: branchProvider.selectedBranch?.id);
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

  void _scheduleNextSlide() {
    _carouselTimer?.cancel();
    if (!mounted) return;
    
    final items = _getItems();
    // [FIX] Critical: "Continuous Check" - If no data, keep polling until it arrives.
    if (items.isEmpty) {
       _carouselTimer = Timer(const Duration(seconds: 1), _scheduleNextSlide);
       return;
    }
    
    // Safety check
    if (_currentHeroIndex >= items.length) _currentHeroIndex = 0;

    final currentItem = items[_currentHeroIndex];
    final isVideo = currentItem.mediaType == 'video';
    // [FIX] Timers: 10s Video, 5s Image
    final duration = isVideo ? const Duration(seconds: 10) : const Duration(seconds: 5);

    _carouselTimer = Timer(duration, () {
      if (!mounted) return;
      
      // [FIX] Critical: If controller isn't attached yet, KEEP TRYING.
      // This loop will never die until the UI is ready.
      if (!_pageController.hasClients) {
         _scheduleNextSlide(); // Recursive retry
         return;
      }

      final currentList = _getItems(); 
      if (currentList.isEmpty) {
        _scheduleNextSlide();
        return;
      }

      // [FIX] Single Item Loop Protection
      // animateToPage won't fire onPageChanged if page doesn't change (e.g. 0 -> 0).
      // So we must manually recurse for single items to keep the timer alive.
      if (currentList.length < 2) {
         _scheduleNextSlide();
         return;
      }

      int nextPage = _currentHeroIndex + 1;
      if (nextPage >= currentList.length) nextPage = 0;
      
      _pageController.animateToPage(
        nextPage, 
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic
      );
      // onPageChanged will handle the recursion
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentHeroIndex = index);
    // Restart timer when page changes (Manual or Automatic)
    _scheduleNextSlide();
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

    // BLOCKING BRANCH CHECK
    final branchProvider = Provider.of<BranchProvider>(context);
    if (branchProvider.selectedBranch == null && !branchProvider.isLoading) {
      // Force User to Select City
      return const BranchSelectionScreen(isModal: false); 
    }

    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(overscroll: false),
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _handleRefresh,
            color: isDark ? Colors.white : AppTheme.primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(), // Ensure scroll even if empty
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 112, 
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
             childAspectRatio: 1.1, // Match real grid (was 0.85)
             children: List.generate(4, (index) => Container(
               decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
             )),
           )
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return UnifiedGlassHeader(
      isDark: isDark,
      height: 112,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Consumer<AuthService>(
            builder: (context, auth, _) {
              final name = auth.currentUser?['name']?.toString().split(" ").first ?? "Friend";
              return Text(
                "Hi $name,",
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
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
                child: Row(
                  children: [
                    Text(
                      branchName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 18, color: isDark ? Colors.white54 : Colors.black54)
                  ],
                ),
              );
            }
          ),
        ],
      ),
      actions: [
        // Notifications Only
        IconButton(
           onPressed: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
           },
           padding: EdgeInsets.zero,
           icon: Stack(
             clipBehavior: Clip.none,
             children: [
               Icon(Icons.notifications_outlined, color: isDark ? Colors.white : Colors.black87, size: 28),
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
        clipBehavior: Clip.none, // Allow shadows to overflow
        onPageChanged: _onPageChanged,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final bool isActive = _currentHeroIndex == index;
          return Container(
            margin: const EdgeInsets.only(right: 10, left: 20),
            child: _buildHeroCard(item, items.length, isActive: isActive),
          );
        },
      ),
    );
  }



// ... (existing imports)

  Widget _buildHeroCard(HeroCarouselItem item, int totalItems, {bool isActive = false}) {
    // Combine Carousel Active + Tab Active
    final bool shouldPlay = isActive && _isTabActive;
    
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
      key: ValueKey("${item.imageUrl}${item.mediaType}"), // Force rebuild if media changes
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C), // Fallback background
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: item.mediaType == 'video' 
                    ? HeroVideoPlayer(
                        videoUrl: item.imageUrl,
                        isActive: shouldPlay, 
                      )
                    : CustomCachedImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        borderRadius: 24,
                      ),
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
      // Empty State
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.cleaning_services_outlined, size: 50, color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 15),
            Text(
              "No services here yet",
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              "We are working on bringing services to this city.",
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // LOCK ORDER
    var services = List.from(_laundryService.services);
    final order = {
      'Regular laundry': 1,
      'Footwears': 2,
      'Footwear': 2, // Alias
      'Rug cleaning': 3,
      'Home/Office cleaning': 4
    };
    
    services.sort((a, b) {
      int posA = 99;
      int posB = 99;
      
      order.forEach((key, val) {
        if (a.name.toLowerCase().contains(key.toLowerCase())) posA = val;
        if (b.name.toLowerCase().contains(key.toLowerCase())) posB = val;
      });
      
      return posA.compareTo(posB);
    });

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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
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
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            s.name,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                       const SizedBox(height: 4),
                       // Hide description for compactness if needed, or keep it small
                       if (s.description.isNotEmpty)
                         Expanded(
                           child: Text(
                              s.description,
                              maxLines: 2, // Allow 2 lines
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 10,
                                height: 1.2,
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
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                     backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                     title: Text(
                       s.lockedLabel.isNotEmpty ? s.lockedLabel : "Coming Soon", 
                       style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)
                     ),
                     content: Text(
                       "${s.name} is currently unavailable in this location.", 
                       style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)
                     ),
                     actions: [
                       TextButton(
                         onPressed: () => Navigator.pop(ctx),
                         child: const Text("Okay", style: TextStyle(color: AppTheme.primaryColor)),
                       ),
                       // Future: Add "Notify Me" here
                     ],
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
                clipBehavior: Clip.antiAlias,
                child: content
              ),
            ),
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
            child: const Row(
              children: [
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
            height: 120, 
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, color: isDark ? Colors.white24 : Colors.black12, size: 40),
                  const SizedBox(height: 10),
                  Text("No featured products", style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
                ],
              ),
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
           borderRadius: BorderRadius.circular(20), // Standardized to 20 for product images
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
