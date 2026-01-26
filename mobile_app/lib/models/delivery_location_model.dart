class DeliveryLocationSelection {
  final double lat;
  final double lng;
  final String addressLabel;
  final String source; // 'pin', 'google', 'manual', 'admin'
  final String? area;
  final String? landmark;

  DeliveryLocationSelection({
    required this.lat,
    required this.lng,
    required this.addressLabel,
    required this.source,
    this.area,
    this.landmark,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'addressLabel': addressLabel,
    'source': source,
    'area': area,
    'landmark': landmark,
  };

  factory DeliveryLocationSelection.fromJson(Map<String, dynamic> json) {
    return DeliveryLocationSelection(
      lat: json['lat'],
      lng: json['lng'],
      addressLabel: json['addressLabel'],
      source: json['source'],
      area: json['area'],
      landmark: json['landmark'],
    );
  }
}
