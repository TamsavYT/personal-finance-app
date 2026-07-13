import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recurring_transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../models/recurring_transaction.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecurringTransactionProvider>().loadRecurringTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Transactions')),
      body: Consumer2<RecurringTransactionProvider, CategoryProvider>(
        builder: (context, recurringProvider, catProvider, child) {
          if (recurringProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = recurringProvider.recurringTransactions;
          if (items.isEmpty) {
            return const Center(child: Text('No recurring transactions yet'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final rt = items[index];
              final category = catProvider.getCategoryById(rt.categoryId);

              return ListTile(
                title: Text(category?.name ?? 'Unknown Category'),
                subtitle: Text(
                  '${rt.frequency[0].toUpperCase()}${rt.frequency.substring(1)}'
                  ' • Next: ${_nextDueLabel(rt)}',
                ),
                leading: Icon(
                  rt.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
                  color: rt.type == 'income' ? Colors.green : Colors.red,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      CurrencyFormatter.formatCurrency(rt.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: rt.isActive,
                      onChanged: (val) => recurringProvider.setActive(rt, val),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => recurringProvider
                          .deleteRecurringTransaction(rt.id!),
                    ),
                  ],
                ),
                onTap: () => _showEditDialog(context, rt),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _nextDueLabel(RecurringTransaction rt) {
    if (rt.lastProcessedDate == null) {
      return DateFormatter.formatDate(rt.startDate);
    }
    return DateFormatter.formatDate(rt.lastProcessedDate!);
  }

  void _showEditDialog(BuildContext context, RecurringTransaction? existing) {
    final catProvider = context.read<CategoryProvider>();
    final accProvider = context.read<AccountProvider>();
    final recurringProvider = context.read<RecurringTransactionProvider>();

    final amountController = TextEditingController(
      text: existing != null ? existing.amount.toString() : '',
    );
    final noteController = TextEditingController(text: existing?.note ?? '');

    String type = existing?.type ?? 'expense';
    String frequency = existing?.frequency ?? 'monthly';
    DateTime startDate = existing?.startDate ?? DateTime.now();
    int? categoryId = existing?.categoryId ??
        (catProvider.expenseCategories.isNotEmpty
            ? catProvider.expenseCategories.first.id
            : null);
    int? accountId = existing?.accountId ??
        (accProvider.accounts.isNotEmpty ? accProvider.accounts.first.id : null);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            final categories = type == 'income'
                ? catProvider.incomeCategories
                : catProvider.expenseCategories;

            return AlertDialog(
              title: Text(existing == null ? 'Add Recurring' : 'Edit Recurring'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      items: ['income', 'expense']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) => setState(() {
                        type = val!;
                        categoryId = null;
                      }),
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    DropdownButtonFormField<int>(
                      value: categoryId,
                      items: categories
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (val) => setState(() => categoryId = val),
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    DropdownButtonFormField<int>(
                      value: accountId,
                      items: accProvider.accounts
                          .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                          .toList(),
                      onChanged: (val) => setState(() => accountId = val),
                      decoration: const InputDecoration(labelText: 'Account'),
                    ),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
                    ),
                    DropdownButtonFormField<String>(
                      value: frequency,
                      items: ['daily', 'weekly', 'monthly', 'yearly']
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (val) => setState(() => frequency = val!),
                      decoration: const InputDecoration(labelText: 'Frequency'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start Date'),
                      subtitle: Text(DateFormatter.formatDate(startDate)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => startDate = picked);
                      },
                    ),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Note (optional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    if (categoryId == null || accountId == null || amount <= 0) {
                      return;
                    }

                    final recurring = RecurringTransaction(
                      id: existing?.id,
                      type: type,
                      amount: amount,
                      categoryId: categoryId!,
                      accountId: accountId!,
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                      frequency: frequency,
                      startDate: startDate,
                      lastProcessedDate: existing?.lastProcessedDate,
                      isActive: existing?.isActive ?? true,
                    );

                    if (existing == null) {
                      recurringProvider.addRecurringTransaction(recurring);
                    } else {
                      recurringProvider.updateRecurringTransaction(recurring);
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
