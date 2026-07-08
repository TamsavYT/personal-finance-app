import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/account.dart';

class AccountProvider extends ChangeNotifier {
  List<Account> _accounts = [];
  bool _isLoading = false;

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> loadAccounts() async {
    try {
      _isLoading = true;
      notifyListeners();

      _accounts = await _db.getActiveAccounts();
    } catch (e) {
      debugPrint('Error loading accounts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addAccount(Account account) async {
    try {
      await _db.insertAccount(account);
      await loadAccounts();
    } catch (e) {
      debugPrint('Error adding account: $e');
    }
  }

  Future<void> updateAccount(Account account) async {
    try {
      await _db.updateAccount(account);
      await loadAccounts();
    } catch (e) {
      debugPrint('Error updating account: $e');
    }
  }

  Future<void> deleteAccount(int id) async {
    try {
      await _db.deleteAccount(id);
      await loadAccounts();
    } catch (e) {
      debugPrint('Error deleting account: $e');
    }
  }

  Future<double> getAccountBalance(int accountId) async {
    try {
      return await _db.getAccountBalance(accountId);
    } catch (e) {
      debugPrint('Error getting account balance: $e');
      return 0.0;
    }
  }

  Future<double> getTotalBalance() async {
    try {
      double total = 0.0;
      for (final account in _accounts) {
        if (account.id != null) {
          total += await _db.getAccountBalance(account.id!);
        }
      }
      return total;
    } catch (e) {
      debugPrint('Error getting total balance: $e');
      return 0.0;
    }
  }

  Account? getAccountById(int id) {
    try {
      return _accounts.firstWhere((account) => account.id == id);
    } catch (e) {
      debugPrint('Account not found with id: $id');
      return null;
    }
  }
}
