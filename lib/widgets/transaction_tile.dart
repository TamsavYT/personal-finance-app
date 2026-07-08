import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../utils/icon_helper.dart';

class TransactionTile extends StatelessWidget {
  final TransactionRecord transaction;
  final Category? category;
  final Account? account;
  final Account? toAccount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.category,
    this.account,
    this.toAccount,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData = Icons.receipt_long;
    Color iconColor = Colors.grey;

    if (transaction.type == 'transfer') {
      iconData = Icons.swap_horiz;
      iconColor = Colors.blue;
    } else if (category != null) {
      iconData = IconHelper.getIconFromCodePoint(int.parse(category!.icon));
      iconColor = Color(int.parse(category!.color.replaceFirst('#', '0xFF')));
    }

    String title = category?.name ?? 'Transfer';
    if (transaction.type == 'transfer') {
      title = 'Transfer';
    }

    String subtitle = account?.name ?? '';
    if (transaction.type == 'transfer') {
      if (toAccount != null) {
        subtitle += ' → ${toAccount!.name}';
      } else if (transaction.friendName != null && transaction.friendName!.isNotEmpty) {
        subtitle += ' → Friend: ${transaction.friendName}';
      }
    }
    if (transaction.note != null && transaction.note!.isNotEmpty) {
      subtitle += ' • ${transaction.note}';
    }

    Color amountColor = Colors.black;
    String amountPrefix = '';
    if (transaction.type == 'income') {
      amountColor = Colors.green;
      amountPrefix = '+';
    } else if (transaction.type == 'expense') {
      amountColor = Colors.red;
      amountPrefix = '-';
    } else {
      amountColor = Colors.blue;
    }

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.2),
        child: Icon(iconData, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$amountPrefix${CurrencyFormatter.formatCurrency(transaction.amount)}',
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormatter.formatDateShort(transaction.date),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
