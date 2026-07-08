import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../models/transaction.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/empty_state.dart';
import '../utils/date_formatter.dart';
import '../utils/currency_formatter.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search amount or note...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  context.read<TransactionProvider>().setSearchQuery(value);
                },
              )
            : const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  context.read<TransactionProvider>().setSearchQuery('');
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: Consumer3<TransactionProvider, CategoryProvider, AccountProvider>(
        builder: (context, txProvider, catProvider, accProvider, child) {
          return Column(
            children: [
              _buildMonthSelector(context, txProvider),
              _buildFilterChips(txProvider),
              Expanded(
                child: txProvider.filteredTransactions.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long,
                        title: 'No Transactions',
                        subtitle: 'No transactions found for this period.',
                      )
                    : RefreshIndicator(
                        onRefresh: () => txProvider.loadTransactions(),
                        child: _buildGroupedTransactions(
                          txProvider.filteredTransactions,
                          catProvider,
                          accProvider,
                          txProvider,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context, TransactionProvider txProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final current = txProvider.selectedMonth;
              txProvider.setSelectedMonth(DateTime(current.year, current.month - 1));
            },
          ),
          Text(
            DateFormatter.formatMonth(txProvider.selectedMonth.month, txProvider.selectedMonth.year),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final current = txProvider.selectedMonth;
              txProvider.setSelectedMonth(DateTime(current.year, current.month + 1));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(TransactionProvider txProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _buildChip('All', 'all', txProvider),
          const SizedBox(width: 8),
          _buildChip('Income', 'income', txProvider),
          const SizedBox(width: 8),
          _buildChip('Expense', 'expense', txProvider),
          const SizedBox(width: 8),
          _buildChip('Transfer', 'transfer', txProvider),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, TransactionProvider txProvider) {
    final isSelected = txProvider.filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          txProvider.setFilterType(value);
        }
      },
    );
  }

  Widget _buildGroupedTransactions(
    List<TransactionRecord> transactions,
    CategoryProvider catProvider,
    AccountProvider accProvider,
    TransactionProvider txProvider,
  ) {
    // Group transactions by date
    Map<String, List<TransactionRecord>> grouped = {};
    for (var tx in transactions) {
      String dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(tx);
    }

    // Sort dates descending
    List<String> sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        String dateKey = sortedDates[index];
        List<TransactionRecord> dailyTxs = grouped[dateKey]!;
        DateTime parsedDate = DateTime.parse(dateKey);

        // Calculate daily total
        double dailyTotal = 0;
        for (var tx in dailyTxs) {
          if (tx.type == 'income') dailyTotal += tx.amount;
          if (tx.type == 'expense') dailyTotal -= tx.amount;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormatter.formatRelative(parsedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  Text(
                    CurrencyFormatter.formatWithSign(dailyTotal, dailyTotal >= 0 ? 'income' : 'expense'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: dailyTotal >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            ...dailyTxs.map((tx) {
              final category = catProvider.getCategoryById(tx.categoryId);
              final account = accProvider.getAccountById(tx.accountId);
              final toAccount = tx.toAccountId != null ? accProvider.getAccountById(tx.toAccountId!) : null;

              return Dismissible(
                key: Key('tx_${tx.id}'),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Confirm"),
                        content: const Text("Are you sure you wish to delete this item?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("CANCEL"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text("DELETE"),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) {
                  txProvider.deleteTransaction(tx.id!);
                },
                child: TransactionTile(
                  transaction: tx,
                  category: category,
                  account: account,
                  toAccount: toAccount,
                  onTap: () {
                    Navigator.pushNamed(context, '/add-transaction', arguments: tx);
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
