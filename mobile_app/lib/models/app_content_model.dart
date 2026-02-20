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
  double freeShippingThreshold; 
  DeliveryAssurance? deliveryAssurance; // [NEW]
  List<PromotionalTemplate> promotionalTemplates; // [NEW]

  AppContentModel({
    required this.id,
    required this.heroCarousel,
    required this.homeGridServices,
    required this.productAds,
    required this.brandText,
    required this.productCategories,
    required this.contactAddress,
    required this.contactPhone,
    this.freeShippingThreshold = 25000.0,
    this.deliveryAssurance,
    this.promotionalTemplates = const [],
  });

  factory AppContentModel.fromJson(Map<String, dynamic> json) {
    final gridRaw = json['homeGridServices'];
    final gridList = (gridRaw is List) 
        ? gridRaw.whereType<Map>().map((e) => ServiceModel.fromJson(Map<String, dynamic>.from(e))).toList() 
        : <ServiceModel>[];

    return AppContentModel(
      id: json['_id'] ?? "",
      heroCarousel: (json['heroCarousel'] as List?)
          ?.map((e) => HeroCarouselItem.fromJson(e))
          .toList() ?? [],
      homeGridServices: gridList,
      productAds: (json['productAds'] as List?)
          ?.map((e) => ProductAd.fromJson(e))
          .toList() ?? [],
      brandText: json['brandText'] ?? "Premium Laundry Services",
      productCategories: (json['productCategories'] as List?)?.map((e) => e.toString()).toList() ?? [],
      contactAddress: json['contactAddress'] ?? "123 Laundry St, Lagos",
      contactPhone: json['contactPhone'] ?? "+234 800 000 0000",
      freeShippingThreshold: (json['freeShippingThreshold'] as num?)?.toDouble() ?? 25000.0,
      deliveryAssurance: json['deliveryAssurance'] != null ? DeliveryAssurance.fromJson(json['deliveryAssurance']) : null,
      promotionalTemplates: (json['promotionalTemplates'] as List?)
          ?.map((e) => PromotionalTemplate.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'heroCarousel': heroCarousel.map((e) => e.toJson()).toList(),
      'homeGridServices': homeGridServices.map((e) => e.id).toList(), 
      'productAds': productAds.map((e) => e.toJson()).toList(),
      'brandText': brandText,
      'productCategories': productCategories,
      'contactAddress': contactAddress,
      'contactPhone': contactPhone,
      'freeShippingThreshold': freeShippingThreshold,
      'deliveryAssurance': deliveryAssurance?.toJson(),
      'promotionalTemplates': promotionalTemplates.map((e) => e.toJson()).toList(),
    };
  }
}

class PromotionalTemplate {
  String title;
  String message;

  PromotionalTemplate({
    required this.title,
    required this.message,
  });

  factory PromotionalTemplate.fromJson(Map<String, dynamic> json) {
    return PromotionalTemplate(
      title: json['title'] ?? "",
      message: json['message'] ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'message': message,
  };
}

class DeliveryAssurance {
  String text;
  String icon;
  bool active;

  DeliveryAssurance({
    this.text = "Arrives in as little as [2 days]",
    this.icon = "van",
    this.active = true
  });

  factory DeliveryAssurance.fromJson(Map<String, dynamic> json) {
    return DeliveryAssurance(
      text: json['text'] ?? "Arrives in as little as [2 days]",
      icon: json['icon'] ?? "van",
      active: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'icon': icon,
    'active': active,
  };
}

class HeroCarouselItem {
  String imageUrl;
  String? title;
  String? titleColor;
  String? tagLine;
  String? tagLineColor;
  String? actionUrl;
  String mediaType;
  String? videoThumbnail;
  int duration; // [NEW] Display duration in ms

  HeroCarouselItem({
    required this.imageUrl, 
    this.title, 
    this.titleColor = "0xFFFFFFFF",
    this.tagLine,
    this.tagLineColor = "0xFFFFFFFF",
    this.actionUrl,
    this.mediaType = 'image',
    this.videoThumbnail,
    this.duration = 5000, 
  });

  factory HeroCarouselItem.fromJson(Map<String, dynamic> json) {
    return HeroCarouselItem(
      imageUrl: json['imageUrl'] ?? "", 
      title: json['title'],
      titleColor: json['titleColor'] ?? "0xFFFFFFFF",
      tagLine: json['tagLine'],
      tagLineColor: json['tagLineColor'] ?? "0xFFFFFFFF",
      actionUrl: json['actionUrl'],
      mediaType: json['mediaType'] ?? 'image',
      videoThumbnail: json['videoThumbnail'],
      duration: json['duration'] ?? 5000,
    );
  }

  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl,
    'title': title,
    'titleColor': titleColor,
    'tagLine': tagLine,
    'tagLineColor': tagLineColor,
    'actionUrl': actionUrl,
    'mediaType': mediaType,
    'videoThumbnail': videoThumbnail,
    'duration': duration,
  };
}

class ProductAd {
  String imageUrl;
  String? targetScreen;
  bool active;

  ProductAd({required this.imageUrl, this.targetScreen, this.active = true});

  factory ProductAd.fromJson(Map<String, dynamic> json) {
    return ProductAd(
      imageUrl: json['imageUrl'] ?? "",
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
