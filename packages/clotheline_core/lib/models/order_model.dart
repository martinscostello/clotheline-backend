enum OrderStatus { New, InProgress, Ready, Completed, Cancelled, Refunded, PendingUserConfirmation, Inspecting }
enum PaymentStatus { Pending, Paid, Refunded }
enum OrderExceptionStatus { None, Stain, Damage, Delay, MissingItem, Other }
enum QuoteStatus { None, Pending, Approved, Rejected }

class OrderModel {
  final String id;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final String? paymentMethod; // [NEW] cash, pos, transfer, pay_on_delivery, paystack
  final OrderExceptionStatus exceptionStatus; // [NEW]
  final String? exceptionNote; // [NEW]
  final String fulfillmentMode; // [NEW] logistics | deployment | bulky
  final QuoteStatus quoteStatus; // [NEW]
  final double inspectionFee; // [NEW]
  
  final String pickupOption; // Pickup, Dropoff
  final String deliveryOption; // Deliver, Pickup
  
  final String? pickupAddress;
  final String? pickupPhone;
  final String? deliveryAddress;
  final String? deliveryPhone;
  
  // [New] Rich Location Support
  final Map<String, dynamic>? deliveryLocation;
  final Map<String, dynamic>? pickupLocation;
  final double? deliveryFeeOverride;
  final bool isFeeOverridden;
  final double deliveryFee;
  final double pickupFee;
  
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
  final FeeAdjustment? feeAdjustment; // [New]
  final String? laundryNotes; // [NEW]
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
    this.paymentMethod,
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
    this.discountBreakdown = const {},
    this.deliveryLocation,
    this.pickupLocation,
    this.deliveryFeeOverride,
    this.isFeeOverridden = false,
    this.deliveryFee = 0.0,
    this.pickupFee = 0,
    this.feeAdjustment,
    this.laundryNotes,
    this.fulfillmentMode = 'logistics',
    this.quoteStatus = QuoteStatus.None,
    this.inspectionFee = 0.0,
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
      paymentMethod: json['paymentMethod'],
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
      deliveryLocation: json['deliveryLocation'],
      pickupLocation: json['pickupLocation'],
      deliveryFeeOverride: (json['deliveryFeeOverride'] as num?)?.toDouble(),
      isFeeOverridden: json['isFeeOverridden'] ?? false,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      pickupFee: (json['pickupFee'] as num?)?.toDouble() ?? 0.0,
      feeAdjustment: json['feeAdjustment'] != null ? FeeAdjustment.fromJson(json['feeAdjustment']) : null,
      laundryNotes: json['laundryNotes'],
      fulfillmentMode: json['fulfillmentMode'] ?? 'logistics',
      quoteStatus: QuoteStatus.values.firstWhere((e) => e.name == (json['quoteStatus'] ?? 'None'), orElse: () => QuoteStatus.None),
      inspectionFee: (json['inspectionFee'] as num?)?.toDouble() ?? 0.0,
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
      'laundryNotes': laundryNotes,
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

class FeeAdjustment {
  final double amount;
  final String status; // Pending, Paid, PayOnDelivery
  final String? paymentReference;
  final bool notified;

  FeeAdjustment({
    required this.amount,
    required this.status,
    this.paymentReference,
    this.notified = false,
  });

  factory FeeAdjustment.fromJson(Map<String, dynamic> json) {
    return FeeAdjustment(
      amount: (json['amount'] as num).toDouble(),
      status: json['status'],
      paymentReference: json['paymentReference'],
      notified: json['notified'] ?? false,
    );
  }
}
