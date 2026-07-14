import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  static DatabaseHelper get instance => _instance;

  DatabaseHelper._internal();

  static const String _databaseName = 'expense_ledger.db';
  static const int _databaseVersion = 3;

  // Table names
  static const String tableAccounts = 'accounts';
  static const String tableCategories = 'categories';
  static const String tableTransactions = 'transactions';
  static const String tableBudgets = 'budgets';
  static const String tableRecurringTransactions = 'recurring_transactions';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add friend_name column
      await db.execute('ALTER TABLE $tableTransactions ADD COLUMN friend_name TEXT');
      // Insert Transfer category if not exists
      final existing = await db.query(
        tableCategories,
        where: 'name = ? AND type = ?',
        whereArgs: ['Transfer', 'transfer'],
        limit: 1,
      );
      if (existing.isEmpty) {
        final transferCategory = {
          'name': 'Transfer',
          'type': 'transfer',
          'icon': '0xe5d5',
          'color': '#1E88E5',
          'is_default': 1,
          'is_active': 1,
        };
        await db.insert(tableCategories, transferCategory);
      }
    }
    if (oldVersion < 3) {
      // Add UPI transaction reference columns
      await db.execute('ALTER TABLE $tableTransactions ADD COLUMN txn_id TEXT');
      await db.execute('ALTER TABLE $tableTransactions ADD COLUMN txn_ref TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create accounts table
    await db.execute('''
      CREATE TABLE $tableAccounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        initial_balance REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create categories table
    await db.execute('''
      CREATE TABLE $tableCategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create transactions table
    await db.execute('''
      CREATE TABLE $tableTransactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER NOT NULL,
        account_id INTEGER NOT NULL,
        to_account_id INTEGER,
        friend_name TEXT,
        note TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        recurring_type TEXT,
        txn_id TEXT,
        txn_ref TEXT,
        FOREIGN KEY (category_id) REFERENCES $tableCategories (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES $tableAccounts (id) ON DELETE CASCADE,
        FOREIGN KEY (to_account_id) REFERENCES $tableAccounts (id) ON DELETE SET NULL
      )
    ''');

    // Create budgets table
    await db.execute('''
      CREATE TABLE $tableBudgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        budget_limit REAL NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES $tableCategories (id) ON DELETE CASCADE,
        UNIQUE (category_id, month, year)
      )
    ''');

    // Create recurring_transactions table
    await db.execute('''
      CREATE TABLE $tableRecurringTransactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER NOT NULL,
        account_id INTEGER NOT NULL,
        note TEXT,
        frequency TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        last_processed_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (category_id) REFERENCES $tableCategories (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES $tableAccounts (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for performance
    await db.execute(
        'CREATE INDEX idx_transactions_date ON $tableTransactions (date)');
    await db.execute(
        'CREATE INDEX idx_transactions_account ON $tableTransactions (account_id)');
    await db.execute(
        'CREATE INDEX idx_transactions_category ON $tableTransactions (category_id)');
    await db.execute(
        'CREATE INDEX idx_transactions_type ON $tableTransactions (type)');
    await db.execute(
        'CREATE INDEX idx_budgets_month_year ON $tableBudgets (month, year)');
    await db.execute(
        'CREATE INDEX idx_recurring_active ON $tableRecurringTransactions (is_active)');

    // Seed default categories and accounts
    await _seedDefaultCategories(db);
    await _seedDefaultAccounts(db);
  }

  Future<void> _seedDefaultCategories(Database db) async {
    // Income categories
    final incomeCategories = [
      {'name': 'Salary', 'type': 'income', 'icon': '0xe227', 'color': '#4CAF50', 'is_default': 1, 'is_active': 1},
      {'name': 'Freelance', 'type': 'income', 'icon': '0xe5f9', 'color': '#2196F3', 'is_default': 1, 'is_active': 1},
      {'name': 'Investment', 'type': 'income', 'icon': '0xe870', 'color': '#FF9800', 'is_default': 1, 'is_active': 1},
      {'name': 'Gift', 'type': 'income', 'icon': '0xe8f6', 'color': '#E91E63', 'is_default': 1, 'is_active': 1},
      {'name': 'Other Income', 'type': 'income', 'icon': '0xe57a', 'color': '#9C27B0', 'is_default': 1, 'is_active': 1},
    ];

    // Expense categories
    final expenseCategories = [
      {'name': 'Food & Dining', 'type': 'expense', 'icon': '0xe56c', 'color': '#FF5722', 'is_default': 1, 'is_active': 1},
      {'name': 'Transport', 'type': 'expense', 'icon': '0xe1d7', 'color': '#3F51B5', 'is_default': 1, 'is_active': 1},
      {'name': 'Shopping', 'type': 'expense', 'icon': '0xe8cc', 'color': '#E91E63', 'is_default': 1, 'is_active': 1},
      {'name': 'Entertainment', 'type': 'expense', 'icon': '0xe63e', 'color': '#9C27B0', 'is_default': 1, 'is_active': 1},
      {'name': 'Bills & Utilities', 'type': 'expense', 'icon': '0xe8e5', 'color': '#607D8B', 'is_default': 1, 'is_active': 1},
      {'name': 'Health', 'type': 'expense', 'icon': '0xe3ec', 'color': '#F44336', 'is_default': 1, 'is_active': 1},
      {'name': 'Education', 'type': 'expense', 'icon': '0xe80c', 'color': '#00BCD4', 'is_default': 1, 'is_active': 1},
      {'name': 'Rent', 'type': 'expense', 'icon': '0xe88a', 'color': '#795548', 'is_default': 1, 'is_active': 1},
      {'name': 'Travel', 'type': 'expense', 'icon': '0xe539', 'color': '#009688', 'is_default': 1, 'is_active': 1},
      {'name': 'Other Expense', 'type': 'expense', 'icon': '0xe5d3', 'color': '#757575', 'is_default': 1, 'is_active': 1},
    ];

    // Transfer category
    final transferCategory = [
      {'name': 'Transfer', 'type': 'transfer', 'icon': '0xe5d5', 'color': '#1E88E5', 'is_default': 1, 'is_active': 1},
    ];

    for (final category in [...incomeCategories, ...expenseCategories, ...transferCategory]) {
      await db.insert(tableCategories, category);
    }
  }

  Future<void> _seedDefaultAccounts(Database db) async {
    final now = DateTime.now().toIso8601String();

    final defaultAccounts = [
      {
        'name': 'Cash',
        'type': 'cash',
        'icon': '0xe57a',
        'color': '#4CAF50',
        'initial_balance': 0.0,
        'created_at': now,
        'is_active': 1,
      },
      {
        'name': 'Bank Account',
        'type': 'bank',
        'icon': '0xe84f',
        'color': '#2196F3',
        'initial_balance': 0.0,
        'created_at': now,
        'is_active': 1,
      },
      {
        'name': 'UPI',
        'type': 'upi',
        'icon': '0xe1bc',
        'color': '#673AB7',
        'initial_balance': 0.0,
        'created_at': now,
        'is_active': 1,
      },
    ];

    for (final account in defaultAccounts) {
      await db.insert(tableAccounts, account);
    }
  }

  // ---------------------------------------------------------------------------
  // Account CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertAccount(Account account) async {
    final db = await database;
    return await db.insert(tableAccounts, account.toMap()..remove('id'));
  }

  Future<List<Account>> getAccounts() async {
    final db = await database;
    final maps = await db.query(tableAccounts, orderBy: 'name ASC');
    return maps.map((map) => Account.fromMap(map)).toList();
  }

  Future<List<Account>> getActiveAccounts() async {
    final db = await database;
    final maps = await db.query(
      tableAccounts,
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Account.fromMap(map)).toList();
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    return await db.update(
      tableAccounts,
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    return await db.delete(
      tableAccounts,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Category CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert(tableCategories, category.toMap()..remove('id'));
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.query(tableCategories, orderBy: 'name ASC');
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<List<Category>> getActiveCategories() async {
    final db = await database;
    final maps = await db.query(
      tableCategories,
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<List<Category>> getCategoriesByType(String type) async {
    final db = await database;
    final maps = await db.query(
      tableCategories,
      where: 'type = ? AND is_active = ?',
      whereArgs: [type, 1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      tableCategories,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete(
      tableCategories,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Transaction CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertTransaction(TransactionRecord transaction) async {
    final db = await database;
    return await db.insert(
        tableTransactions, transaction.toMap()..remove('id'));
  }

  Future<int> insertTransactions(List<TransactionRecord> transactions) async {
    final db = await database;
    int count = 0;
    await db.transaction((txn) async {
      for (final transaction in transactions) {
        await txn.insert(
            tableTransactions, transaction.toMap()..remove('id'));
        count++;
      }
    });
    return count;
  }

  Future<List<TransactionRecord>> getTransactions() async {
    final db = await database;
    final maps = await db.query(tableTransactions, orderBy: 'date DESC');
    return maps.map((map) => TransactionRecord.fromMap(map)).toList();
  }

  Future<TransactionRecord?> getTransactionById(int id) async {
    final db = await database;
    final maps = await db.query(
      tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return TransactionRecord.fromMap(maps.first);
  }

  Future<int> updateTransaction(TransactionRecord transaction) async {
    final db = await database;
    return await db.update(
      tableTransactions,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearTransactionsForAccount(int accountId) async {
    final db = await database;
    return await db.delete(
      tableTransactions,
      where: 'account_id = ? OR to_account_id = ?',
      whereArgs: [accountId, accountId],
    );
  }

  Future<int> clearAllTransactions() async {
    final db = await database;
    return await db.delete(tableTransactions);
  }

  // ---------------------------------------------------------------------------
  // Budget CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertBudget(Budget budget) async {
    final db = await database;
    return await db.insert(tableBudgets, budget.toMap()..remove('id'));
  }

  Future<List<Budget>> getBudgets() async {
    final db = await database;
    final maps = await db.query(tableBudgets, orderBy: 'year DESC, month DESC');
    return maps.map((map) => Budget.fromMap(map)).toList();
  }

  Future<List<Budget>> getBudgetsByMonthYear(int month, int year) async {
    final db = await database;
    final maps = await db.query(
      tableBudgets,
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
    );
    return maps.map((map) => Budget.fromMap(map)).toList();
  }

  Future<int> updateBudget(Budget budget) async {
    final db = await database;
    return await db.update(
      tableBudgets,
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteBudget(int id) async {
    final db = await database;
    return await db.delete(
      tableBudgets,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // RecurringTransaction CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertRecurringTransaction(
      RecurringTransaction recurringTransaction) async {
    final db = await database;
    return await db.insert(
        tableRecurringTransactions, recurringTransaction.toMap()..remove('id'));
  }

  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    final db = await database;
    final maps = await db.query(tableRecurringTransactions,
        orderBy: 'start_date DESC');
    return maps.map((map) => RecurringTransaction.fromMap(map)).toList();
  }

  Future<List<RecurringTransaction>> getActiveRecurringTransactions() async {
    final db = await database;
    final maps = await db.query(
      tableRecurringTransactions,
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'start_date DESC',
    );
    return maps.map((map) => RecurringTransaction.fromMap(map)).toList();
  }

  Future<int> updateRecurringTransaction(
      RecurringTransaction recurringTransaction) async {
    final db = await database;
    return await db.update(
      tableRecurringTransactions,
      recurringTransaction.toMap(),
      where: 'id = ?',
      whereArgs: [recurringTransaction.id],
    );
  }

  Future<int> deleteRecurringTransaction(int id) async {
    final db = await database;
    return await db.delete(
      tableRecurringTransactions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Special Query Methods
  // ---------------------------------------------------------------------------

  /// Returns all transactions within the given date range (inclusive).
  Future<List<TransactionRecord>> getTransactionsForDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query(
      tableTransactions,
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map((map) => TransactionRecord.fromMap(map)).toList();
  }

  /// Returns transactions for a specific month and year.
  Future<List<TransactionRecord>> getTransactionsByMonth(
      int month, int year) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);
    return getTransactionsForDateRange(startDate, endDate);
  }

  /// Calculates the current balance for an account by summing:
  /// initialBalance + income to account - expenses from account
  /// + transfers received - transfers sent
  Future<double> getAccountBalance(int accountId) async {
    final db = await database;

    // Get initial balance
    final accountMaps = await db.query(
      tableAccounts,
      columns: ['initial_balance'],
      where: 'id = ?',
      whereArgs: [accountId],
    );
    if (accountMaps.isEmpty) return 0.0;

    final initialBalance =
        (accountMaps.first['initial_balance'] as num).toDouble();

    // Sum income to this account
    final incomeResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0.0) as total FROM $tableTransactions '
      'WHERE account_id = ? AND type = ?',
      [accountId, 'income'],
    );
    final totalIncome = (incomeResult.first['total'] as num).toDouble();

    // Sum expenses from this account
    final expenseResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0.0) as total FROM $tableTransactions '
      'WHERE account_id = ? AND type = ?',
      [accountId, 'expense'],
    );
    final totalExpense = (expenseResult.first['total'] as num).toDouble();

    // Sum transfers received (to_account_id = this account)
    final transferInResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0.0) as total FROM $tableTransactions '
      'WHERE to_account_id = ? AND type = ?',
      [accountId, 'transfer'],
    );
    final totalTransferIn =
        (transferInResult.first['total'] as num).toDouble();

    // Sum transfers sent (account_id = this account, type = transfer)
    final transferOutResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0.0) as total FROM $tableTransactions '
      'WHERE account_id = ? AND type = ?',
      [accountId, 'transfer'],
    );
    final totalTransferOut =
        (transferOutResult.first['total'] as num).toDouble();

    return initialBalance + totalIncome - totalExpense + totalTransferIn -
        totalTransferOut;
  }

  /// Returns a summary map for a given month with totalIncome, totalExpense, balance.
  Future<Map<String, double>> getMonthlySummary(int month, int year) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate =
        DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    final incomeResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0.0) as total FROM $tableTransactions '
      'WHERE type = ? AND date >= ? AND date <= ?',
      ['income', startDate, endDate],
    );
    final totalIncome = (incomeResult.first['total'] as num).toDouble();

    final expenseResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0.0) as total FROM $tableTransactions '
      'WHERE type = ? AND date >= ? AND date <= ?',
      ['expense', startDate, endDate],
    );
    final totalExpense = (expenseResult.first['total'] as num).toDouble();

    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'balance': totalIncome - totalExpense,
    };
  }

  /// Returns category-wise expense breakdown for a given month.
  /// Each map: {categoryId, categoryName, total, color, icon}
  Future<List<Map<String, dynamic>>> getCategoryWiseExpenses(
      int month, int year) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate =
        DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    final results = await db.rawQuery('''
      SELECT 
        c.id as categoryId,
        c.name as categoryName,
        COALESCE(SUM(t.amount), 0.0) as total,
        c.color as color,
        c.icon as icon
      FROM $tableTransactions t
      INNER JOIN $tableCategories c ON t.category_id = c.id
      WHERE t.type = ? AND t.date >= ? AND t.date <= ?
      GROUP BY c.id
      ORDER BY total DESC
    ''', ['expense', startDate, endDate]);

    return results
        .map((row) => {
              'categoryId': row['categoryId'],
              'categoryName': row['categoryName'],
              'total': (row['total'] as num).toDouble(),
              'color': row['color'],
              'icon': row['icon'],
            })
        .toList();
  }

  /// Returns monthly income/expense trend for a full year (12 months).
  /// Each map: {month, income, expense}
  Future<List<Map<String, dynamic>>> getMonthlyTrend(int year) async {
    final db = await database;
    final startDate = DateTime(year, 1, 1).toIso8601String();
    final endDate = DateTime(year, 12, 31, 23, 59, 59).toIso8601String();

    final results = await db.rawQuery(
      '''
      SELECT
        CAST(strftime('%m', date) AS INTEGER) as month,
        type,
        COALESCE(SUM(amount), 0.0) as total
      FROM $tableTransactions
      WHERE date >= ? AND date <= ? AND type IN ('income', 'expense')
      GROUP BY month, type
      ''',
      [startDate, endDate],
    );

    final trend = List.generate(
      12,
      (i) => {'month': i + 1, 'income': 0.0, 'expense': 0.0},
    );

    for (final row in results) {
      final month = row['month'] as int;
      final type = row['type'] as String;
      trend[month - 1][type] = (row['total'] as num).toDouble();
    }

    return trend;
  }

  /// Returns budget status for a given month.
  /// Each map: {categoryId, categoryName, budgetLimit, spent, remaining, percentage}
  Future<List<Map<String, dynamic>>> getBudgetStatus(
      int month, int year) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate =
        DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    final results = await db.rawQuery('''
      SELECT 
        b.category_id as categoryId,
        c.name as categoryName,
        b.budget_limit as budgetLimit,
        COALESCE(SUM(t.amount), 0.0) as spent
      FROM $tableBudgets b
      INNER JOIN $tableCategories c ON b.category_id = c.id
      LEFT JOIN $tableTransactions t 
        ON t.category_id = b.category_id 
        AND t.type = 'expense' 
        AND t.date >= ? 
        AND t.date <= ?
      WHERE b.month = ? AND b.year = ?
      GROUP BY b.category_id
    ''', [startDate, endDate, month, year]);

    return results.map((row) {
      final budgetLimit = (row['budgetLimit'] as num).toDouble();
      final spent = (row['spent'] as num).toDouble();
      final remaining = budgetLimit - spent;
      final percentage = budgetLimit > 0 ? (spent / budgetLimit) * 100 : 0.0;

      return {
        'categoryId': row['categoryId'],
        'categoryName': row['categoryName'],
        'budgetLimit': budgetLimit,
        'spent': spent,
        'remaining': remaining,
        'percentage': percentage,
      };
    }).toList();
  }

  /// Returns active recurring transactions that are due for processing.
  /// A recurring transaction is due if:
  /// - It has never been processed (lastProcessedDate is null) and startDate <= now
  /// - OR the next due date based on frequency has passed
  Future<List<RecurringTransaction>> getDueRecurringTransactions() async {
    final db = await database;
    final now = DateTime.now();

    // Get all active recurring transactions
    final maps = await db.query(
      tableRecurringTransactions,
      where: 'is_active = ?',
      whereArgs: [1],
    );

    final allActive =
        maps.map((map) => RecurringTransaction.fromMap(map)).toList();

    return allActive.where((rt) {
      // Check if end_date has passed
      if (rt.endDate != null && rt.endDate!.isBefore(now)) return false;

      // Never processed but start date has arrived
      if (rt.lastProcessedDate == null) {
        return !rt.startDate.isAfter(now);
      }

      // Calculate next due date from lastProcessedDate
      final nextDue = _calculateNextDueDate(rt.lastProcessedDate!, rt.frequency);
      return !nextDue.isAfter(now);
    }).toList();
  }

  /// Calculates the next due date based on the last processed date and frequency.
  DateTime _calculateNextDueDate(DateTime lastProcessed, String frequency) {
    switch (frequency) {
      case 'daily':
        return lastProcessed.add(const Duration(days: 1));
      case 'weekly':
        return lastProcessed.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(
          lastProcessed.year,
          lastProcessed.month + 1,
          lastProcessed.day,
        );
      case 'yearly':
        return DateTime(
          lastProcessed.year + 1,
          lastProcessed.month,
          lastProcessed.day,
        );
      default:
        return lastProcessed.add(const Duration(days: 30));
    }
  }

  /// Processes all due recurring transactions:
  /// 1. Finds all due recurring transactions
  /// 2. Creates actual TransactionRecords for each
  /// 3. Updates lastProcessedDate on each recurring transaction
  /// Uses a database transaction for atomicity.
  Future<int> processRecurringTransactions() async {
    final db = await database;
    final dueTransactions = await getDueRecurringTransactions();

    if (dueTransactions.isEmpty) return 0;

    int processedCount = 0;
    final now = DateTime.now();

    await db.transaction((txn) async {
      for (final rt in dueTransactions) {
        // Create the actual transaction record
        final transaction = TransactionRecord(
          type: rt.type,
          amount: rt.amount,
          categoryId: rt.categoryId,
          accountId: rt.accountId,
          note: rt.note != null ? '${rt.note} (recurring)' : '(recurring)',
          date: now,
          createdAt: now,
          isRecurring: true,
          recurringType: rt.frequency,
        );

        await txn.insert(tableTransactions, transaction.toMap()..remove('id'));

        // Update lastProcessedDate on the recurring transaction
        await txn.update(
          tableRecurringTransactions,
          {'last_processed_date': now.toIso8601String()},
          where: 'id = ?',
          whereArgs: [rt.id],
        );

        processedCount++;
      }
    });

    return processedCount;
  }

  /// Close the database. Typically called when the app is disposed.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
