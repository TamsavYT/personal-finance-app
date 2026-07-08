import 'package:flutter/material.dart';

/// Maps category names and account types to Material Design icons.
class IconHelper {
  IconHelper._();

  /// Icon lookup table for expense/income categories.
  static const Map<String, IconData> _categoryIcons = {
    'Food & Dining': Icons.restaurant,
    'Transport': Icons.directions_car,
    'Shopping': Icons.shopping_cart,
    'Entertainment': Icons.movie,
    'Bills & Utilities': Icons.receipt_long,
    'Health': Icons.favorite,
    'Education': Icons.school,
    'Rent': Icons.home,
    'Travel': Icons.flight,
    'Salary': Icons.account_balance_wallet,
    'Freelance': Icons.work,
    'Investment': Icons.trending_up,
    'Gift': Icons.card_giftcard,
    'Groceries': Icons.local_grocery_store,
    'Insurance': Icons.security,
    'Subscriptions': Icons.subscriptions,
    'Personal Care': Icons.spa,
    'Clothing': Icons.checkroom,
    'Electronics': Icons.devices,
    'Donations': Icons.volunteer_activism,
    'EMI': Icons.credit_card,
    'Fuel': Icons.local_gas_station,
    'Maintenance': Icons.build,
    'Interest': Icons.savings,
    'Refund': Icons.replay,
    'Other Income': Icons.attach_money,
    'Other Expense': Icons.money_off,
  };

  /// Returns the Material icon for the given [categoryName].
  ///
  /// Falls back to [Icons.category] when no mapping is found.
  static IconData getIconForCategory(String categoryName) {
    return _categoryIcons[categoryName] ?? Icons.category;
  }

  /// Icon lookup table for account types.
  static const Map<String, IconData> _accountTypeIcons = {
    'cash': Icons.money,
    'bank': Icons.account_balance,
    'upi': Icons.phone_android,
    'wallet': Icons.account_balance_wallet,
    'credit_card': Icons.credit_card,
  };

  /// Returns the Material icon for the given account [type].
  ///
  /// Falls back to [Icons.payment] when no mapping is found.
  static IconData getIconForAccountType(String type) {
    return _accountTypeIcons[type.toLowerCase()] ?? Icons.payment;
  }

  /// Constructs an [IconData] from a raw [codePoint], using the
  /// `MaterialIcons` font family.
  static IconData getIconFromCodePoint(int codePoint) {
    // ignore: non_const_argument_for_const_parameter
    return IconData(codePoint, fontFamily: 'MaterialIcons');
  }
}
