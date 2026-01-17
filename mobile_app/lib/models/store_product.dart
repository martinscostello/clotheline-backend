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
  
  final String brand;
  final List<ProductReview> reviews; // [NEW]
  final String category; 
  final List<ProductVariant> variants;
  final List<BranchProductInfo> branchInfo; // [NEW]

  StoreProduct({
    required this.id,
    required this.name,
    this.brand = "Generic", // Default
    this.reviews = const [], // Default
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
    this.branchInfo = const [], // [NEW]
  });
  
  // Backward compatibility getter
  String get imagePath => imageUrls.isNotEmpty ? imageUrls.first : 'assets/images/service_laundry.png';

  // Calculate discount percentage dynamically if needed
  int get discountPercent {
    if (originalPrice <= price) return 0;
    return ((originalPrice - price) / originalPrice * 100).round();
  }
  
  double get discountPercentage => discountPercent.toDouble();

  double get savedAmount => originalPrice > price ? originalPrice - price : 0;

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return StoreProduct(
      id: json['_id'] ?? "unknown_id",
      name: json['name'] ?? "Unnamed Product",
      brand: json['brand'] ?? "Generic",
      category: json['category'] ?? "Uncategorized",
      imageUrls: (json['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      description: json['description'] ?? "",
      price: parseDouble(json['price']),
      originalPrice: parseDouble(json['originalPrice'] ?? json['price']),
      soldCount: json['soldCount'] ?? 0,
      rating: parseDouble(json['rating']),
      reviews: (json['reviews'] as List?)?.map((e) => ProductReview.fromJson(e)).toList() ?? [],
      reviewCount: (json['reviews'] as List?)?.length ?? 0, 
      stockLevel: json['stock'] ?? 0,
      isFreeShipping: json['isFreeShipping'] ?? false,
      variants: (json['variations'] as List?)?.map((e) => ProductVariant.fromJson(e)).toList() ?? [],
      branchInfo: (json['branchInfo'] is List) 
          ? (json['branchInfo'] as List).where((e) => e is Map).map((e) => BranchProductInfo.fromJson(Map<String, dynamic>.from(e))).toList() 
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'brand': brand,
      'category': category,
      'price': price,
      'imageUrls': imageUrls,
      'description': description,
      'originalPrice': originalPrice,
      'stock': stockLevel,
      'isFreeShipping': isFreeShipping,
      'variations': variants.map((e) => e.toJson()).toList(),
      'branchInfo': branchInfo.map((e) => e.toJson()).toList(),
      // Reviews usually not sent back on product update
    };
  }
}

class ProductReview {
  final String userName;
  final double rating;
  final String comment;
  final DateTime date;

  ProductReview({required this.userName, required this.rating, required this.comment, required this.date});

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    return ProductReview(
      userName: json['userName'] ?? "Anonymous",
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      comment: json['comment'] ?? "",
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    );
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
      name: json['name'] ?? "Unknown Variant",
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

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'variant': variant?.toJson(),
    'quantity': quantity,
  };

  factory StoreCartItem.fromJson(Map<String, dynamic> json) {
    return StoreCartItem(
      product: StoreProduct.fromJson(json['product']),
      variant: json['variant'] != null ? ProductVariant.fromJson(json['variant']) : null,
      quantity: json['quantity'],
    );
  }
}

class BranchProductInfo {
  final String branchId;
  final double? price; // Override
  final int stock;
  final bool isAvailable;

  BranchProductInfo({required this.branchId, this.price, required this.stock, this.isAvailable = true});

  factory BranchProductInfo.fromJson(Map<String, dynamic> json) {
    return BranchProductInfo(
      branchId: json['branchId'],
      price: (json['price'] as num?)?.toDouble(),
      stock: json['stock'] ?? 0,
      isAvailable: json['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'branchId': branchId,
    'price': price,
    'stock': stock,
    'isAvailable': isAvailable,
  };
}
