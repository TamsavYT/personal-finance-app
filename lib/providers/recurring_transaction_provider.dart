import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/recurring_transaction.dart';

class RecurringTransactionProvider extends ChangeNotifier {
  List<RecurringTransaction> _recurringTransactions = [];
  bool _isLoading = false;

  List<RecurringTransaction> get recurringTransactions => _recurringTransactions;
  bool get isLoading => _isLoading;

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> loadRecurringTransactions() async {
    try {
      _isLoading = true;
      notifyListeners();

      _recurringTransactions = await _db.getRecurringTransactions();
    } catch (e) {
      debugPrint('Error loading recurring transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addRecurringTransaction(RecurringTransaction recurring) async {
    try {
      await _db.insertRecurringTransaction(recurring);
      await loadRecurringTransactions();
    } catch (e) {
      debugPrint('Error adding recurring transaction: $e');
    }
  }

  Future<void> updateRecurringTransaction(RecurringTransaction recurring) async {
    try {
      await _db.updateRecurringTransaction(recurring);
      await loadRecurringTransactions();
    } catch (e) {
      debugPrint('Error updating recurring transaction: $e');
    }
  }

  Future<void> deleteRecurringTransaction(int id) async {
    try {
      await _db.deleteRecurringTransaction(id);
      _recurringTransactions.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting recurring transaction: $e');
    }
  }

  Future<void> setActive(RecurringTransaction recurring, bool isActive) async {
    await updateRecurringTransaction(recurring.copyWith(isActive: isActive));
  }
}
