import 'package:flutter/foundation.dart' hide Category;
import '../database/database_helper.dart';
import '../models/category.dart';

class CategoryProvider extends ChangeNotifier {
  List<Category> _categories = [];
  bool _isLoading = false;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;

  List<Category> get incomeCategories =>
      _categories.where((c) => c.type == 'income').toList();

  List<Category> get expenseCategories =>
      _categories.where((c) => c.type == 'expense').toList();

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> loadCategories() async {
    try {
      _isLoading = true;
      notifyListeners();

      _categories = await _db.getActiveCategories();
    } catch (e) {
      debugPrint('Error loading categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(Category category) async {
    try {
      await _db.insertCategory(category);
      await loadCategories();
    } catch (e) {
      debugPrint('Error adding category: $e');
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      await _db.updateCategory(category);
      await loadCategories();
    } catch (e) {
      debugPrint('Error updating category: $e');
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _db.deleteCategory(id);
      await loadCategories();
    } catch (e) {
      debugPrint('Error deleting category: $e');
    }
  }

  Category? getCategoryById(int id) {
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (e) {
      debugPrint('Category not found with id: $id');
      return null;
    }
  }
}
