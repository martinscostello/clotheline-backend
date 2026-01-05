import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat.decimalPattern('en_US');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Clean formatting and non-numerical characters
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // If empty after clean, return empty
    if (newText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Parse and format
    int value = int.parse(newText);
    String formatted = _formatter.format(value);

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
  static String formatString(String value) {
    if (value.isEmpty) return "";
    try {
      final numVal = int.parse(value.replaceAll(RegExp(r'[^0-9]'), ''));
      return _formatter.format(numVal);
    } catch (e) {
      return value;
    }
  }
}
