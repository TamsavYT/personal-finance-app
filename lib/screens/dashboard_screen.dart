import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/account_card.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/empty_state.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const DashboardScreen({super.key, this.onSeeAll});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().loadAccounts();
      context.read<CategoryProvider>().loadCategories();
      context.read<TransactionProvider>().loadTransactions();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<AccountProvider>().loadAccounts();
    await context.read<CategoryProvider>().loadCategories();
    await context.read<TransactionProvider>().loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopSection(),
                _buildAccountsSection(),
                _buildRecentTransactionsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Consumer2<TransactionProvider, AccountProvider>(
      builder: (context, txProvider, accProvider, child) {
        return FutureBuilder<double>(
          future: accProvider.getTotalBalance(),
          builder: (context, snapshot) {
            double totalBalance = snapshot.data ?? 0;
            return BalanceCard(
              totalBalance: totalBalance,
              income: txProvider.monthlyIncome,
              expense: txProvider.monthlyExpense,
              month: txProvider.selectedMonth,
              onPreviousMonth: () {
                final current = txProvider.selectedMonth;
                txProvider.setSelectedMonth(DateTime(current.year, current.month - 1));
              },
              onNextMonth: () {
                final current = txProvider.selectedMonth;
                txProvider.setSelectedMonth(DateTime(current.year, current.month + 1));
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAccountsSection() {
    return Consumer<AccountProvider>(
      builder: (context, accProvider, child) {
        if (accProvider.accounts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Accounts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: accProvider.accounts.length,
                itemBuilder: (context, index) {
                  final account = accProvider.accounts[index];
                  return FutureBuilder<double>(
                    future: accProvider.getAccountBalance(account.id!),
                    builder: (context, snapshot) {
                      return AccountCard(
                        account: account,
                        balance: snapshot.data ?? 0,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Consumer3<TransactionProvider, CategoryProvider, AccountProvider>(
      builder: (context, txProvider, catProvider, accProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: widget.onSeeAll,
                    child: const Text('See All'),
                  ),
                ],
              ),
            ),
            if (txProvider.transactions.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long,
                title: 'No Transactions',
                subtitle: 'Tap the + button to add one',
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: txProvider.transactions.length > 5 ? 5 : txProvider.transactions.length,
                itemBuilder: (context, index) {
                  final tx = txProvider.transactions[index];
                  final category = catProvider.getCategoryById(tx.categoryId);
                  final account = accProvider.getAccountById(tx.accountId);
                  final toAccount = tx.toAccountId != null ? accProvider.getAccountById(tx.toAccountId!) : null;

                  return TransactionTile(
                    transaction: tx,
                    category: category,
                    account: account,
                    toAccount: toAccount,
                    onTap: () {
                      Navigator.pushNamed(context, '/add-transaction', arguments: tx);
                    },
                  );
                },
              ),
            const SizedBox(height: 80), // Padding for FAB
          ],
        );
      },
    );
  }
}
