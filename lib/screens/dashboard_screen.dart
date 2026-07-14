import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/account_card.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/empty_state.dart';
import 'qr_scan_screen.dart';
import '../models/upi_qr_prefill.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const DashboardScreen({super.key, this.onSeeAll});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<double>? _totalBalanceFuture;
  final Map<int, Future<double>> _accountBalanceFutures = {};

  @override
  void initState() {
    super.initState();
    // Load data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AccountProvider>().loadAccounts();
      if (!mounted) return;
      await context.read<CategoryProvider>().loadCategories();
      if (!mounted) return;
      await context.read<TransactionProvider>().loadTransactions();
      if (mounted) _refreshBalances();
    });
  }

  void _refreshBalances() {
    final accProvider = context.read<AccountProvider>();
    setState(() {
      _totalBalanceFuture = accProvider.getTotalBalance();
      _accountBalanceFutures.clear();
      for (final account in accProvider.accounts) {
        _accountBalanceFutures[account.id!] =
            accProvider.getAccountBalance(account.id!);
      }
    });
  }

  Future<void> _onRefresh() async {
    await context.read<AccountProvider>().loadAccounts();
    if (!mounted) return;
    await context.read<CategoryProvider>().loadCategories();
    if (!mounted) return;
    await context.read<TransactionProvider>().loadTransactions();
    _refreshBalances();
  }

  Future<void> _scanUpiQr() async {
    final prefill = await Navigator.of(context).push<UpiQrPrefill>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (prefill == null || !mounted) return;

    final hasUpiAccount = context.read<AccountProvider>().accounts.any((a) => a.type == 'upi');
    if (!hasUpiAccount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No UPI account set up yet - add one in Settings to pay directly. '
            'Amount and payee have been prefilled for now.'),
        duration: Duration(seconds: 5),
      ));
    }

    if (!mounted) return;
    await Navigator.pushNamed(context, '/add-transaction', arguments: prefill);
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
                _buildScanQrButton(),
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
          future: _totalBalanceFuture,
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

  Widget _buildScanQrButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: OutlinedButton.icon(
        onPressed: _scanUpiQr,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan UPI QR to Pay'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
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
                    future: _accountBalanceFutures.putIfAbsent(
                      account.id!,
                      () => accProvider.getAccountBalance(account.id!),
                    ),
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
