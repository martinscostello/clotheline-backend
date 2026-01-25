import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/review_service.dart';
import '../../../../models/review_model.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LaundryGlassBackground.dart';
import '../../../../utils/toast_utils.dart';
import '../../../../widgets/custom_cached_image.dart';
import '../../../../widgets/fullscreen_gallery.dart';

class ReviewModerationScreen extends StatefulWidget {
  const ReviewModerationScreen({super.key});

  @override
  State<ReviewModerationScreen> createState() => _ReviewModerationScreenState();
}

class _ReviewModerationScreenState extends State<ReviewModerationScreen> {
  List<ReviewModel> _reviews = [];
  bool _isLoading = true;

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
      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleVisibility(ReviewModel review) async {
    final reviewService = Provider.of<ReviewService>(context, listen: false);
    final success = await reviewService.toggleVisibility(review.id);
    if (success && mounted) {
      ToastUtils.show(context, "Review visibility updated", type: ToastType.success);
      _fetchReviews();
    } else if (mounted) {
      ToastUtils.show(context, "Failed to update visibility", type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Review Moderation", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: LaundryGlassBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _reviews.isEmpty
                ? const Center(child: Text("No reviews found", style: TextStyle(color: Colors.white70)))
                : RefreshIndicator(
                    onRefresh: _fetchReviews,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _reviews.length,
                      itemBuilder: (context, index) {
                        final review = _reviews[index];
                        return _buildReviewCard(review);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return GlassContainer(
      opacity: 0.1,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    "Rating: ${review.rating} ⭐",
                    style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Switch(
                value: !review.isHidden, 
                onChanged: (_) => _toggleVisibility(review),
                activeColor: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (review.comment != null && review.comment!.isNotEmpty)
            Text(review.comment!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          if (review.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: review.images.length,
                itemBuilder: (context, idx) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenGallery(
                          imageUrls: review.images,
                          initialIndex: idx,
                        )));
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CustomCachedImage(
                          imageUrl: review.images[idx],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const Divider(color: Colors.white12, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}",
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              const Text("Review ID: ...", style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    ) as Widget; // Cast because GlassContainer might return a complex widget
  }
}
