import 'package:flutter/material.dart';

class ServiceModel {
  final String id;
  final String name;
  final String image;
  final String icon; // raw string e.g. "water_drop"
  final String color; // raw hex e.g. "0xFF..."
  final String description;
  final bool isLocked;
  final String lockedLabel;
  final List<ServiceItem> items;
  final List<ServiceVariant> serviceTypes;
  final List<BranchPrice> branchPricing; // [NEW]
  final double discountPercentage;
  final String discountLabel;
  final int order; // [NEW] Sort order

  ServiceModel({
    required this.id,
    required this.name,
    required this.image,
    required this.icon,
    required this.color,
    required this.description,
    this.discountPercentage = 0,
    this.discountLabel = "",
    this.isLocked = false,
    this.lockedLabel = "Coming Soon",
    this.order = 0, // [NEW]
    this.items = const [],
    this.serviceTypes = const [],
    this.branchPricing = const [], // [NEW]
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return ServiceModel(
      id: json['_id'] ?? "unknown_id",
      name: json['name'] ?? "Unnamed Service",
      image: json['image'] ?? "assets/images/service_laundry.png",
      icon: json['icon'] ?? "cleaning_services",
      color: json['color'] ?? "0xFF2196F3",
      description: json['description'] ?? '',
      discountPercentage: parseDouble(json['discountPercentage']),
      discountLabel: json['discountLabel'] ?? "",
      isLocked: json['isLocked'] ?? false,
      lockedLabel: json['lockedLabel'] ?? "Coming Soon",
      order: json['order'] ?? 0,
      items: (json['items'] as List?)?.map((e) => ServiceItem.fromJson(e)).toList() ?? [],
      serviceTypes: (json['serviceTypes'] as List?)?.map((e) => ServiceVariant.fromJson(e)).toList() ?? [],
      branchPricing: (json['branchPricing'] as List?)?.map((e) => BranchPrice.fromJson(e)).toList() ?? [],
    );
  }

  // Helper to get actual IconData
  IconData get iconData {
    switch (icon) {
      case 'dry_cleaning': 
      case 'local_laundry_service':
        return Icons.local_laundry_service;
      case 'do_not_step': return Icons.do_not_step;
      case 'water_drop': return Icons.water_drop;
      case 'house': return Icons.house;
      default: return Icons.cleaning_services;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'image': image,
      'icon': icon,
      'color': color,
      'description': description,
      'discountPercentage': discountPercentage,
      'discountLabel': discountLabel,
      'isLocked': isLocked,
      'lockedLabel': lockedLabel,
      'order': order,
      'items': items.map((e) => e.toJson()).toList(),
      'serviceTypes': serviceTypes.map((e) => e.toJson()).toList(),
      'branchPricing': branchPricing.map((e) => e.toJson()).toList(),
    };
  }

  // Helper to get Color object
  Color get colorObj {
    try {
      String hex = color.replaceAll('#', '');
      if (hex.startsWith('0x')) hex = hex.substring(2);
      if (hex.length == 6) hex = "FF$hex";
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }
}

class ServiceItem {
  final String? id; // Nullable for new items
  final String name;
  final double price; // Legacy Base Price
  final List<ServiceOption> services; // [NEW] Nested services

  ServiceItem({
    this.id, 
    required this.name, 
    required this.price,
    this.services = const []
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: json['_id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      services: (json['services'] as List?)?.map((s) => ServiceOption.fromJson(s)).toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'name': name, 
    'price': price,
    'services': services.map((s) => s.toJson()).toList(),
  };
}

class ServiceOption {
  final String name;
  final double price;

  ServiceOption({required this.name, required this.price});

  factory ServiceOption.fromJson(Map<String, dynamic> json) {
    return ServiceOption(
      name: json['name'] ?? "",
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
  };
}

class ServiceVariant {
  final String name;
  final double priceMultiplier;

  ServiceVariant({required this.name, this.priceMultiplier = 1.0});

  factory ServiceVariant.fromJson(Map<String, dynamic> json) {
    return ServiceVariant(
      name: json['name'],
      priceMultiplier: (json['priceMultiplier'] as num?)?.toDouble() ?? 1.0,
    );
  }
  
  Map<String, dynamic> toJson() => {'name': name, 'priceMultiplier': priceMultiplier};
}

class BranchPrice {
  final String branchId;
  final bool isAvailable;
  final double? priceOverride; // If null, use default

  BranchPrice({required this.branchId, this.isAvailable = true, this.priceOverride});

  factory BranchPrice.fromJson(Map<String, dynamic> json) {
    return BranchPrice(
      branchId: json['branchId'] ?? "",
      isAvailable: json['isAvailable'] ?? true,
      priceOverride: (json['price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'branchId': branchId,
    'isAvailable': isAvailable,
    'price': priceOverride,
  };
}
