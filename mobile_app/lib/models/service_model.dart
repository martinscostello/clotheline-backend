import 'package:flutter/material.dart';

class ServiceModel {
  final String id;
  final String name;
  final String image;
  final String icon; // raw string e.g. "water_drop"
  final String color; // raw hex e.g. "0xFF..."
  final String description;
  final double discountPercentage;
  final String discountLabel;

  ServiceModel({
    required this.id,
    required this.name,
    required this.image,
    required this.icon,
    required this.color,
    required this.description,
    this.discountPercentage = 0,
    this.discountLabel = "",
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['_id'],
      name: json['name'],
      image: json['image'] ?? "assets/images/service_laundry.png", // Default fallback
      icon: json['icon'],
      color: json['color'],
      description: json['description'] ?? '',
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0,
      discountLabel: json['discountLabel'] ?? "",
    );
  }

  // Helper to get actual IconData
  IconData get iconData {
    switch (icon) {
      case 'dry_cleaning': return Icons.dry_cleaning;
      case 'do_not_step': return Icons.do_not_step;
      case 'water_drop': return Icons.water_drop;
      case 'house': return Icons.house;
      default: return Icons.cleaning_services;
    }
  }

  // Helper to get Color object
  Color get colorObj {
    try {
      // Handle # and 0x
      String hex = color.replaceAll('#', '');
      if (hex.startsWith('0x')) hex = hex.substring(2);
      if (hex.length == 6) hex = "FF$hex";
      return Color(int.parse("0x$hex"));
    } catch (e) {
      return Colors.blue;
    }
  }
}
