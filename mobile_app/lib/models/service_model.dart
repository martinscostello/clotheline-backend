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
    this.items = const [],
    this.serviceTypes = const [],
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['_id'],
      name: json['name'],
      image: json['image'] ?? "assets/images/service_laundry.png",
      icon: json['icon'],
      color: json['color'],
      description: json['description'] ?? '',
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0,
      discountLabel: json['discountLabel'] ?? "",
      isLocked: json['isLocked'] ?? false,
      lockedLabel: json['lockedLabel'] ?? "Coming Soon",
      items: (json['items'] as List?)?.map((e) => ServiceItem.fromJson(e)).toList() ?? [],
      serviceTypes: (json['serviceTypes'] as List?)?.map((e) => ServiceVariant.fromJson(e)).toList() ?? [],
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
  final String name;
  final double price;

  ServiceItem({required this.name, required this.price});

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      name: json['name'],
      price: (json['price'] as num).toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() => {'name': name, 'price': price};
}

class ServiceVariant {
  final String name;

  ServiceVariant({required this.name});

  factory ServiceVariant.fromJson(Map<String, dynamic> json) {
    return ServiceVariant(name: json['name']);
  }
  
  Map<String, dynamic> toJson() => {'name': name};
}
