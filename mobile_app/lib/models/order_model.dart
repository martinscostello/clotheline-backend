enum OrderStatus { New, InProgress, Ready, Completed, Cancelled, Refunded }
enum PaymentStatus { Pending, Paid }

class OrderModel {
  final String id;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  
  final String pickupOption; // Pickup, Dropoff
  final String deliveryOption; // Deliver, Pickup
  
  final String? pickupAddress;
  final String? pickupPhone;
  final String? deliveryAddress;
  final String? deliveryPhone;
  
  final DateTime date;
  
  // Tax
  final double subtotal;
  final double taxAmount;
  final double taxRate;

  // Multi-Branch
  final String? branchId;

  // Guest Info
  final String? guestName;
  final String? guestPhone;
  final String? guestEmail; // [Added]
  final String? userName;
  final String? userEmail;

  OrderModel({
    required this.id,
    required this.items,
    required this.totalAmount,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.taxRate = 0,
    required this.status,
    required this.paymentStatus,
    required this.pickupOption,
    required this.deliveryOption,
    this.pickupAddress,
    this.pickupPhone,
    this.deliveryAddress,
    this.deliveryPhone,
    required this.date,
    this.branchId, 
    this.guestName,
    this.guestPhone,
    this.guestEmail, // [Added]
    this.userName,
    this.userEmail
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['_id'],
      items: (json['items'] as List).map((i) => OrderItem.fromJson(i)).toList(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? (json['totalAmount'] as num).toDouble(),
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.0,
      status: OrderStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => OrderStatus.New),
      paymentStatus: PaymentStatus.values.firstWhere((e) => e.name == json['paymentStatus'], orElse: () => PaymentStatus.Pending),
      pickupOption: json['pickupOption'],
      deliveryOption: json['deliveryOption'],
      pickupAddress: json['pickupAddress'],
      pickupPhone: json['pickupPhone'],
      deliveryAddress: json['deliveryAddress'],
      deliveryPhone: json['deliveryPhone'],
      date: DateTime.parse(json['date']),
      branchId: json['branchId'],
      guestName: json['guestInfo']?['name'],
      guestPhone: json['guestInfo']?['phone'],
      guestEmail: json['guestInfo']?['email'], // [Added]
      userName: json['user'] is Map ? json['user']['name'] : null,
      userEmail: json['user'] is Map ? json['user']['email'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((i) => i.toJson()).toList(),
      'totalAmount': totalAmount,
      'status': status.name,
      'paymentStatus': paymentStatus.name,
      'pickupOption': pickupOption,
      'deliveryOption': deliveryOption,
      'pickupAddress': pickupAddress,
      'pickupPhone': pickupPhone,
      'deliveryAddress': deliveryAddress,
      'deliveryPhone': deliveryPhone,
      'guestInfo': {
        'name': guestName,
        'phone': guestPhone,
        'email': guestEmail // [Added]
      }
    };
  }
}

class OrderItem {
  final String itemType; // Service, Product
  final String itemId; 
  final String name;
  final String? variant;
  final String? serviceType;
  final int quantity;
  final double price;

  OrderItem({
    required this.itemType,
    required this.itemId,
    required this.name,
    this.variant,
    this.serviceType,
    required this.quantity,
    required this.price
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemType: json['itemType'],
      itemId: json['itemId'],
      name: json['name'],
      variant: json['variant'],
      serviceType: json['serviceType'],
      quantity: json['quantity'],
      price: (json['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'itemType': itemType,
    'itemId': itemId,
    'name': name,
    'variant': variant,
    'serviceType': serviceType,
    'quantity': quantity,
    'price': price,
  };
}
