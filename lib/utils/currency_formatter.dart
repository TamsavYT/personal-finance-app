import 'package:intl/intl.dart';

/// Formats monetary values in Indian Rupee (₹) notation.
///
/// Supports full formatting, compact notation (K / L / Cr), and
/// sign-prefixed output based on transaction type.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Formats [amount] as a full INR string — e.g. `₹1,23,456.78`.
  static String formatCurrency(double amount) {
    return _inrFormat.format(amount.abs());
  }

  /// Formats [amount] in a compact form for large numbers:
  /// - < 1,000      → `₹999.00`
  /// - < 1,00,000   → `₹12.5K`
  /// - < 1,00,00,000 → `₹12.5L`
  /// - ≥ 1,00,00,000 → `₹1.2Cr`
  static String formatCurrencyShort(double amount) {
    final absAmount = amount.abs();

    if (absAmount < 1000) {
      return _inrFormat.format(absAmount);
    } else if (absAmount < 100000) {
      // Thousands
      final value = absAmount / 1000;
      return '₹${_compactNumber(value)}K';
    } else if (absAmount < 10000000) {
      // Lakhs
      final value = absAmount / 100000;
      return '₹${_compactNumber(value)}L';
    } else {
      // Crores
      final value = absAmount / 10000000;
      return '₹${_compactNumber(value)}Cr';
    }
  }

  /// Formats [amount] with a leading sign based on [type]:
  /// - `income`   → `+₹1,234.56`
  /// - `expense`  → `-₹1,234.56`
  /// - `transfer` → `₹1,234.56`
  static String formatWithSign(double amount, String type) {
    final formatted = formatCurrency(amount);

    switch (type.toLowerCase()) {
      case 'income':
        return '+$formatted';
      case 'expense':
        return '-$formatted';
      default:
        return formatted;
    }
  }

  /// Strips unnecessary trailing zeros for compact notation.
  static String _compactNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}
