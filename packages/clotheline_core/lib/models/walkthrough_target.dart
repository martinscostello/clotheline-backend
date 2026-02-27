import 'package:flutter/material.dart';

class WalkthroughTarget {
  final GlobalKey key;
  final String title;
  final String description;
  final IconData? icon;

  WalkthroughTarget({
    required this.key,
    required this.title,
    required this.description,
    this.icon,
  });
}
