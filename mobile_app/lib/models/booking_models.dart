import 'service_model.dart';
import 'package:latlong2/latlong.dart';

class ServiceType {
  final String id;
  final String name;
  final double priceMultiplier;

  ServiceType({required this.id, required this.name, this.priceMultiplier = 1.0});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'priceMultiplier': priceMultiplier,
  };

  factory ServiceType.fromJson(Map<String, dynamic> json) {
    return ServiceType(
      id: json['id'],
      name: json['name'],
      priceMultiplier: (json['priceMultiplier'] as num).toDouble(),
    );
  }
}

class ClothingItem {
  final String id;
  final String name;
  final double basePrice;
  final String imageUrl;

  ClothingItem({required this.id, required this.name, required this.basePrice, this.imageUrl = ''});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'basePrice': basePrice,
    'imageUrl': imageUrl,
  };

  factory ClothingItem.fromJson(Map<String, dynamic> json) {
    return ClothingItem(
      id: json['id'],
      name: json['name'],
      basePrice: (json['basePrice'] as num).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}

class CartItem {
  final ClothingItem item;
  final ServiceType? serviceType;
  final double discountPercentage;
  final String fulfillmentMode;
  final bool quoteRequired; 
  double inspectionFee; // [CHANGED] Allow updating during checkout
  final List<InspectionZone> inspectionFeeZones; // [NEW]
  final LatLng? deploymentLocation; // [NEW]
  final String? serviceId; // [NEW] Originating Service ID for isolation
  final String? serviceName; // [NEW] Originating Service Name
  int quantity;

  CartItem({
    required this.item, 
    this.serviceType, 
    this.quantity = 1, 
    this.discountPercentage = 0.0,
    this.fulfillmentMode = 'logistics',
    this.quoteRequired = false,
    this.inspectionFee = 0.0,
    this.inspectionFeeZones = const [],
    this.deploymentLocation,
    this.serviceId,
    this.serviceName,
  });

  // [NEW] Gross Total for the line item (Quantity * Price * Multiplier)
  double get baseTotal => item.basePrice * (serviceType?.priceMultiplier ?? 1.0) * quantity;

  // [NEW] Absolute Discount Value for the line item
  double get discountValue => baseTotal * (discountPercentage / 100);

  double get checkoutPrice {
     // [HARD ISOLATION] Deployment mode uses Inspection Fees for checkout
     if (fulfillmentMode == 'deployment' && quoteRequired) return inspectionFee;
     
     // Logistics (Laundry) and standard services use the Full Gross Price
     // The discount is handled at the summary level to match user expectations.
     return baseTotal;
  }

  double get totalPrice => checkoutPrice; // Backward compatibility

  // Used for "Service Estimate" in Deployment mode or summary math
  double get fullEstimate => baseTotal - discountValue;

  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'serviceType': serviceType?.toJson(),
    'quantity': quantity,
    'discountPercentage': discountPercentage,
    'fulfillmentMode': fulfillmentMode,
    'quoteRequired': quoteRequired,
    'inspectionFee': inspectionFee,
    'inspectionFeeZones': inspectionFeeZones.map((z) => z.toJson()).toList(),
    'deploymentLocation': deploymentLocation != null ? {'lat': deploymentLocation!.latitude, 'lng': deploymentLocation!.longitude} : null,
    'serviceId': serviceId,
    'serviceName': serviceName,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      item: ClothingItem.fromJson(json['item']),
      serviceType: json['serviceType'] != null ? ServiceType.fromJson(json['serviceType']) : null,
      quantity: json['quantity'] ?? 1,
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      fulfillmentMode: json['fulfillmentMode'] ?? 'logistics',
      quoteRequired: json['quoteRequired'] ?? false,
      inspectionFee: (json['inspectionFee'] as num?)?.toDouble() ?? 0.0,
      inspectionFeeZones: (json['inspectionFeeZones'] as List?)?.map((z) => InspectionZone.fromJson(z)).toList() ?? [],
      deploymentLocation: json['deploymentLocation'] != null ? LatLng(json['deploymentLocation']['lat'], json['deploymentLocation']['lng']) : null,
      serviceId: json['serviceId'],
      serviceName: json['serviceName'],
    );
  }
}
