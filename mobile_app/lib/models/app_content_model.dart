import 'package:laundry_app/models/service_model.dart';

class AppContentModel {
  String id;
  List<HeroCarouselItem> heroCarousel;
  List<ServiceModel> homeGridServices;
  List<ProductAd> productAds;
  String brandText;
  List<String> productCategories;
  String contactAddress;
  String contactPhone;

  AppContentModel({
    required this.id,
    required this.heroCarousel,
    required this.homeGridServices,
    required this.productAds,
    required this.brandText,
    required this.productCategories,
    required this.contactAddress,
    required this.contactPhone,
  });

  factory AppContentModel.fromJson(Map<String, dynamic> json) {
    return AppContentModel(
      id: json['_id'],
      heroCarousel: (json['heroCarousel'] as List?)
          ?.map((e) => HeroCarouselItem.fromJson(e))
          .toList() ?? [],
      homeGridServices: (json['homeGridServices'] as List?)
          ?.map((e) => ServiceModel.fromJson(e))
          .toList() ?? [],
      productAds: (json['productAds'] as List?)
          ?.map((e) => ProductAd.fromJson(e))
          .toList() ?? [],
      brandText: json['brandText'] ?? "Premium Laundry Services",
      productCategories: (json['productCategories'] as List?)?.map((e) => e.toString()).toList() ?? [],
      contactAddress: json['contactAddress'] ?? "123 Laundry St, Lagos",
      contactPhone: json['contactPhone'] ?? "+234 800 000 0000",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'heroCarousel': heroCarousel.map((e) => e.toJson()).toList(),
      'homeGridServices': homeGridServices.map((e) => e.id).toList(), // Send IDs back to backend
      'productAds': productAds.map((e) => e.toJson()).toList(),
      'brandText': brandText,
      'productCategories': productCategories,
      'contactAddress': contactAddress,
      'contactPhone': contactPhone,
    };
  }
}

class HeroCarouselItem {
  String imageUrl;
  String? title;
  String? actionUrl;

  HeroCarouselItem({required this.imageUrl, this.title, this.actionUrl});

  factory HeroCarouselItem.fromJson(Map<String, dynamic> json) {
    return HeroCarouselItem(
      imageUrl: json['imageUrl'],
      title: json['title'],
      actionUrl: json['actionUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl,
    'title': title,
    'actionUrl': actionUrl,
  };
}

class ProductAd {
  String imageUrl;
  String? targetScreen;
  bool active;

  ProductAd({required this.imageUrl, this.targetScreen, this.active = true});

  factory ProductAd.fromJson(Map<String, dynamic> json) {
    return ProductAd(
      imageUrl: json['imageUrl'],
      targetScreen: json['targetScreen'],
      active: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl,
    'targetScreen': targetScreen,
    'active': active,
  };
}
