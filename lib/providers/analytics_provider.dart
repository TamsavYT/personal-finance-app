import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

class AnalyticsProvider extends ChangeNotifier {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  List<Map<String, dynamic>> _categoryExpenses = [];
  List<Map<String, dynamic>> _monthlyTrend = [];
  List<Map<String, dynamic>> _budgetStatus = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  bool _isLoading = false;

  int get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;
  List<Map<String, dynamic>> get categoryExpenses => _categoryExpenses;
  List<Map<String, dynamic>> get monthlyTrend => _monthlyTrend;
  List<Map<String, dynamic>> get budgetStatus => _budgetStatus;
  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;
  bool get isLoading => _isLoading;

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> loadAnalytics() async {
    try {
      _isLoading = true;
      notifyListeners();

      await Future.wait([
        loadCategoryExpenses(),
        loadMonthlyTrend(),
        loadBudgetStatus(),
        loadMonthlySummary(),
      ]);
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategoryExpenses() async {
    try {
      _categoryExpenses = await _db.getCategoryWiseExpenses(
        _selectedMonth,
        _selectedYear,
      );
    } catch (e) {
      debugPrint('Error loading category expenses: $e');
    }
  }

  Future<void> loadMonthlyTrend() async {
    try {
      _monthlyTrend = await _db.getMonthlyTrend(_selectedYear);
    } catch (e) {
      debugPrint('Error loading monthly trend: $e');
    }
  }

  Future<void> loadBudgetStatus() async {
    try {
      _budgetStatus = await _db.getBudgetStatus(
        _selectedMonth,
        _selectedYear,
      );
    } catch (e) {
      debugPrint('Error loading budget status: $e');
    }
  }

  Future<void> loadMonthlySummary() async {
    try {
      final summary = await _db.getMonthlySummary(
        _selectedMonth,
        _selectedYear,
      );
      _totalIncome = (summary['totalIncome'] ?? 0).toDouble();
      _totalExpense = (summary['totalExpense'] ?? 0).toDouble();
    } catch (e) {
      debugPrint('Error loading monthly summary: $e');
    }
  }

  void setMonth(int month, int year) {
    _selectedMonth = month;
    _selectedYear = year;
    loadAnalytics();
  }
}
