class Branch {
  final String id;
  final String name;
  final String address;
  final String phone;
  final BranchLocation location;
  final List<DeliveryZone> deliveryZones;
  final bool isDefault;
  final bool isPosTerminalEnabled;
  final PosConfig? posConfig; // [NEW]
  final String categorySortOrder;

  Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.location,
    required this.deliveryZones,
    this.isDefault = false,
    this.isPosTerminalEnabled = false,
    this.posConfig,
    this.categorySortOrder = 'alphabetical',
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
      isPosTerminalEnabled: json['isPosTerminalEnabled'] ?? false,
      posConfig: json['posConfig'] != null ? PosConfig.fromJson(json['posConfig']) : null,
      categorySortOrder: json['categorySortOrder'] ?? 'alphabetical',
    );
  }
}

class PosConfig {
  final String? terminalDisplayName;
  final PosCharges charges;
  final PosProfitTarget profitTarget;
  final PosSecurity security;
  final double defaultOpeningCash;

  PosConfig({
    this.terminalDisplayName,
    required this.charges,
    required this.profitTarget,
    required this.security,
    this.defaultOpeningCash = 0.0,
    this.transactionTypes = const [],
  });

  factory PosConfig.fromJson(Map<String, dynamic> json) {
    return PosConfig(
      terminalDisplayName: json['terminalDisplayName'],
      charges: PosCharges.fromJson(json['charges'] ?? {}),
      profitTarget: PosProfitTarget.fromJson(json['profitTarget'] ?? {}),
      security: PosSecurity.fromJson(json['security'] ?? {}),
      defaultOpeningCash: (json['defaultOpeningCash'] as num?)?.toDouble() ?? 0.0,
      transactionTypes: (json['transactionTypes'] as List?)?.map((t) => PosTransactionType.fromJson(t)).toList() ?? [],
    );
  }

  final List<PosTransactionType> transactionTypes;
}

class PosTransactionType {
  final String name;
  final bool hasProviderFee;
  final bool hasCustomerCharge;

  PosTransactionType({
    required this.name,
    this.hasProviderFee = true,
    this.hasCustomerCharge = true,
  });

  factory PosTransactionType.fromJson(Map<String, dynamic> json) {
    return PosTransactionType(
      name: json['name'] ?? "",
      hasProviderFee: json['hasProviderFee'] ?? true,
      hasCustomerCharge: json['hasCustomerCharge'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'hasProviderFee': hasProviderFee,
    'hasCustomerCharge': hasCustomerCharge,
  };
}

class PosCharges {
  final double withdrawal;
  final double transfer;
  final double deposit;
  final String opayTier; // [NEW]
  final bool smartTiersEnabled;
  final List<SmartTier> smartTiers;

  PosCharges({
    this.withdrawal = 0.0,
    this.transfer = 0.0,
    this.deposit = 0.0,
    this.opayTier = 'Regular',
    this.smartTiersEnabled = false,
    this.smartTiers = const [],
  });

  factory PosCharges.fromJson(Map<String, dynamic> json) {
    return PosCharges(
      withdrawal: (json['withdrawal'] as num?)?.toDouble() ?? 0.0,
      transfer: (json['transfer'] as num?)?.toDouble() ?? 0.0,
      deposit: (json['deposit'] as num?)?.toDouble() ?? 0.0,
      opayTier: json['opayTier'] ?? 'Regular',
      smartTiersEnabled: json['smartTiersEnabled'] ?? false,
      smartTiers: (json['smartTiers'] as List?)?.map((t) => SmartTier.fromJson(t)).toList() ?? [],
    );
  }
}

class SmartTier {
  final double min;
  final double max;
  final double charge;

  SmartTier({required this.min, required this.max, required this.charge});

  factory SmartTier.fromJson(Map<String, dynamic> json) {
    return SmartTier(
      min: (json['min'] as num?)?.toDouble() ?? 0.0,
      max: (json['max'] as num?)?.toDouble() ?? 0.0,
      charge: (json['charge'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PosProfitTarget {
  final bool enabled;
  final double amount;

  PosProfitTarget({this.enabled = false, this.amount = 0.0});

  factory PosProfitTarget.fromJson(Map<String, dynamic> json) {
    return PosProfitTarget(
      enabled: json['enabled'] ?? false,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PosSecurity {
  final bool lockAfter24h;
  final bool masterAdminOnly;
  final bool requireReconciliation;
  final bool requireDeleteConfirmation;

  PosSecurity({
    this.lockAfter24h = false,
    this.masterAdminOnly = false,
    this.requireReconciliation = false,
    this.requireDeleteConfirmation = true,
  });

  factory PosSecurity.fromJson(Map<String, dynamic> json) {
    return PosSecurity(
      lockAfter24h: json['lockAfter24h'] ?? false,
      masterAdminOnly: json['masterAdminOnly'] ?? false,
      requireReconciliation: json['requireReconciliation'] ?? false,
      requireDeleteConfirmation: json['requireDeleteConfirmation'] ?? true,
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
  final String color; // Added for visualization

  DeliveryZone({
    required this.name,
    required this.description,
    required this.radiusKm,
    required this.baseFee,
    this.color = '#4286f4', // Default blue
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      name: json['name'],
      description: json['description'],
      radiusKm: (json['radiusKm'] as num).toDouble(),
      baseFee: (json['baseFee'] as num).toDouble(),
      color: json['color'] ?? '#4286f4',
    );
  }
}
