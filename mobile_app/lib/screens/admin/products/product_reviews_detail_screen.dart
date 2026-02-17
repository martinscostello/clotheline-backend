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

class ProductReviewsDetailScreen extends StatelessWidget {
  final String productId;
  final String productName;
  final List<ReviewModel> reviews;

  const ProductReviewsDetailScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(productName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context, true),
          ),
          centerTitle: true,
        ),
        body: LaundryGlassBackground(
          child: ProductReviewsDetailBody(
            productId: productId,
            productName: productName,
            reviews: reviews,
          ),
        ),
      ),
    );
  }
}

class ProductReviewsDetailBody extends StatefulWidget {
  final String productId;
  final String productName;
  final List<ReviewModel> reviews;
  final bool isEmbedded;

  const ProductReviewsDetailBody({
    super.key,
    required this.productId,
    required this.productName,
    required this.reviews,
    this.isEmbedded = false,
  });

  @override
  State<ProductReviewsDetailBody> createState() => _ProductReviewsDetailBodyState();
}

class _ProductReviewsDetailBodyState extends State<ProductReviewsDetailBody> {
  late List<ReviewModel> _reviews;

  @override
  void initState() {
    super.initState();
    _reviews = List.from(widget.reviews);
  }

  Future<void> _toggleVisibility(ReviewModel review) async {
    final reviewService = Provider.of<ReviewService>(context, listen: false);
    final success = await reviewService.toggleVisibility(review.id);
    if (success && mounted) {
      ToastUtils.show(context, "Review visibility updated", type: ToastType.success);
      setState(() {
        final index = _reviews.indexWhere((r) => r.id == review.id);
        if (index != -1) {
          _reviews[index] = ReviewModel(
            id: review.id,
            userId: review.userId,
            userName: review.userName,
            productId: review.productId,
            productName: review.productName,
            orderId: review.orderId,
            rating: review.rating,
            comment: review.comment,
            images: review.images,
            isHidden: !review.isHidden,
            createdAt: review.createdAt,
          );
        }
      });
    } else if (mounted) {
      ToastUtils.show(context, "Failed to update visibility", type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _reviews.isEmpty
        ? const Center(child: Text("No reviews for this product", style: TextStyle(color: Colors.white70)))
        : ListView.builder(
            padding: EdgeInsets.only(
              top: widget.isEmbedded ? 20 : MediaQuery.of(context).padding.top + 80, 
              bottom: 40, left: 20, right: 20
            ),
            itemCount: _reviews.length,
            itemBuilder: (context, index) {
              final review = _reviews[index];
              return _buildReviewCard(review);
            },
          );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: GlassContainer(
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
                Text("Review ID: ${review.id.substring(review.id.length - 6)}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
