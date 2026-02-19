

class CurrencyFormatter {

  static String format(num amount) {
    // If intl is not available or issues arise, use regex fallback
    // return "₦${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";
    
    // Using simple regex for maximum compatibility if intl setup is tricky without running pub get
    return "₦${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";
  }

  static String compact(num amount) {
    if (amount >= 1000000) {
      return "₦${(amount / 1000000).toStringAsFixed(1)}M";
    } else if (amount >= 1000) {
      return "₦${(amount / 1000).toStringAsFixed(1)}K";
    }
    return format(amount);
  }
}
