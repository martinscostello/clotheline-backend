class OPayFeeCalculator {
  static const Map<String, List<OPayTierRange>> fees = {
    'Platinum': [
      OPayTierRange(min: 1, max: 3000, percentage: 0.0043),
      OPayTierRange(min: 3001, max: 4000, fixed: 17.00),
      OPayTierRange(min: 4001, max: 5000, fixed: 21.25),
      OPayTierRange(min: 5001, max: 6000, fixed: 25.55),
      OPayTierRange(min: 6001, max: 7000, fixed: 29.75),
      OPayTierRange(min: 7001, max: 8000, fixed: 34.00),
      OPayTierRange(min: 8001, max: 9000, fixed: 38.25),
      OPayTierRange(min: 9001, max: 10000, fixed: 42.225), // Rounded for double
      OPayTierRange(min: 10001, max: 11000, fixed: 46.75),
      OPayTierRange(min: 11001, max: 12000, fixed: 51.00),
      OPayTierRange(min: 12001, max: 13000, fixed: 55.25),
      OPayTierRange(min: 13001, max: 14000, fixed: 59.50),
      OPayTierRange(min: 14001, max: 15000, fixed: 63.75),
      OPayTierRange(min: 15001, max: 16000, fixed: 68.00),
      OPayTierRange(min: 16001, max: 17000, fixed: 72.25),
      OPayTierRange(min: 17001, max: 18000, fixed: 76.50),
      OPayTierRange(min: 18001, max: 19000, fixed: 80.75),
      OPayTierRange(min: 19001, max: 20000, fixed: 85.00),
      OPayTierRange(min: 20001, max: double.infinity, fixed: 85.00), // Capped
    ],
    'Gold': [
      OPayTierRange(min: 1, max: 3000, percentage: 0.0045),
      OPayTierRange(min: 3001, max: 4000, fixed: 18.00),
      OPayTierRange(min: 4001, max: 5000, fixed: 22.50),
      OPayTierRange(min: 5001, max: 6000, fixed: 27.00),
      OPayTierRange(min: 6001, max: 7000, fixed: 31.50),
      OPayTierRange(min: 7001, max: 8000, fixed: 36.00),
      OPayTierRange(min: 8001, max: 9000, fixed: 40.50),
      OPayTierRange(min: 9001, max: 10000, fixed: 45.00),
      OPayTierRange(min: 10001, max: 11000, fixed: 49.50),
      OPayTierRange(min: 11001, max: 12000, fixed: 54.00),
      OPayTierRange(min: 12001, max: 13000, fixed: 58.50),
      OPayTierRange(min: 13001, max: 14000, fixed: 63.00),
      OPayTierRange(min: 14001, max: 15000, fixed: 67.50),
      OPayTierRange(min: 15001, max: 16000, fixed: 72.00),
      OPayTierRange(min: 16001, max: 17000, fixed: 76.50),
      OPayTierRange(min: 17001, max: 18000, fixed: 81.00),
      OPayTierRange(min: 18001, max: 19000, fixed: 85.50),
      OPayTierRange(min: 19001, max: 20000, fixed: 90.00),
      OPayTierRange(min: 20001, max: double.infinity, fixed: 90.00), // Capped
    ],
    'Regular': [
      OPayTierRange(min: 1, max: 3000, percentage: 0.0050),
      OPayTierRange(min: 3001, max: 4000, fixed: 20.00),
      OPayTierRange(min: 4001, max: 5000, fixed: 25.00),
      OPayTierRange(min: 5001, max: 6000, fixed: 30.00),
      OPayTierRange(min: 6001, max: 7000, fixed: 35.00),
      OPayTierRange(min: 7001, max: 8000, fixed: 40.00),
      OPayTierRange(min: 8001, max: 9000, fixed: 45.00),
      OPayTierRange(min: 9001, max: 10000, fixed: 50.00),
      OPayTierRange(min: 10001, max: 11000, fixed: 55.00),
      OPayTierRange(min: 11001, max: 12000, fixed: 60.00),
      OPayTierRange(min: 12001, max: 13000, fixed: 65.00),
      OPayTierRange(min: 13001, max: 14000, fixed: 70.00),
      OPayTierRange(min: 14001, max: 15000, fixed: 75.00),
      OPayTierRange(min: 15001, max: 16000, fixed: 80.00),
      OPayTierRange(min: 16001, max: 17000, fixed: 85.00),
      OPayTierRange(min: 17001, max: 18000, fixed: 90.00),
      OPayTierRange(min: 18001, max: 19000, fixed: 95.00),
      OPayTierRange(min: 19001, max: 20000, fixed: 100.00),
      OPayTierRange(min: 20001, max: double.infinity, fixed: 100.00), // Capped
    ],
  };

  static double calculateFee(double amount, String tier) {
    if (amount <= 0) return 0;
    
    final ranges = fees[tier] ?? fees['Regular']!;
    for (var range in ranges) {
      if (amount >= range.min && amount <= range.max) {
        if (range.percentage != null) {
          return amount * range.percentage!;
        }
        return range.fixed ?? 0;
      }
    }
    
    // Fallback to last range (Capped value for 20,000+)
    return ranges.last.fixed ?? 0;
  }
}

class OPayTierRange {
  final double min;
  final double max;
  final double? percentage;
  final double? fixed;

  const OPayTierRange({
    required this.min,
    required this.max,
    this.percentage,
    this.fixed,
  });
}
