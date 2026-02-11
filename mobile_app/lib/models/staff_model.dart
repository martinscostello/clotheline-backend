class Staff {
  final String id;
  final String name;
  final String? email;
  final String phone;
  final String position;
  final String branchId;
  final List<StaffWarning> warnings;
  final String? salaryNotes;
  final String status;
  final bool isSuspended;
  final bool isArchived;
  final String? archiveReason;
  final DateTime createdAt;

  Staff({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    required this.position,
    required this.branchId,
    required this.warnings,
    this.salaryNotes,
    this.status = 'Active',
    this.isSuspended = false,
    this.isArchived = false,
    this.archiveReason,
    required this.createdAt,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      position: json['position'],
      branchId: json['branchId'],
      warnings: (json['warnings'] as List? ?? [])
          .map((w) => StaffWarning.fromJson(w))
          .toList(),
      salaryNotes: json['salaryNotes'],
      status: json['status'] ?? 'Active',
      isSuspended: json['isSuspended'] ?? false,
      isArchived: json['isArchived'] ?? false,
      archiveReason: json['archiveReason'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class StaffWarning {
  final String id;
  final String reason;
  final String severity;
  final String? notes;
  final String? issuedBy; // Name or ID of admin
  final bool sentViaWhatsApp;
  final DateTime timestamp;

  StaffWarning({
    required this.id,
    required this.reason,
    required this.severity,
    this.notes,
    this.issuedBy,
    required this.sentViaWhatsApp,
    required this.timestamp,
  });

  factory StaffWarning.fromJson(Map<String, dynamic> json) {
    String? issuer;
    if (json['issuedBy'] is Map) {
      issuer = json['issuedBy']['name'];
    } else {
      issuer = json['issuedBy'];
    }

    return StaffWarning(
      id: json['_id'] ?? json['id'] ?? '',
      reason: json['reason'],
      severity: json['severity'],
      notes: json['notes'],
      issuedBy: issuer,
      sentViaWhatsApp: json['sentViaWhatsApp'] ?? false,
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}
