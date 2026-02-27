import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LaundryGlassBackground.dart';
import 'product_reviews_detail_screen.dart';

class ReviewModerationScreen extends StatelessWidget {
  const ReviewModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Review Moderation", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
        ),
        body: const LaundryGlassBackground(
          child: ReviewModerationBody(),
        ),
      ),
    );
  }
}

class ReviewModerationBody extends StatefulWidget {
  final bool isEmbedded;
  final Function(String, Map<String, dynamic>)? onNavigate;
  const ReviewModerationBody({super.key, this.isEmbedded = false, this.onNavigate});

  @override
  State<ReviewModerationBody> createState() => _ReviewModerationBodyState();
}

class _ReviewModerationBodyState extends State<ReviewModerationBody> {
  List<ReviewModel> _allReviews = [];
  Map<String, List<ReviewModel>> _groupedReviews = {};
  List<String> _filteredProductIds = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);
    final reviewService = Provider.of<ReviewService>(context, listen: false);
    final reviews = await reviewService.getAllReviewsAdmin();
    if (mounted) {
      _allReviews = reviews;
      _groupAndFilter();
      setState(() => _isLoading = false);
    }
  }

  void _groupAndFilter() {
    final Map<String, List<ReviewModel>> groups = {};
    for (var review in _allReviews) {
      if (!groups.containsKey(review.productId)) {
        groups[review.productId] = [];
      }
      groups[review.productId]!.add(review);
    }
    _groupedReviews = groups;
    
    _applySearch(_searchCtrl.text);
  }

  void _applySearch(String query) {
    if (query.isEmpty) {
      _filteredProductIds = _groupedReviews.keys.toList();
    } else {
      _filteredProductIds = _groupedReviews.keys.where((id) {
        final productName = _groupedReviews[id]!.first.productName.toLowerCase();
        return productName.contains(query.toLowerCase());
      }).toList();
    }
  }

  double _calculateAverageRating(List<ReviewModel> reviews) {
    if (reviews.isEmpty) return 0;
    final sum = reviews.fold(0, (prev, r) => prev + r.rating);
    return sum / reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Search Bar / Header
            Container(
              padding: EdgeInsets.only(top: widget.isEmbedded ? 10 : MediaQuery.of(context).padding.top + 10, left: 10, right: 10),
              child: Row(
                children: [
                  if (!widget.isEmbedded)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(25)),
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: "Search products...",
                          hintStyle: TextStyle(color: Colors.white30),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.white30, size: 20),
                        ),
                        onChanged: (val) => setState(() => _applySearch(val)),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: _fetchReviews,
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _filteredProductIds.isEmpty
                    ? const Center(child: Text("No products found", style: TextStyle(color: Colors.white70)))
                    : RefreshIndicator(
                        onRefresh: _fetchReviews,
                        color: Colors.white,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                          itemCount: _filteredProductIds.length,
                          itemBuilder: (context, index) {
                            final productId = _filteredProductIds[index];
                            final productReviews = _groupedReviews[productId]!;
                            final productName = productReviews.first.productName;
                            final avgRating = _calculateAverageRating(productReviews);

                            return _buildProductCard(productId, productName, productReviews, avgRating);
                          },
                        ),
                      ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductCard(String productId, String productName, List<ReviewModel> reviews, double avgRating) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
      onTap: () async {
        if (widget.isEmbedded && widget.onNavigate != null) {
          widget.onNavigate!('review_detail', {
            'productId': productId,
            'productName': productName,
            'reviews': reviews,
          });
        } else {
          final shouldRefresh = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductReviewsDetailScreen(
                productId: productId,
                productName: productName,
                reviews: reviews,
              ),
            ),
          );
          if (shouldRefresh == true) {
            _fetchReviews();
          }
        }
      },
        child: GlassContainer(
          opacity: 0.1,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 5),
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "${reviews.length} Reviews",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
