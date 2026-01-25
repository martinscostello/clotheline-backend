enum OrderStatus { New, InProgress, Ready, Completed, Cancelled, Refunded }
enum PaymentStatus { Pending, Paid, Refunded }
enum OrderExceptionStatus { None, Stain, Damage, Delay, MissingItem, Other }

class OrderModel {
  final String id;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final OrderExceptionStatus exceptionStatus; // [NEW]
  final String? exceptionNote; // [NEW]
  
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
  final String? guestEmail; 
  final String? userName;
  final String? userEmail;
  final String? userId; 
  
  // Discount Metadata
  final double discountAmount; // [New]
  final double storeDiscount;
  final Map<String, double> discountBreakdown;
  // Note: discountBreakdown keys: "Discount (Regular)", "Discount (Footwear)" etc.

  OrderModel({
    required this.id,
    required this.items,
    required this.totalAmount,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.taxRate = 0,
    required this.status,
    required this.paymentStatus,
    this.exceptionStatus = OrderExceptionStatus.None, 
    this.exceptionNote, 
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
    this.guestEmail,
    this.userName,
    this.userEmail,
    this.userId,
    this.discountAmount = 0.0, // [New]
    this.storeDiscount = 0.0,
    this.discountBreakdown = const {}
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
      exceptionStatus: OrderExceptionStatus.values.firstWhere((e) => e.name == (json['exceptionStatus'] ?? 'None'), orElse: () => OrderExceptionStatus.None),
      exceptionNote: json['exceptionNote'],
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
      guestEmail: json['guestInfo']?['email'], 
      userName: json['user'] is Map ? json['user']['name'] : null,
      userEmail: json['user'] is Map ? json['user']['email'] : null,
      userId: json['user'] is Map ? json['user']['_id'] : (json['user'] is String ? json['user'] : null),
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0, // [New]
      storeDiscount: (json['storeDiscount'] as num?)?.toDouble() ?? 0.0, // [New]
      discountBreakdown: json['discountBreakdown'] != null 
          ? Map<String, double>.from(json['discountBreakdown'].map((k, v) => MapEntry(k, (v as num).toDouble()))) 
          : {}, // [New]
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
      },
      'userId': userId // [NEW]
    };
  }
}

class OrderItem {
  final String? id; // [NEW] Subdocument ID
  final String itemType; // Service, Product
  final String itemId; 
  final String name;
  final String? variant;
  final String? serviceType;
  final int quantity;
  final double price;

  OrderItem({
    this.id,
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
      id: json['_id'],
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
    '_id': id,
    'itemType': itemType,
    'itemId': itemId,
    'name': name,
    'variant': variant,
    'serviceType': serviceType,
    'quantity': quantity,
    'price': price,
  };
}
