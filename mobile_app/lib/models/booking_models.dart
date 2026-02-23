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
  final ServiceType serviceType;
  final double discountPercentage;
  final String fulfillmentMode;
  final bool quoteRequired; // [NEW]
  final double inspectionFee; // [NEW]
  int quantity;

  CartItem({
    required this.item, 
    required this.serviceType, 
    this.quantity = 1, 
    this.discountPercentage = 0.0,
    this.fulfillmentMode = 'logistics',
    this.quoteRequired = false,
    this.inspectionFee = 0.0,
  });

  double get totalPrice {
     if (quoteRequired) return inspectionFee;
     double base = item.basePrice * serviceType.priceMultiplier * quantity;
     if (discountPercentage > 0) {
       return base * (1 - (discountPercentage / 100));
     }
     return base;
  }

  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'serviceType': serviceType.toJson(),
    'quantity': quantity,
    'discountPercentage': discountPercentage,
    'fulfillmentMode': fulfillmentMode,
    'quoteRequired': quoteRequired,
    'inspectionFee': inspectionFee,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      item: ClothingItem.fromJson(json['item']),
      serviceType: ServiceType.fromJson(json['serviceType']),
      quantity: json['quantity'] ?? 1,
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      fulfillmentMode: json['fulfillmentMode'] ?? 'logistics',
      quoteRequired: json['quoteRequired'] ?? false,
      inspectionFee: (json['inspectionFee'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
