class ServiceType {
  final String id;
  final String name;
  final double priceMultiplier;

  ServiceType({required this.id, required this.name, this.priceMultiplier = 1.0});
}

class ClothingItem {
  final String id;
  final String name;
  final double basePrice;
  final String imageUrl;

  ClothingItem({required this.id, required this.name, required this.basePrice, this.imageUrl = ''});
}

class CartItem {
  final ClothingItem item;
  final ServiceType serviceType;
  final double discountPercentage;
  int quantity;

  CartItem({required this.item, required this.serviceType, this.quantity = 1, this.discountPercentage = 0.0});

  double get totalPrice {
     double base = item.basePrice * serviceType.priceMultiplier * quantity;
     if (discountPercentage > 0) {
       return base * (1 - (discountPercentage / 100));
     }
     return base;
  }
}
