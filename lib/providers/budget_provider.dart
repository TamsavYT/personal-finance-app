import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/budget.dart';

class BudgetProvider extends ChangeNotifier {
  List<Budget> _budgets = [];
  bool _isLoading = false;
  int? _loadedMonth;
  int? _loadedYear;

  List<Budget> get budgets => _budgets;
  bool get isLoading => _isLoading;

  /// True once loadBudgets has completed for this month/year, even if the
  /// result was empty - lets callers avoid re-triggering a load from build().
  bool hasLoadedFor(int month, int year) =>
      _loadedMonth == month && _loadedYear == year;

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> loadBudgets(int month, int year) async {
    try {
      _isLoading = true;
      notifyListeners();

      _budgets = await _db.getBudgetsByMonthYear(month, year);
      _loadedMonth = month;
      _loadedYear = year;
    } catch (e) {
      debugPrint('Error loading budgets: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBudget(Budget budget) async {
    try {
      await _db.insertBudget(budget);
      await loadBudgets(budget.month, budget.year);
    } catch (e) {
      debugPrint('Error adding budget: $e');
    }
  }

  Future<void> updateBudget(Budget budget) async {
    try {
      await _db.updateBudget(budget);
      await loadBudgets(budget.month, budget.year);
    } catch (e) {
      debugPrint('Error updating budget: $e');
    }
  }

  Future<void> deleteBudget(int id) async {
    try {
      await _db.deleteBudget(id);
      _budgets.removeWhere((budget) => budget.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting budget: $e');
    }
  }

  Budget? getBudgetForCategory(int categoryId) {
    try {
      return _budgets.firstWhere((budget) => budget.categoryId == categoryId);
    } catch (e) {
      debugPrint('Budget not found for category id: $categoryId');
      return null;
    }
  }
}
