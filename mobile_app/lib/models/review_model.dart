class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String productId;
  final String orderId;
  final int rating;
  final String? comment;
  final List<String> images;
  final bool isHidden;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.productId,
    required this.orderId,
    required this.rating,
    this.comment,
    this.images = const [],
    this.isHidden = false,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['_id'],
      userId: json['user'] is Map ? json['user']['_id'] : json['user'],
      userName: json['user'] is Map ? json['user']['name'] : 'User',
      productId: json['product'] is Map ? json['product']['_id'] : (json['product'] ?? ''),
      orderId: json['order'],
      rating: json['rating'],
      comment: json['comment'],
      images: List<String>.from(json['images'] ?? []),
      isHidden: json['isHidden'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
