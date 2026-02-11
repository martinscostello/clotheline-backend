class Staff {
  final String id;
  final String staffId;
  final String name;
  final String? email;
  final String phone;
  final String? address;
  final String position;
  final String? passportPhoto;
  final String? idCardImage;
  final String? signature;
  final DateTime employmentDate;
  final String branchId;
  final List<StaffWarning> warnings;
  final BankDetails? bankDetails;
  final GuarantorDetails? guarantor;
  final SalaryDetails? salary;
  final PerformanceDetails? performance;
  final ProbationDetails? probation;
  final String status;
  final bool isSuspended;
  final bool isArchived;
  final String? archiveReason;
  final List<StaffPayment> paymentHistory;
  final DateTime createdAt;

  Staff({
    required this.id,
    required this.staffId,
    required this.name,
    this.email,
    required this.phone,
    this.address,
    required this.position,
    this.passportPhoto,
    this.idCardImage,
    this.signature,
    required this.employmentDate,
    required this.branchId,
    required this.warnings,
    this.bankDetails,
    this.guarantor,
    this.salary,
    this.performance,
    this.probation,
    this.status = 'Active',
    this.isSuspended = false,
    this.isArchived = false,
    this.archiveReason,
    this.paymentHistory = const [],
    required this.createdAt,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['_id'] ?? json['id'] ?? '',
      staffId: json['staffId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'] ?? '',
      address: json['address'],
      position: json['position'] ?? '',
      passportPhoto: json['passportPhoto'],
      idCardImage: json['idCardImage'],
      signature: json['signature'],
      employmentDate: DateTime.parse(json['employmentDate'] ?? DateTime.now().toIso8601String()),
      branchId: json['branchId'] ?? '',
      warnings: (json['warnings'] as List? ?? [])
          .map((w) => StaffWarning.fromJson(w))
          .toList(),
      bankDetails: json['bankDetails'] != null ? BankDetails.fromJson(json['bankDetails']) : null,
      guarantor: json['guarantor'] != null ? GuarantorDetails.fromJson(json['guarantor']) : null,
      salary: json['salary'] != null ? SalaryDetails.fromJson(json['salary']) : null,
      performance: json['performance'] != null ? PerformanceDetails.fromJson(json['performance']) : null,
      probation: json['probation'] != null ? ProbationDetails.fromJson(json['probation']) : null,
      status: json['status'] ?? 'Active',
      isSuspended: json['isSuspended'] ?? false,
      isArchived: json['isArchived'] ?? false,
      archiveReason: json['archiveReason'],
      paymentHistory: (json['paymentHistory'] as List? ?? [])
          .map((p) => StaffPayment.fromJson(p))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'position': position,
      'passportPhoto': passportPhoto,
      'idCardImage': idCardImage,
      'signature': signature,
      'employmentDate': employmentDate.toIso8601String(),
      'branchId': branchId,
      'bankDetails': bankDetails?.toJson(),
      'guarantor': guarantor?.toJson(),
      'salary': salary?.toJson(),
      'performance': performance?.toJson(),
      'probation': probation?.toJson(),
      'paymentHistory': paymentHistory.map((p) => p.toJson()).toList(),
      'status': status,
    };
  }
}

class StaffPayment {
  final String id;
  final double amount;
  final DateTime date;
  final String? reference;
  final String status;

  StaffPayment({
    required this.id,
    required this.amount,
    required this.date,
    this.reference,
    this.status = 'Paid',
  });

  factory StaffPayment.fromJson(Map<String, dynamic> json) => StaffPayment(
    id: json['_id'] ?? json['id'] ?? '',
    amount: (json['amount'] ?? 0).toDouble(),
    date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
    reference: json['reference'],
    status: json['status'] ?? 'Paid',
  );

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'date': date.toIso8601String(),
    'reference': reference,
    'status': status,
  };
}

class BankDetails {
  final String? bankName;
  final String? accountNumber;
  final String? accountName;

  BankDetails({this.bankName, this.accountNumber, this.accountName});

  factory BankDetails.fromJson(Map<String, dynamic> json) => BankDetails(
    bankName: json['bankName'],
    accountNumber: json['accountNumber'],
    accountName: json['accountName'],
  );

  Map<String, dynamic> toJson() => {
    'bankName': bankName,
    'accountNumber': accountNumber,
    'accountName': accountName,
  };
}

class GuarantorDetails {
  final String? name;
  final String? phone;
  final String? address;
  final String? relationship;
  final String? occupation;
  final String? idImage;

  GuarantorDetails({this.name, this.phone, this.address, this.relationship, this.occupation, this.idImage});

  factory GuarantorDetails.fromJson(Map<String, dynamic> json) => GuarantorDetails(
    name: json['name'],
    phone: json['phone'],
    address: json['address'],
    relationship: json['relationship'],
    occupation: json['occupation'],
    idImage: json['idImage'],
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
    'relationship': relationship,
    'occupation': occupation,
    'idImage': idImage,
  };
}

class SalaryDetails {
  final String grade;
  final double baseSalary;
  final String cycle;
  final DateTime? lastPaidDate;
  final DateTime? nextPaymentDueDate;
  final String status;

  SalaryDetails({
    this.grade = 'Level 1',
    this.baseSalary = 0,
    this.cycle = 'Monthly',
    this.lastPaidDate,
    this.nextPaymentDueDate,
    this.status = 'Pending',
  });

  factory SalaryDetails.fromJson(Map<String, dynamic> json) => SalaryDetails(
    grade: json['grade'] ?? 'Level 1',
    baseSalary: (json['baseSalary'] ?? 0).toDouble(),
    cycle: json['cycle'] ?? 'Monthly',
    lastPaidDate: json['lastPaidDate'] != null ? DateTime.parse(json['lastPaidDate']) : null,
    nextPaymentDueDate: json['nextPaymentDueDate'] != null ? DateTime.parse(json['nextPaymentDueDate']) : null,
    status: json['status'] ?? 'Pending',
  );

  Map<String, dynamic> toJson() => {
    'grade': grade,
    'baseSalary': baseSalary,
    'cycle': cycle,
    'lastPaidDate': lastPaidDate?.toIso8601String(),
    'nextPaymentDueDate': nextPaymentDueDate?.toIso8601String(),
    'status': status,
  };
}

class PerformanceDetails {
  final double rating;
  final String? notes;

  PerformanceDetails({this.rating = 0, this.notes});

  factory PerformanceDetails.fromJson(Map<String, dynamic> json) => PerformanceDetails(
    rating: (json['rating'] ?? 0).toDouble(),
    notes: json['notes'],
  );

  Map<String, dynamic> toJson() => {
    'rating': rating,
    'notes': notes,
  };
}

class ProbationDetails {
  final int durationMonths;
  final String status;

  ProbationDetails({this.durationMonths = 3, this.status = 'On Probation'});

  factory ProbationDetails.fromJson(Map<String, dynamic> json) => ProbationDetails(
    durationMonths: json['durationMonths'] ?? 3,
    status: json['status'] ?? 'On Probation',
  );

  Map<String, dynamic> toJson() => {
    'durationMonths': durationMonths,
    'status': status,
  };
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
