class Branch {
  final String id;
  final String name;
  final String address;
  final String phone;
  final BranchLocation location;
  final List<DeliveryZone> deliveryZones;
  final bool isDefault;

  Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.location,
    required this.deliveryZones,
    this.isDefault = false,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['_id'],
      name: json['name'],
      address: json['address'],
      phone: json['phone'],
      location: BranchLocation.fromJson(json['location']),
      deliveryZones: (json['deliveryZones'] as List).map((z) => DeliveryZone.fromJson(z)).toList(),
      isDefault: json['isDefault'] ?? false,
    );
  }
}

class BranchLocation {
  final double lat;
  final double lng;

  BranchLocation({required this.lat, required this.lng});

  // Compatibility getters
  double get latitude => lat;
  double get longitude => lng;

  factory BranchLocation.fromJson(Map<String, dynamic> json) {
    return BranchLocation(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class DeliveryZone {
  final String name;
  final String description;
  final double radiusKm;
  final double baseFee;

  DeliveryZone({
    required this.name,
    required this.description,
    required this.radiusKm,
    required this.baseFee,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      name: json['name'],
      description: json['description'],
      radiusKm: (json['radiusKm'] as num).toDouble(),
      baseFee: (json['baseFee'] as num).toDouble(),
    );
  }
}
