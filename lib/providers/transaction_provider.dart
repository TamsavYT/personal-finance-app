import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import 'package:home_widget/home_widget.dart';

class TransactionProvider extends ChangeNotifier {
  List<TransactionRecord> _transactions = [];
  DateTime _selectedMonth = DateTime.now();
  String _filterType = 'all'; // 'all', 'income', 'expense', 'transfer'
  int? _filterAccountId;
  int? _filterCategoryId;
  String _searchQuery = '';
  bool _isLoading = false;

  List<TransactionRecord> get transactions => _transactions;
  DateTime get selectedMonth => _selectedMonth;
  String get filterType => _filterType;
  int? get filterAccountId => _filterAccountId;
  int? get filterCategoryId => _filterCategoryId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  final DatabaseHelper _db = DatabaseHelper.instance;

  List<TransactionRecord> get filteredTransactions {
    final query = _searchQuery.toLowerCase();

    return _transactions.where((t) {
      if (_filterType != 'all' && t.type != _filterType) return false;
      if (_filterAccountId != null && t.accountId != _filterAccountId) {
        return false;
      }
      if (_filterCategoryId != null && t.categoryId != _filterCategoryId) {
        return false;
      }
      if (query.isNotEmpty) {
        final noteMatch = t.note?.toLowerCase().contains(query) ?? false;
        final amountMatch = t.amount.toString().contains(query);
        if (!noteMatch && !amountMatch) return false;
      }
      return true;
    }).toList();
  }

  double get monthlyIncome {
    return _transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get monthlyExpense {
    return _transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get monthlyBalance => monthlyIncome - monthlyExpense;

  Future<void> loadTransactions() async {
    try {
      _isLoading = true;
      notifyListeners();

      _transactions = await _db.getTransactionsByMonth(
        _selectedMonth.month,
        _selectedMonth.year,
      );
      
      await _updateWidgetData();
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateWidgetData() async {
    try {
      final recent = _transactions.take(3).toList();
      String widgetText = '';
      if (recent.isEmpty) {
        widgetText = 'No recent transactions';
      } else {
        for (var t in recent) {
          String sign = t.type == 'expense' ? '-' : '+';
          widgetText += '${t.note ?? 'Transaction'} \n$sign\$${t.amount.toStringAsFixed(2)}\n\n';
        }
      }
      await HomeWidget.saveWidgetData<String>('recent_transactions', widgetText.trim());
      await HomeWidget.updateWidget(androidName: 'ExpenseWidgetProvider');
    } catch (e) {
      debugPrint('Widget update error: $e');
    }
  }

  Future<void> addTransaction(TransactionRecord transaction) async {
    try {
      await _db.insertTransaction(transaction);
      await loadTransactions();
    } catch (e) {
      debugPrint('Error adding transaction: $e');
    }
  }

  Future<void> updateTransaction(TransactionRecord transaction) async {
    try {
      await _db.updateTransaction(transaction);
      await loadTransactions();
    } catch (e) {
      debugPrint('Error updating transaction: $e');
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      await _db.deleteTransaction(id);
      await loadTransactions();
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
    }
  }

  Future<void> clearTransactionsForAccount(int accountId) async {
    try {
      await _db.clearTransactionsForAccount(accountId);
      await loadTransactions();
    } catch (e) {
      debugPrint('Error clearing transactions for account: $e');
    }
  }

  Future<int> importTransactions(List<TransactionRecord> transactions) async {
    try {
      final count = await _db.insertTransactions(transactions);
      if (transactions.isNotEmpty) {
        // Jump the view to the most recent imported transaction's month -
        // otherwise a historical import lands outside the current month
        // filter and looks like it silently did nothing.
        final latest = transactions.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b);
        _selectedMonth = DateTime(latest.year, latest.month);
      }
      await loadTransactions();
      return count;
    } catch (e) {
      debugPrint('Error importing transactions: $e');
      return 0;
    }
  }

  Future<void> clearAllTransactions() async {
    try {
      await _db.clearAllTransactions();
      await loadTransactions();
    } catch (e) {
      debugPrint('Error clearing all transactions: $e');
    }
  }

  void setSelectedMonth(DateTime month) {
    _selectedMonth = month;
    loadTransactions();
  }

  void setFilterType(String type) {
    _filterType = type;
    notifyListeners();
  }

  void setFilterAccount(int? accountId) {
    _filterAccountId = accountId;
    notifyListeners();
  }

  void setFilterCategory(int? categoryId) {
    _filterCategoryId = categoryId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _filterType = 'all';
    _filterAccountId = null;
    _filterCategoryId = null;
    _searchQuery = '';
    notifyListeners();
  }

  Future<List<TransactionRecord>> getRecentTransactions(int limit) async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final transactions = await _db.getTransactionsForDateRange(
        thirtyDaysAgo,
        now,
      );

      return transactions.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting recent transactions: $e');
      return [];
    }
  }
}
