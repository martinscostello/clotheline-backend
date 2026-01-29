import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/review_service.dart';
import '../../../../models/review_model.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LaundryGlassBackground.dart';
import 'product_reviews_detail_screen.dart';

class ReviewModerationScreen extends StatefulWidget {
  const ReviewModerationScreen({super.key});

  @override
  State<ReviewModerationScreen> createState() => _ReviewModerationScreenState();
}

class _ReviewModerationScreenState extends State<ReviewModerationScreen> {
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
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: _isSearching 
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Search product name...",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _applySearch(val)),
              )
            : const Text("Review Moderation", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _isSearching = false;
                    _searchCtrl.clear();
                    _applySearch("");
                  } else {
                    _isSearching = true;
                  }
                });
              },
            ),
          ],
          centerTitle: true,
        ),
        body: LaundryGlassBackground(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _filteredProductIds.isEmpty
                  ? const Center(child: Text("No products found", style: TextStyle(color: Colors.white70)))
                  : RefreshIndicator(
                      onRefresh: _fetchReviews,
                      color: Colors.white,
                      child: ListView.builder(
                        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 80, bottom: 40, left: 20, right: 20),
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
      ),
    );
  }

  Widget _buildProductCard(String productId, String productName, List<ReviewModel> reviews, double avgRating) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: () async {
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
