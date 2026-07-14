import 'package:flutter/material.dart';
import '../models/account.dart';
import '../utils/currency_formatter.dart';
import '../utils/icon_helper.dart';
import '../utils/color_helper.dart';

class AccountCard extends StatelessWidget {
  final Account account;
  final double balance;
  final VoidCallback? onTap;

  const AccountCard({
    super.key,
    required this.account,
    required this.balance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color accountColor = ColorHelper.hexToColor(account.color);
    IconData iconData = IconHelper.getIconForAccountType(account.type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: accountColor, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(iconData, color: accountColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    account.name,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              CurrencyFormatter.formatCurrency(balance),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
