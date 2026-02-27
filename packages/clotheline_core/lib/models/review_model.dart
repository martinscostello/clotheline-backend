class ReviewModel {
  final String id;
  final String? userId; // Nullable for admin reviews
  final String userName;
  final String productId;
  final String productName;
  final String? orderId; // Nullable for admin reviews
  final int rating;
  final String? comment;
  final List<String> images;
  final bool isHidden;
  final bool isAdminGenerated;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    this.userId,
    required this.userName,
    required this.productId,
    this.productName = 'Unknown Product',
    this.orderId,
    required this.rating,
    this.comment,
    this.images = const [],
    this.isHidden = false,
    this.isAdminGenerated = false,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['_id'],
      userId: json['user'] is Map ? json['user']['_id'] : json['user'],
      userName: json['isAdminGenerated'] == true 
          ? (json['userName'] ?? 'Customer')
          : (json['user'] is Map ? json['user']['name'] : (json['userName'] ?? 'User')),
      productId: json['product'] is Map ? json['product']['_id'] : (json['product'] ?? ''),
      productName: json['product'] is Map ? (json['product']['name'] ?? 'Product') : 'Product',
      orderId: json['order'],
      rating: json['rating'],
      comment: json['comment'],
      images: List<String>.from(json['images'] ?? []),
      isHidden: json['isHidden'] ?? false,
      isAdminGenerated: json['isAdminGenerated'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
