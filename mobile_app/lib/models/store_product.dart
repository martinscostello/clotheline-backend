import 'package:flutter/material.dart';

class StoreProduct {
  final String id;
  final String name;
  final String description;
  final List<String> imageUrls;
  final double price;
  final double originalPrice;
  
  // Social Proof & Urgency
  final int soldCount;
  final double rating;
  final int reviewCount;
  final int stockLevel; // For "Only 4 left"
  
  // Marketing / Admin Controlled
  final String? badgeText; // "Almost Sold Out", "-50%"
  final String? badgeColorHex; // Hex color for badge background
  final bool isFlashDeal;
  final DateTime? dealEndTime;
  final bool isFreeShipping;
  
  final String category; // [NEW] Category for grouping
  final List<ProductVariant> variants;

  StoreProduct({
    required this.id,
    required this.name,
    required this.category, 
    required this.imageUrls,
    this.description = "",
    required this.price,
    required this.originalPrice,
    this.soldCount = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.stockLevel = 100,
    this.badgeText,
    this.badgeColorHex,
    this.isFlashDeal = false,
    this.isFreeShipping = false,
    this.dealEndTime,
    this.variants = const [],
  });
  
  // Backward compatibility getter
  String get imagePath => imageUrls.isNotEmpty ? imageUrls.first : 'assets/images/service_laundry.png';

  // Calculate discount percentage dynamically if needed
  int get discountPercent {
    if (originalPrice <= price) return 0;
    return ((originalPrice - price) / originalPrice * 100).round();
  }

  double get savedAmount => originalPrice > price ? originalPrice - price : 0;

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    return StoreProduct(
      id: json['_id'],
      name: json['name'],
      category: json['category'] ?? "Uncategorized",
      imageUrls: (json['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      description: json['description'] ?? "",
      price: (json['price'] as num).toDouble(),
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ?? (json['price'] as num).toDouble(),
      soldCount: json['soldCount'] ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      stockLevel: json['stock'] ?? 0,
      isFreeShipping: json['isFreeShipping'] ?? false,
      // Mapping variants from backend structure {name, price}
      variants: (json['variations'] as List?)?.map((e) => ProductVariant.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'price': price,
      'imageUrls': imageUrls,
      'description': description,
      'originalPrice': originalPrice,
      'stock': stockLevel,
      'isFreeShipping': isFreeShipping,
      'variations': variants.map((e) => e.toJson()).toList(),
    };
  }
}

class ProductVariant {
  final String id;
  final String name; // e.g. "100ml", "Red"
  final double price;
  final double originalPrice;
  
  ProductVariant({
    required this.id, 
    required this.name, 
    required this.price, 
    required this.originalPrice
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    double p = (json['price'] as num?)?.toDouble() ?? 0.0;
    double op = (json['originalPrice'] as num?)?.toDouble() ?? p;
    
    return ProductVariant(
      id: json['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'],
      price: p,
      originalPrice: op,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'originalPrice': originalPrice,
  };
}

class StoreCartItem {
  final StoreProduct product;
  final ProductVariant? variant;
  final int quantity;
  
  StoreCartItem({required this.product, this.variant, required this.quantity});
  
  double get price => variant?.price ?? product.price;
  double get totalPrice => price * quantity;
}
