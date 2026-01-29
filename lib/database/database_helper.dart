import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/expense_model.dart';
import '../models/account_model.dart';
import '../models/budget_model.dart';
import '../models/recurring_expense_model.dart';
import '../models/recurring_income_model.dart';
import '../models/category_model.dart';
import '../models/income_model.dart';
import '../models/quick_template_model.dart';
import '../models/monthly_balance_model.dart';
import '../utils/decimal_helper.dart';
import '../utils/date_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  // FIX: Add completer to prevent race condition during initialization
  static Completer<Database>? _initCompleter;

  // FIX: Add timeout duration for database operations
  static const Duration _queryTimeout = Duration(seconds: 30);

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    // FIX: If database already initialized, return immediately
    if (_database != null) return _database!;

    // FIX: If initialization in progress, wait for it to complete
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      if (kDebugMode) debugPrint('Database initialization already in progress, waiting...');
      return await _initCompleter!.future;
    }

    // FIX: Start new initialization
    _initCompleter = Completer<Database>();
    try {
      if (kDebugMode) debugPrint('Starting database initialization...');
      _database = await _initDatabase();
      _initCompleter!.complete(_database!);
      if (kDebugMode) debugPrint('Database initialization complete');
      return _database!;
    } catch (e) {
      if (kDebugMode) debugPrint('Database initialization failed: $e');
      _initCompleter!.completeError(e);
      _initCompleter = null; // Reset so retry is possible
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final dbPath = path.join(databasePath, 'expense_tracker_v4.db');

    return await openDatabase(
      dbPath,
      version: 17, // Bumped version for overall_budget column
      // FIX #4: Enable SQLite foreign key enforcement
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Accounts table
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        isDefault INTEGER DEFAULT 0,
        currencyCode TEXT DEFAULT 'USD'
      )
    ''');

    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        amountPaid REAL DEFAULT 0,
        paymentMethod TEXT DEFAULT 'Cash',
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // Income table
    await db.execute('''
      CREATE TABLE income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // Budgets table
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        month TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // Recurring expenses table
    await db.execute('''
      CREATE TABLE recurring_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        dayOfMonth INTEGER NOT NULL,
        isActive INTEGER DEFAULT 1,
        lastCreated TEXT,
        account_id INTEGER NOT NULL,
        paymentMethod TEXT DEFAULT 'Cash',
        endDate TEXT,
        maxOccurrences INTEGER,
        occurrenceCount INTEGER DEFAULT 0,
        frequency INTEGER DEFAULT 0,
        startDate TEXT,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        isDefault INTEGER DEFAULT 0,
        type TEXT DEFAULT 'expense',
        color TEXT,
        icon TEXT,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // Deleted expenses table (for 30-day restore)
    await db.execute('''
      CREATE TABLE deleted_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_id INTEGER,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        amountPaid REAL DEFAULT 0,
        paymentMethod TEXT,
        deletedAt TEXT NOT NULL
      )
    ''');

    // Deleted income table (for 30-day restore)
    await db.execute('''
      CREATE TABLE deleted_income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_id INTEGER,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        deletedAt TEXT NOT NULL
      )
    ''');

    // Deleted accounts table (for 30-day restore)
    await db.execute('''
      CREATE TABLE deleted_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_id INTEGER,
        name TEXT NOT NULL,
        deletedAt TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');

    // Quick templates table
    await db.execute('''
      CREATE TABLE quick_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        paymentMethod TEXT DEFAULT 'Cash',
        type TEXT DEFAULT 'expense',
        account_id INTEGER NOT NULL,
        sortOrder INTEGER DEFAULT 0,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // Recurring income table
    await db.execute('''
      CREATE TABLE recurring_income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        dayOfMonth INTEGER NOT NULL,
        isActive INTEGER DEFAULT 1,
        lastCreated TEXT,
        account_id INTEGER NOT NULL,
        frequency INTEGER DEFAULT 0,
        startDate TEXT,
        endDate TEXT,
        maxOccurrences INTEGER,
        occurrenceCount INTEGER DEFAULT 0,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // Tags table for transactions
    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color TEXT,
        account_id INTEGER NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // Transaction-tags junction table
    await db.execute('''
      CREATE TABLE transaction_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        transaction_type TEXT NOT NULL,
        tag_id INTEGER NOT NULL,
        FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
      )
    ''');

    // Monthly balances table (for carryover tracking and overall budget)
    await db.execute('''
      CREATE TABLE monthly_balances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        carryover_from_previous REAL DEFAULT 0,
        overall_budget REAL,
        account_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
        UNIQUE(account_id, month)
      )
    ''');

    // Insert default account
    await db.insert('accounts', {
      'name': 'Main Account',
      'isDefault': 1,
    });

    // Insert default expense categories
    final defaultExpenseCategories = [
      'Food', 'Transport', 'Shopping', 'Entertainment',
      'Health', 'Education', 'Bills', 'Other'
    ];
    for (var cat in defaultExpenseCategories) {
      await db.insert('categories', {
        'name': cat,
        'account_id': 1,
        'isDefault': 1,
        'type': 'expense',
      });
    }

    // Insert default income categories
    final defaultIncomeCategories = [
      'Salary', 'Freelance', 'Investment', 'Gift', 'Other'
    ];
    for (var cat in defaultIncomeCategories) {
      await db.insert('categories', {
        'name': cat,
        'account_id': 1,
        'isDefault': 1,
        'type': 'income',
      });
    }

    // CRITICAL FIX: Create all indexes for new databases
    // Performance indexes for expenses and income
    await db.execute('CREATE INDEX idx_expenses_account_date ON expenses(account_id, date DESC)');
    await db.execute('CREATE INDEX idx_expenses_category ON expenses(account_id, category)');
    await db.execute('CREATE INDEX idx_expenses_description ON expenses(account_id, description)');
    await db.execute('CREATE INDEX idx_income_account_date ON income(account_id, date DESC)');
    await db.execute('CREATE INDEX idx_income_category ON income(account_id, category)');
    await db.execute('CREATE INDEX idx_income_description ON income(account_id, description)');
    await db.execute('CREATE INDEX idx_expenses_account_date_category ON expenses(account_id, date DESC, category)');
    await db.execute('CREATE INDEX idx_income_account_date_category ON income(account_id, date DESC, category)');

    // Indexes for deleted tables (trash cleanup queries)
    await db.execute('CREATE INDEX idx_deleted_expenses_deletedAt ON deleted_expenses(deletedAt)');
    await db.execute('CREATE INDEX idx_deleted_income_deletedAt ON deleted_income(deletedAt)');
    await db.execute('CREATE INDEX idx_deleted_accounts_deletedAt ON deleted_accounts(deletedAt)');
    await db.execute('CREATE INDEX idx_deleted_expenses_account ON deleted_expenses(account_id, deletedAt)');
    await db.execute('CREATE INDEX idx_deleted_income_account ON deleted_income(account_id, deletedAt)');

    // Performance indexes for budgets (month/category queries)
    await db.execute('CREATE INDEX idx_budgets_account_month ON budgets(account_id, month)');
    await db.execute('CREATE INDEX idx_budgets_category ON budgets(account_id, category)');

    // Performance indexes for recurring transactions (active status queries)
    await db.execute('CREATE INDEX idx_recurring_expenses_active ON recurring_expenses(account_id, isActive)');
    await db.execute('CREATE INDEX idx_recurring_income_active ON recurring_income(account_id, isActive)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      // Add income table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS income (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          description TEXT,
          date TEXT NOT NULL,
          account_id INTEGER NOT NULL,
          FOREIGN KEY (account_id) REFERENCES accounts (id)
        )
      ''');

      // Add quick_templates table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quick_templates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          paymentMethod TEXT DEFAULT 'Cash',
          type TEXT DEFAULT 'expense',
          account_id INTEGER NOT NULL,
          sortOrder INTEGER DEFAULT 0,
          FOREIGN KEY (account_id) REFERENCES accounts (id)
        )
      ''');

      // Add columns safely using helper method (no more try-catch guessing)
      await _addColumnIfNotExists(db, 'expenses', 'paymentMethod', 'TEXT DEFAULT "Cash"');
      await _addColumnIfNotExists(db, 'recurring_expenses', 'paymentMethod', 'TEXT DEFAULT "Cash"');
      await _addColumnIfNotExists(db, 'categories', 'type', 'TEXT DEFAULT "expense"');
      await _addColumnIfNotExists(db, 'accounts', 'icon', 'TEXT');
      await _addColumnIfNotExists(db, 'accounts', 'color', 'TEXT');

      // Insert default income categories if they don't exist
      final defaultIncomeCategories = [
        'Salary', 'Freelance', 'Investment', 'Gift', 'Other'
      ];
      for (var cat in defaultIncomeCategories) {
        final existing = await db.query(
          'categories',
          where: 'name = ? AND type = ?',
          whereArgs: [cat, 'income'],
        );
        if (existing.isEmpty) {
          await db.insert('categories', {
            'name': cat,
            'account_id': 1,
            'isDefault': 1,
            'type': 'income',
          });
        }
      }
    }

    if (oldVersion < 5) {
      // Add deleted_income table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS deleted_income (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          original_id INTEGER,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          description TEXT,
          date TEXT NOT NULL,
          account_id INTEGER NOT NULL,
          deletedAt TEXT NOT NULL
        )
      ''');

      // Add original_id to deleted_expenses if not exists
      await _addColumnIfNotExists(db, 'deleted_expenses', 'original_id', 'INTEGER');
    }

    if (oldVersion < 6) {
      // Add recurring_income table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_income (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          dayOfMonth INTEGER NOT NULL,
          isActive INTEGER DEFAULT 1,
          lastCreated TEXT,
          account_id INTEGER NOT NULL,
          FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
        )
      ''');

      // Add tags table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          color TEXT,
          account_id INTEGER NOT NULL,
          FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
        )
      ''');

      // Add transaction_tags junction table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transaction_tags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL,
          transaction_type TEXT NOT NULL,
          tag_id INTEGER NOT NULL,
          FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 7) {
      // Add frequency and startDate columns for recurring income
      await _addColumnIfNotExists(db, 'recurring_income', 'frequency', 'INTEGER DEFAULT 0');
      await _addColumnIfNotExists(db, 'recurring_income', 'startDate', 'TEXT');
    }

    if (oldVersion < 8) {
      // Add deleted_accounts table for account undo feature
      await db.execute('''
        CREATE TABLE IF NOT EXISTS deleted_accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          original_id INTEGER,
          name TEXT NOT NULL,
          deletedAt TEXT NOT NULL,
          data TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 9) {
      // FIX: Add currency column to accounts table to prevent backup desynchronization
      await _addColumnIfNotExists(db, 'accounts', 'currencyCode', 'TEXT DEFAULT "USD"');
    }

    if (oldVersion < 10) {
      // FIX: Add end date and max occurrences to recurring transactions
      await _addColumnIfNotExists(db, 'recurring_expenses', 'endDate', 'TEXT');
      await _addColumnIfNotExists(db, 'recurring_expenses', 'maxOccurrences', 'INTEGER');
      await _addColumnIfNotExists(db, 'recurring_expenses', 'occurrenceCount', 'INTEGER DEFAULT 0');
      await _addColumnIfNotExists(db, 'recurring_income', 'endDate', 'TEXT');
      await _addColumnIfNotExists(db, 'recurring_income', 'maxOccurrences', 'INTEGER');
      await _addColumnIfNotExists(db, 'recurring_income', 'occurrenceCount', 'INTEGER DEFAULT 0');
    }

    if (oldVersion < 11) {
      // FIX: Add frequency support to recurring expenses (parity with recurring income)
      await _addColumnIfNotExists(db, 'recurring_expenses', 'frequency', 'INTEGER DEFAULT 0');
      await _addColumnIfNotExists(db, 'recurring_expenses', 'startDate', 'TEXT');
    }

    if (oldVersion < 12) {
      // FIX: Add indexes to improve search performance and prevent full table scans
      // These indexes significantly speed up queries with WHERE clauses on these columns
      await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_account_date ON expenses(account_id, date DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(account_id, category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_description ON expenses(account_id, description)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_income_account_date ON income(account_id, date DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_income_category ON income(account_id, category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_income_description ON income(account_id, description)');
      // Composite index for common date range queries
      await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_account_date_category ON expenses(account_id, date DESC, category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_income_account_date_category ON income(account_id, date DESC, category)');
    }

    if (oldVersion < 13) {
      // CRITICAL FIX: Add indexes on deleted tables for faster trash cleanup and queries
      // These prevent full table scans when cleaning up 30-day old items
      await db.execute('CREATE INDEX IF NOT EXISTS idx_deleted_expenses_deletedAt ON deleted_expenses(deletedAt)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_deleted_income_deletedAt ON deleted_income(deletedAt)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_deleted_accounts_deletedAt ON deleted_accounts(deletedAt)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_deleted_expenses_account ON deleted_expenses(account_id, deletedAt)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_deleted_income_account ON deleted_income(account_id, deletedAt)');

      // Performance indexes for budgets and recurring transactions
      await db.execute('CREATE INDEX IF NOT EXISTS idx_budgets_account_month ON budgets(account_id, month)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_budgets_category ON budgets(account_id, category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_recurring_expenses_active ON recurring_expenses(account_id, isActive)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_recurring_income_active ON recurring_income(account_id, isActive)');
    }

    if (oldVersion < 14) {
      // Add color column to categories table for visual category indicators
      await _addColumnIfNotExists(db, 'categories', 'color', 'TEXT');
    }

    if (oldVersion < 15) {
      // Add icon column to categories table for category icons
      await _addColumnIfNotExists(db, 'categories', 'icon', 'TEXT');
    }

    if (oldVersion < 16) {
      // Add monthly_balances table for carryover tracking
      await db.execute('''
        CREATE TABLE IF NOT EXISTS monthly_balances (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          carryover_from_previous REAL DEFAULT 0,
          account_id INTEGER NOT NULL,
          month TEXT NOT NULL,
          FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
          UNIQUE(account_id, month)
        )
      ''');
    }

    if (oldVersion < 17) {
      // Add overall_budget column to monthly_balances table
      await _addColumnIfNotExists(db, 'monthly_balances', 'overall_budget', 'REAL');
    }
  }

  /// Safely adds a column to a table if it doesn't already exist.
  /// Uses PRAGMA table_info to check schema, avoiding try-catch that could
  /// swallow legitimate errors (syntax errors, locked database, etc.)
  Future<void> _addColumnIfNotExists(
    Database db,
    String tableName,
    String columnName,
    String columnDefinition,
  ) async {
    // Query table schema using PRAGMA
    final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');

    // Check if column already exists
    final columnExists = tableInfo.any((row) => row['name'] == columnName);

    if (!columnExists) {
      await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition');
    }
  }

  /// FIX P1-4: Execute a query with timeout to prevent UI freeze.
  /// Returns null if timeout occurs.
  ///
  /// Usage: Wrap potentially long-running queries (especially those involving
  /// large datasets or complex JOINs) with this method to prevent UI freezes.
  ///
  /// Example:
  /// ```dart
  /// final result = await _queryWithTimeout(() => db.query('expenses', ...));
  /// if (result == null) {
  ///   // Handle timeout - show error or retry
  /// }
  /// ```
  ///
  /// Note: Most simple CRUD operations complete quickly and don't need timeouts.
  /// Use this primarily for:
  /// - Backup/restore operations
  /// - Bulk data exports
  /// - Complex aggregate queries
  /// - Operations on large datasets (1000+ records)
  Future<T?> _queryWithTimeout<T>(Future<T> Function() query, {Duration? timeout}) async {
    try {
      return await query().timeout(timeout ?? _queryTimeout);
    } on TimeoutException {
      if (kDebugMode) debugPrint('Database query timed out after ${timeout ?? _queryTimeout}');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Database query error: $e');
      rethrow;
    }
  }

  // ============== INCOME METHODS ==============

  Future<int> createIncome(Income income) async {
    final db = await database;
    return await db.insert('income', income.toMap());
  }

  Future<List<Income>> readAllIncome(int accountId) async {
    final db = await database;
    final result = await db.query(
      'income',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'date DESC',
    );
    return result.map((map) => Income.fromMap(map)).toList();
  }

  Future<List<Income>> getIncomeByMonth(int accountId, int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    final result = await db.query(
      'income',
      where: 'account_id = ? AND date >= ? AND date <= ?',
      whereArgs: [accountId, startDate, endDate],
      orderBy: 'date DESC',
    );
    return result.map((map) => Income.fromMap(map)).toList();
  }

  Future<int> updateIncome(Income income) async {
    final db = await database;
    return await db.update(
      'income',
      income.toMap(),
      where: 'id = ?',
      whereArgs: [income.id],
    );
  }

  Future<int> deleteIncome(int id) async {
    final db = await database;

    // FIX: Delete orphaned tags first to prevent data integrity issues
    await db.delete(
      'transaction_tags',
      where: 'transaction_id = ? AND transaction_type = ?',
      whereArgs: [id, 'income'],
    );

    return await db.delete(
      'income',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Move income to deleted (for undo/restore)
  Future<void> moveIncomeToDeleted(Income income) async {
    final db = await database;
    await db.insert('deleted_income', {
      'original_id': income.id,
      'amount': income.amount,
      'category': income.category,
      'description': income.description,
      'date': income.date.toIso8601String(),
      'account_id': income.accountId,
      // FIX: Use UTC to avoid timezone-dependent expiration
      'deletedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await db.delete('income', where: 'id = ?', whereArgs: [income.id]);
  }

  // Move income to deleted by ID (fetches from DB if needed)
  Future<bool> moveIncomeToDeletedById(int id) async {
    final income = await getIncomeById(id);
    if (income == null) return false;
    await moveIncomeToDeleted(income);
    return true;
  }

  // ============== QUICK TEMPLATE METHODS ==============

  Future<int> createTemplate(QuickTemplate template) async {
    final db = await database;
    return await db.insert('quick_templates', template.toMap());
  }

  Future<List<QuickTemplate>> readAllTemplates(int accountId) async {
    final db = await database;
    final result = await db.query(
      'quick_templates',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'sortOrder ASC, name ASC',
    );
    return result.map((map) => QuickTemplate.fromMap(map)).toList();
  }

  Future<int> updateTemplate(QuickTemplate template) async {
    final db = await database;
    return await db.update(
      'quick_templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  Future<int> deleteTemplate(int id) async {
    final db = await database;
    return await db.delete(
      'quick_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============== ACCOUNT METHODS ==============

  Future<int> createAccount(Account account) async {
    final db = await database;
    return await db.insert('accounts', account.toMap());
  }

  Future<List<Account>> readAllAccounts() async {
    final db = await database;
    final result = await db.query('accounts', orderBy: 'isDefault DESC, name ASC');
    return result.map((map) => Account.fromMap(map)).toList();
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    return await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  // FIX #3: Soft delete account - move to trash for 30-day restore
  Future<int> deleteAccount(int id) async {
    final db = await database;

    // Don't allow deleting the default account
    final accountResult = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (accountResult.isEmpty) {
      throw Exception('Account not found');
    }
    if (accountResult.first['isDefault'] == 1) {
      throw Exception('Cannot delete default account');
    }

    final accountName = accountResult.first['name'] as String;
    // FIX: Use UTC to avoid timezone-dependent expiration
    final deletedAt = DateTime.now().toUtc();

    // FIX: Save backup to file instead of database to prevent OOM crashes
    // This avoids SQLite row size limits and massive memory allocations
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(path.join(appDocDir.path, 'deleted_accounts'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    // FIX: Check available disk space before creating backup
    // Estimate: 1KB per transaction + overhead, minimum 10MB free space required
    final transactionCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM expenses WHERE account_id = ?',
      [id],
    );
    final expenseCount = Sqflite.firstIntValue(transactionCount) ?? 0;

    final incomeCountQuery = await db.rawQuery(
      'SELECT COUNT(*) as count FROM income WHERE account_id = ?',
      [id],
    );
    final incomeCount = Sqflite.firstIntValue(incomeCountQuery) ?? 0;

    // FIX: Log estimated backup size for diagnostics (debug only)
    if (kDebugMode) {
      final estimatedSizeBytes = (expenseCount + incomeCount) * 1024; // 1KB per transaction
      final estimatedSizeMB = estimatedSizeBytes / (1024 * 1024);
      debugPrint('Estimated backup size: ${estimatedSizeMB.toStringAsFixed(2)}MB for $expenseCount expenses + $incomeCount incomes');
    }

    // Note: We can't reliably check free space on all platforms without platform channels
    // So we'll catch disk full errors during file write instead

    final backupFile = File(path.join(
      backupsDir.path,
      'account_${id}_${deletedAt.millisecondsSinceEpoch}.json',
    ));

    // Write data incrementally to file using a stream to avoid loading everything in memory
    final sink = backupFile.openWrite();

    try {
      // Start JSON object
      sink.write('{"account":');
      sink.write(jsonEncode(accountResult.first));

      // Write expenses in batches
      sink.write(',"expenses":[');
      const batchSize = 500;
      int expenseOffset = 0;
      bool firstExpense = true;
      while (true) {
        final expenseBatch = await db.query(
          'expenses',
          where: 'account_id = ?',
          whereArgs: [id],
          limit: batchSize,
          offset: expenseOffset,
        );
        if (expenseBatch.isEmpty) break;

        for (final expense in expenseBatch) {
          if (!firstExpense) sink.write(',');
          sink.write(jsonEncode(expense));
          firstExpense = false;
        }
        expenseOffset += batchSize;
      }
      sink.write(']');

      // Write income in batches
      sink.write(',"income":[');
      int incomeOffset = 0;
      bool firstIncome = true;
      while (true) {
        final incomeBatch = await db.query(
          'income',
          where: 'account_id = ?',
          whereArgs: [id],
          limit: batchSize,
          offset: incomeOffset,
        );
        if (incomeBatch.isEmpty) break;

        for (final income in incomeBatch) {
          if (!firstIncome) sink.write(',');
          sink.write(jsonEncode(income));
          firstIncome = false;
        }
        incomeOffset += batchSize;
      }
      sink.write(']');

      // Write other data (typically small)
      final budgets = await db.query('budgets', where: 'account_id = ?', whereArgs: [id]);
      sink.write(',"budgets":');
      sink.write(jsonEncode(budgets));

      final recurringExpenses = await db.query('recurring_expenses', where: 'account_id = ?', whereArgs: [id]);
      sink.write(',"recurringExpenses":');
      sink.write(jsonEncode(recurringExpenses));

      final recurringIncome = await db.query('recurring_income', where: 'account_id = ?', whereArgs: [id]);
      sink.write(',"recurringIncome":');
      sink.write(jsonEncode(recurringIncome));

      final categories = await db.query('categories', where: 'account_id = ?', whereArgs: [id]);
      sink.write(',"categories":');
      sink.write(jsonEncode(categories));

      final templates = await db.query('quick_templates', where: 'account_id = ?', whereArgs: [id]);
      sink.write(',"templates":');
      sink.write(jsonEncode(templates));

      // Close JSON object
      sink.write('}');

      await sink.flush();
      await sink.close();

      // Store metadata in database (just filename and basic info, not the actual data)
      await db.insert('deleted_accounts', {
        'original_id': id,
        'name': accountName,
        'deletedAt': deletedAt.toIso8601String(),
        'data': backupFile.path, // Store file path instead of JSON blob
      });
    } catch (e) {
      // FIX: Better error handling for disk write failures
      if (kDebugMode) debugPrint('Error creating account backup: $e');

      // Clean up file if something went wrong
      try {
        if (await backupFile.exists()) {
          await backupFile.delete();
        }
      } catch (deleteError) {
        if (kDebugMode) debugPrint('Could not delete incomplete backup file: $deleteError');
        // Track orphaned file for cleanup
        await _trackOrphanedFile(backupFile.path);
      }

      // Provide user-friendly error message
      if (e.toString().contains('No space left') || e.toString().contains('disk full')) {
        throw Exception('Not enough disk space to backup account. Please free up space and try again.');
      }
      rethrow;
    }

    // FIX: Delete orphaned tags in batches to prevent OOM
    const batchSize = 500;

    // Batch delete tags for expenses
    int tagExpenseOffset = 0;
    while (true) {
      final expenseIdsBatch = await db.query(
        'expenses',
        columns: ['id'],
        where: 'account_id = ?',
        whereArgs: [id],
        limit: batchSize,
        offset: tagExpenseOffset,
      );
      if (expenseIdsBatch.isEmpty) break;

      for (final expenseRow in expenseIdsBatch) {
        await db.delete('transaction_tags', where: 'transaction_id = ? AND transaction_type = ?', whereArgs: [expenseRow['id'], 'expense']);
      }
      tagExpenseOffset += batchSize;
    }

    // Batch delete tags for income
    int tagIncomeOffset = 0;
    while (true) {
      final incomeIdsBatch = await db.query(
        'income',
        columns: ['id'],
        where: 'account_id = ?',
        whereArgs: [id],
        limit: batchSize,
        offset: tagIncomeOffset,
      );
      if (incomeIdsBatch.isEmpty) break;

      for (final incomeRow in incomeIdsBatch) {
        await db.delete('transaction_tags', where: 'transaction_id = ? AND transaction_type = ?', whereArgs: [incomeRow['id'], 'income']);
      }
      tagIncomeOffset += batchSize;
    }

    // Delete all associated data
    await db.delete('expenses', where: 'account_id = ?', whereArgs: [id]);
    await db.delete('income', where: 'account_id = ?', whereArgs: [id]);
    await db.delete('budgets', where: 'account_id = ?', whereArgs: [id]);
    await db.delete('recurring_expenses', where: 'account_id = ?', whereArgs: [id]);
    await db.delete('recurring_income', where: 'account_id = ?', whereArgs: [id]);
    await db.delete('categories', where: 'account_id = ?', whereArgs: [id]);
    await db.delete('quick_templates', where: 'account_id = ?', whereArgs: [id]);
    await db.delete('deleted_expenses', where: 'account_id = ?', whereArgs: [id]);
    await db.delete('deleted_income', where: 'account_id = ?', whereArgs: [id]);
    // FIX: Also delete tags that belong to this account
    await db.delete('tags', where: 'account_id = ?', whereArgs: [id]);

    // Finally delete the account
    return await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  /// FIX: Track orphaned backup files that failed to delete
  Future<void> _trackOrphanedFile(String filePath) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final orphanedLog = File(path.join(appDocDir.path, 'orphaned_files.log'));

      final timestamp = DateTime.now().toUtc().toIso8601String();
      await orphanedLog.writeAsString(
        '$timestamp: $filePath\n',
        mode: FileMode.append,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Could not track orphaned file: $e');
    }
  }

  /// FIX: Clean up orphaned backup files
  Future<int> cleanOrphanedBackupFiles() async {
    int cleanedCount = 0;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();

      // Check orphaned log file
      final orphanedLog = File(path.join(appDocDir.path, 'orphaned_files.log'));
      if (await orphanedLog.exists()) {
        final lines = await orphanedLog.readAsLines();
        for (final line in lines) {
          try {
            // Parse: "timestamp: filepath"
            final parts = line.split(': ');
            if (parts.length >= 2) {
              final filePath = parts.sublist(1).join(': '); // Rejoin in case path has ':'
              final file = File(filePath);
              if (await file.exists()) {
                await file.delete();
                cleanedCount++;
              }
            }
          } catch (e) {
            if (kDebugMode) debugPrint('Error cleaning orphaned file from log: $e');
          }
        }

        // Clear the log after cleanup
        await orphanedLog.delete();
      }

      // Also scan backups directory for files not in database
      final backupsDir = Directory(path.join(appDocDir.path, 'deleted_accounts'));
      if (await backupsDir.exists()) {
        final db = await database;
        final registeredPaths = (await db.query('deleted_accounts', columns: ['data']))
            .map((row) => row['data'] as String)
            .toSet();

        await for (final entity in backupsDir.list()) {
          if (entity is File && !registeredPaths.contains(entity.path)) {
            try {
              await entity.delete();
              cleanedCount++;
              if (kDebugMode) debugPrint('Cleaned orphaned backup: ${entity.path}');
            } catch (e) {
              if (kDebugMode) debugPrint('Could not delete orphaned backup: $e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error during orphaned file cleanup: $e');
    }
    return cleanedCount;
  }

  /// Get list of deleted accounts that can be restored
  Future<List<Map<String, dynamic>>> getDeletedAccounts() async {
    final db = await database;
    // FIX: Use UTC to avoid timezone-dependent expiration
    final cutoffDate = DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String();

    // FIX: Clean up old backup files before deleting database records
    final oldAccounts = await db.query(
      'deleted_accounts',
      where: 'deletedAt < ?',
      whereArgs: [cutoffDate],
    );

    for (final account in oldAccounts) {
      final filePath = account['data'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          // FIX: Track failed deletions instead of silently ignoring
          if (kDebugMode) debugPrint('Failed to delete old backup file: $e');
          await _trackOrphanedFile(filePath);
        }
      }
    }

    // Clean up database records for accounts older than 30 days
    await db.delete(
      'deleted_accounts',
      where: 'deletedAt < ?',
      whereArgs: [cutoffDate],
    );

    return await db.query(
      'deleted_accounts',
      orderBy: 'deletedAt DESC',
    );
  }

  /// Restore a deleted account and all its data
  Future<int> restoreDeletedAccount(int deletedId) async {
    final db = await database;

    final result = await db.query(
      'deleted_accounts',
      where: 'id = ?',
      whereArgs: [deletedId],
    );

    if (result.isEmpty) {
      throw Exception('Deleted account not found');
    }

    final deletedAccount = result.first;
    final accountName = deletedAccount['name'] as String;
    final filePath = deletedAccount['data'] as String;

    // FIX: Read backup data from file instead of database
    final backupFile = File(filePath);
    if (!await backupFile.exists()) {
      throw Exception('Backup file not found');
    }

    final jsonString = await backupFile.readAsString();
    final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

    // Create a new account with the same name
    final newAccountId = await db.insert('accounts', {
      'name': accountName,
      'isDefault': 0,
    });

    // Restore expenses
    final expenses = backupData['expenses'] as List<dynamic>? ?? [];
    for (final expense in expenses) {
      final expenseMap = Map<String, dynamic>.from(expense as Map);
      expenseMap.remove('id');
      expenseMap['account_id'] = newAccountId;
      await db.insert('expenses', expenseMap);
    }

    // Restore income
    final income = backupData['income'] as List<dynamic>? ?? [];
    for (final inc in income) {
      final incomeMap = Map<String, dynamic>.from(inc as Map);
      incomeMap.remove('id');
      incomeMap['account_id'] = newAccountId;
      await db.insert('income', incomeMap);
    }

    // Restore budgets
    final budgets = backupData['budgets'] as List<dynamic>? ?? [];
    for (final budget in budgets) {
      final budgetMap = Map<String, dynamic>.from(budget as Map);
      budgetMap.remove('id');
      budgetMap['account_id'] = newAccountId;
      await db.insert('budgets', budgetMap);
    }

    // Restore recurring expenses
    final recurringExpenses = backupData['recurringExpenses'] as List<dynamic>? ?? [];
    for (final rec in recurringExpenses) {
      final recMap = Map<String, dynamic>.from(rec as Map);
      recMap.remove('id');
      recMap['account_id'] = newAccountId;
      await db.insert('recurring_expenses', recMap);
    }

    // Restore recurring income
    final recurringIncome = backupData['recurringIncome'] as List<dynamic>? ?? [];
    for (final rec in recurringIncome) {
      final recMap = Map<String, dynamic>.from(rec as Map);
      recMap.remove('id');
      recMap['account_id'] = newAccountId;
      await db.insert('recurring_income', recMap);
    }

    // Restore categories (non-default ones)
    final categories = backupData['categories'] as List<dynamic>? ?? [];
    for (final cat in categories) {
      final catMap = Map<String, dynamic>.from(cat as Map);
      if (catMap['isDefault'] != 1) {
        catMap.remove('id');
        catMap['account_id'] = newAccountId;
        await db.insert('categories', catMap);
      }
    }

    // Restore quick templates
    final templates = backupData['templates'] as List<dynamic>? ?? [];
    for (final template in templates) {
      final templateMap = Map<String, dynamic>.from(template as Map);
      templateMap.remove('id');
      templateMap['account_id'] = newAccountId;
      await db.insert('quick_templates', templateMap);
    }

    // Remove from deleted_accounts
    await db.delete('deleted_accounts', where: 'id = ?', whereArgs: [deletedId]);

    // FIX: Delete the backup file after successful restore
    if (await backupFile.exists()) {
      await backupFile.delete();
    }

    return newAccountId;
  }

  /// Permanently delete a trashed account
  Future<void> permanentlyDeleteAccount(int deletedId) async {
    final db = await database;

    // FIX: Delete the backup file before removing database record
    final result = await db.query('deleted_accounts', where: 'id = ?', whereArgs: [deletedId]);
    if (result.isNotEmpty) {
      final filePath = result.first['data'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await db.delete('deleted_accounts', where: 'id = ?', whereArgs: [deletedId]);
  }

  // ============== EXPENSE METHODS ==============

  Future<int> createExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> readAllExpenses(int accountId) async {
    final db = await database;
    const orderBy = 'date DESC';
    final result = await db.query(
      'expenses',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: orderBy,
    );
    return result.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getExpensesByMonth(int accountId, int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    final result = await db.query(
      'expenses',
      where: 'account_id = ? AND date >= ? AND date <= ?',
      whereArgs: [accountId, startDate, endDate],
      orderBy: 'date DESC',
    );
    return result.map((map) => Expense.fromMap(map)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;

    // FIX: Delete orphaned tags first to prevent data integrity issues
    await db.delete(
      'transaction_tags',
      where: 'transaction_id = ? AND transaction_type = ?',
      whereArgs: [id, 'expense'],
    );

    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get single expense by ID
  Future<Expense?> getExpenseById(int id) async {
    final db = await database;
    final result = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Expense.fromMap(result.first);
  }

  // Get single income by ID
  Future<Income?> getIncomeById(int id) async {
    final db = await database;
    final result = await db.query(
      'income',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Income.fromMap(result.first);
  }

  // Move expense to deleted (for 30-day restore)
  Future<void> moveToDeleted(Expense expense) async {
    final db = await database;
    await db.insert('deleted_expenses', {
      'original_id': expense.id,
      'amount': expense.amount,
      'category': expense.category,
      'description': expense.description,
      'date': expense.date.toIso8601String(),
      'account_id': expense.accountId,
      'amountPaid': expense.amountPaid,
      'paymentMethod': expense.paymentMethod,
      // FIX: Use UTC to avoid timezone-dependent expiration
      'deletedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await db.delete('expenses', where: 'id = ?', whereArgs: [expense.id]);
  }

  // Move expense to deleted by ID (fetches from DB if needed)
  Future<bool> moveToDeletedById(int id) async {
    final expense = await getExpenseById(id);
    if (expense == null) return false;
    await moveToDeleted(expense);
    return true;
  }

  // FIX #2: Get ALL deleted expenses (for trash screen)
  Future<List<Map<String, dynamic>>> getAllDeletedExpenses(int accountId) async {
    final db = await database;
    // FIX: Use UTC to avoid timezone-dependent expiration
    final thirtyDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String();
    final result = await db.query(
      'deleted_expenses',
      where: 'account_id = ? AND deletedAt >= ?',
      whereArgs: [accountId, thirtyDaysAgo],
      orderBy: 'deletedAt DESC',
    );
    return result;
  }

  // Get ALL deleted income (for trash screen)
  Future<List<Map<String, dynamic>>> getAllDeletedIncome(int accountId) async {
    final db = await database;
    // FIX: Use UTC to avoid timezone-dependent expiration
    final thirtyDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String();
    final result = await db.query(
      'deleted_income',
      where: 'account_id = ? AND deletedAt >= ?',
      whereArgs: [accountId, thirtyDaysAgo],
      orderBy: 'deletedAt DESC',
    );
    return result;
  }

  // Restore specific deleted expense by id
  Future<void> restoreDeletedExpense(int deletedId) async {
    final db = await database;
    final result = await db.query(
      'deleted_expenses',
      where: 'id = ?',
      whereArgs: [deletedId],
    );

    if (result.isNotEmpty) {
      final map = result.first;
      await db.insert('expenses', {
        'amount': map['amount'],
        'category': map['category'],
        'description': map['description'],
        'date': map['date'],
        'account_id': map['account_id'],
        'amountPaid': map['amountPaid'],
        'paymentMethod': map['paymentMethod'],
      });
      await db.delete('deleted_expenses', where: 'id = ?', whereArgs: [deletedId]);
    }
  }

  // Restore specific deleted income by id
  Future<void> restoreDeletedIncome(int deletedId) async {
    final db = await database;
    final result = await db.query(
      'deleted_income',
      where: 'id = ?',
      whereArgs: [deletedId],
    );

    if (result.isNotEmpty) {
      final map = result.first;
      await db.insert('income', {
        'amount': map['amount'],
        'category': map['category'],
        'description': map['description'],
        'date': map['date'],
        'account_id': map['account_id'],
      });
      await db.delete('deleted_income', where: 'id = ?', whereArgs: [deletedId]);
    }
  }

  // Permanently delete from trash
  Future<void> permanentlyDeleteExpense(int deletedId) async {
    final db = await database;
    await db.delete('deleted_expenses', where: 'id = ?', whereArgs: [deletedId]);
  }

  Future<void> permanentlyDeleteIncome(int deletedId) async {
    final db = await database;
    await db.delete('deleted_income', where: 'id = ?', whereArgs: [deletedId]);
  }

  // Get last deleted expense for a specific account (for quick undo)
  Future<Expense?> getLastDeleted(int accountId) async {
    final db = await database;
    final result = await db.query(
      'deleted_expenses',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'deletedAt DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;

    final map = result.first;
    return Expense(
      amount: DecimalHelper.fromDoubleSafe(map['amount'] as double?),
      category: map['category'] as String,
      description: map['description'] as String? ?? '',
      date: DateHelper.parseDate(map['date'] as String) ?? DateHelper.today(),
      accountId: map['account_id'] as int,
      amountPaid: DecimalHelper.fromDoubleSafe(map['amountPaid'] as double?),
      paymentMethod: map['paymentMethod'] as String? ?? 'Cash',
    );
  }

  // Restore last deleted expense for a specific account (for quick undo)
  Future<void> restoreLastDeleted(int accountId) async {
    final db = await database;
    final result = await db.query(
      'deleted_expenses',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'deletedAt DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      final map = result.first;
      await db.insert('expenses', {
        'amount': map['amount'],
        'category': map['category'],
        'description': map['description'],
        'date': map['date'],
        'account_id': map['account_id'],
        'amountPaid': map['amountPaid'],
        'paymentMethod': map['paymentMethod'],
      });
      await db.delete('deleted_expenses', where: 'id = ?', whereArgs: [map['id']]);
    }
  }

  // Clear old deleted items (30 days) - call on app startup
  Future<void> clearOldDeleted() async {
    final db = await database;
    // FIX: Use UTC to avoid timezone-dependent expiration
    final thirtyDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String();
    await db.delete(
      'deleted_expenses',
      where: 'deletedAt < ?',
      whereArgs: [thirtyDaysAgo],
    );
    await db.delete(
      'deleted_income',
      where: 'deletedAt < ?',
      whereArgs: [thirtyDaysAgo],
    );
  }

  // Empty trash completely
  Future<void> emptyTrash(int accountId) async {
    final db = await database;
    await db.delete('deleted_expenses', where: 'account_id = ?', whereArgs: [accountId]);
    await db.delete('deleted_income', where: 'account_id = ?', whereArgs: [accountId]);
  }

  // ============== BUDGET METHODS ==============

  Future<int> createBudget(Budget budget) async {
    final db = await database;
    return await db.insert('budgets', budget.toMap());
  }

  /// CRITICAL FIX: Read budgets with optional month filter and limit
  /// Without filters, this could load ALL budgets across ALL months into memory
  Future<List<Budget>> readAllBudgets(int accountId, {DateTime? month, int? limit}) async {
    final db = await database;

    String whereClause = 'account_id = ?';
    List<dynamic> whereArgs = [accountId];

    // Add month filter if provided (recommended for most use cases)
    if (month != null) {
      final monthStart = DateTime(month.year, month.month, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 0);
      whereClause += ' AND month >= ? AND month <= ?';
      whereArgs.addAll([monthStart.toIso8601String(), monthEnd.toIso8601String()]);
    }

    final result = await db.query(
      'budgets',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'month DESC',
      // CRITICAL FIX: Add limit to prevent unbounded memory growth
      // Default to 100 if no limit specified (covers ~8 years of monthly budgets)
      limit: limit ?? 100,
    );
    return result.map((map) => Budget.fromMap(map)).toList();
  }

  // FIX #7: Get budgets for specific month only
  Future<List<Budget>> getBudgetsForMonth(int accountId, int year, int month) async {
    final db = await database;
    final monthStr = DateTime(year, month, 1).toIso8601String().substring(0, 7); // "2024-01"

    final result = await db.query(
      'budgets',
      where: 'account_id = ? AND month LIKE ?',
      whereArgs: [accountId, '$monthStr%'],
    );
    return result.map((map) => Budget.fromMap(map)).toList();
  }

  Future<int> updateBudget(Budget budget) async {
    final db = await database;
    return await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteBudget(int id) async {
    final db = await database;
    return await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============== MONTHLY BALANCE METHODS ==============

  /// Get the monthly balance for a specific month
  Future<MonthlyBalance?> getMonthlyBalance(int accountId, DateTime month) async {
    final db = await database;
    final monthStr = DateTime(month.year, month.month, 1).toIso8601String().substring(0, 7);

    final result = await db.query(
      'monthly_balances',
      where: 'account_id = ? AND month LIKE ?',
      whereArgs: [accountId, '$monthStr%'],
    );

    if (result.isEmpty) return null;
    return MonthlyBalance.fromMap(result.first);
  }

  /// Create or update a monthly balance record
  Future<int> upsertMonthlyBalance(MonthlyBalance balance) async {
    final db = await database;

    // Check if record exists
    final existing = await getMonthlyBalance(balance.accountId, balance.month);

    if (existing != null) {
      // Update existing record
      return await db.update(
        'monthly_balances',
        balance.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      // Insert new record
      return await db.insert('monthly_balances', balance.toMap()..remove('id'));
    }
  }

  /// Get all monthly balances for an account (for analytics/history)
  Future<List<MonthlyBalance>> getMonthlyBalances(int accountId, {int? limit}) async {
    final db = await database;

    final result = await db.query(
      'monthly_balances',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'month DESC',
      limit: limit,
    );

    return result.map((map) => MonthlyBalance.fromMap(map)).toList();
  }

  /// Delete a monthly balance record
  Future<int> deleteMonthlyBalance(int id) async {
    final db = await database;
    return await db.delete(
      'monthly_balances',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Calculate the balance for a specific month (income - expenses)
  /// This is used to compute the carryover for the next month
  Future<double> calculateMonthBalance(int accountId, int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    // Sum income for the month
    final incomeResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM income WHERE account_id = ? AND date >= ? AND date <= ?',
      [accountId, startDate, endDate],
    );
    final totalIncome = (incomeResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // Sum expenses for the month
    final expenseResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE account_id = ? AND date >= ? AND date <= ?',
      [accountId, startDate, endDate],
    );
    final totalExpenses = (expenseResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return totalIncome - totalExpenses;
  }

  // ============== RECURRING EXPENSE METHODS ==============

  Future<int> createRecurringExpense(RecurringExpense expense) async {
    final db = await database;
    return await db.insert('recurring_expenses', expense.toMap());
  }

  Future<List<RecurringExpense>> readAllRecurringExpenses(int accountId) async {
    final db = await database;
    final result = await db.query(
      'recurring_expenses',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    return result.map((map) => RecurringExpense.fromMap(map)).toList();
  }

  /// FIX: Optimized method to read only active recurring expenses
  /// This prevents iterating over inactive transactions during daily processing
  Future<List<RecurringExpense>> readActiveRecurringExpenses(int accountId) async {
    final db = await database;
    final result = await db.query(
      'recurring_expenses',
      where: 'account_id = ? AND isActive = 1',
      whereArgs: [accountId],
    );
    return result.map((map) => RecurringExpense.fromMap(map)).toList();
  }

  Future<int> updateRecurringExpense(RecurringExpense expense) async {
    final db = await database;
    return await db.update(
      'recurring_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteRecurringExpense(int id) async {
    final db = await database;
    return await db.delete(
      'recurring_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============== CATEGORY METHODS ==============

  Future<int> createCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> readAllCategories(int accountId, {String? type}) async {
    final db = await database;
    final result = type == null
        ? await db.query('categories', where: 'account_id = ?', whereArgs: [accountId])
        : await db.query('categories', where: 'account_id = ? AND type = ?', whereArgs: [accountId, type]);
    return result.map((map) => Category.fromMap(map)).toList();
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  // FIX #2: Cascade category rename across all dependent tables
  Future<void> renameCategoryInAllTables(int accountId, String oldName, String newName, String type) async {
    final db = await database;

    // Use a transaction for atomicity
    await db.transaction((txn) async {
      if (type == 'expense') {
        // Update expenses
        await txn.rawUpdate(
          'UPDATE expenses SET category = ? WHERE account_id = ? AND category = ?',
          [newName, accountId, oldName],
        );

        // Update recurring expenses
        await txn.rawUpdate(
          'UPDATE recurring_expenses SET category = ? WHERE account_id = ? AND category = ?',
          [newName, accountId, oldName],
        );

        // Update quick templates
        await txn.rawUpdate(
          'UPDATE quick_templates SET category = ? WHERE account_id = ? AND category = ?',
          [newName, accountId, oldName],
        );

        // Update budgets
        await txn.rawUpdate(
          'UPDATE budgets SET category = ? WHERE account_id = ? AND category = ?',
          [newName, accountId, oldName],
        );

        // Update deleted expenses
        await txn.rawUpdate(
          'UPDATE deleted_expenses SET category = ? WHERE account_id = ? AND category = ?',
          [newName, accountId, oldName],
        );
      } else if (type == 'income') {
        // Update income
        await txn.rawUpdate(
          'UPDATE income SET category = ? WHERE account_id = ? AND category = ?',
          [newName, accountId, oldName],
        );

        // Update deleted income
        await txn.rawUpdate(
          'UPDATE deleted_income SET category = ? WHERE account_id = ? AND category = ?',
          [newName, accountId, oldName],
        );
      }
    });
  }

  /// Bulk reassign all transactions from one category to another
  /// This is much faster than updating one-by-one in a loop
  Future<void> bulkReassignCategory(int accountId, String oldCategory, String newCategory, String type) async {
    final db = await database;

    // Use a transaction for atomicity - either all succeed or all fail
    await db.transaction((txn) async {
      if (type == 'expense') {
        // Update all expenses in one SQL statement
        await txn.rawUpdate(
          'UPDATE expenses SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );

        // Update recurring expenses
        await txn.rawUpdate(
          'UPDATE recurring_expenses SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );

        // Update quick templates
        await txn.rawUpdate(
          'UPDATE quick_templates SET category = ? WHERE account_id = ? AND category = ? AND type = ?',
          [newCategory, accountId, oldCategory, 'expense'],
        );

        // Update budgets
        await txn.rawUpdate(
          'UPDATE budgets SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );

        // Update deleted expenses
        await txn.rawUpdate(
          'UPDATE deleted_expenses SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );
      } else if (type == 'income') {
        // Update all income in one SQL statement
        await txn.rawUpdate(
          'UPDATE income SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );

        // Update recurring income
        await txn.rawUpdate(
          'UPDATE recurring_income SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );

        // Update quick templates
        await txn.rawUpdate(
          'UPDATE quick_templates SET category = ? WHERE account_id = ? AND category = ? AND type = ?',
          [newCategory, accountId, oldCategory, 'income'],
        );

        // Update deleted income
        await txn.rawUpdate(
          'UPDATE deleted_income SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );
      }
    });
  }

  /// FIX #3: Atomically reassign transactions AND delete category to prevent data loss
  Future<void> bulkReassignCategoryAndDelete(int accountId, int categoryId, String oldCategory, String newCategory, String type) async {
    final db = await database;

    // Use a transaction for atomicity - either all succeed or all fail
    await db.transaction((txn) async {
      if (type == 'expense') {
        await txn.rawUpdate(
          'UPDATE expenses SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );
        await txn.rawUpdate(
          'UPDATE recurring_expenses SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );
        await txn.rawUpdate(
          'UPDATE quick_templates SET category = ? WHERE account_id = ? AND category = ? AND type = ?',
          [newCategory, accountId, oldCategory, 'expense'],
        );
        await txn.rawUpdate(
          'UPDATE budgets SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );
        await txn.rawUpdate(
          'UPDATE deleted_expenses SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );
      } else if (type == 'income') {
        await txn.rawUpdate(
          'UPDATE income SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );
        await txn.rawUpdate(
          'UPDATE recurring_income SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );
        await txn.rawUpdate(
          'UPDATE quick_templates SET category = ? WHERE account_id = ? AND category = ? AND type = ?',
          [newCategory, accountId, oldCategory, 'income'],
        );
        await txn.rawUpdate(
          'UPDATE deleted_income SET category = ? WHERE account_id = ? AND category = ?',
          [newCategory, accountId, oldCategory],
        );
      }
      // FIX #3: Delete category atomically in same transaction
      await txn.delete(
        'categories',
        where: 'id = ? AND isDefault = 0',
        whereArgs: [categoryId],
      );
    });
  }

  /// FIX #3: Atomically delete transactions AND category to prevent orphaned data
  Future<void> bulkDeleteTransactionsAndCategory(int accountId, int categoryId, String category, String type) async {
    final db = await database;

    await db.transaction((txn) async {
      if (type == 'expense') {
        final expenses = await txn.query(
          'expenses',
          where: 'account_id = ? AND category = ?',
          whereArgs: [accountId, category],
        );

        final now = DateTime.now().toUtc().toIso8601String();
        for (final expense in expenses) {
          await txn.insert('deleted_expenses', {
            'original_id': expense['id'],
            'amount': expense['amount'],
            'category': expense['category'],
            'description': expense['description'],
            'date': expense['date'],
            'account_id': expense['account_id'],
            'amountPaid': expense['amountPaid'],
            'paymentMethod': expense['paymentMethod'],
            'deletedAt': now,
          });
        }

        await txn.delete(
          'expenses',
          where: 'account_id = ? AND category = ?',
          whereArgs: [accountId, category],
        );
      } else if (type == 'income') {
        final incomes = await txn.query(
          'income',
          where: 'account_id = ? AND category = ?',
          whereArgs: [accountId, category],
        );

        final now = DateTime.now().toUtc().toIso8601String();
        for (final income in incomes) {
          await txn.insert('deleted_income', {
            'original_id': income['id'],
            'amount': income['amount'],
            'category': income['category'],
            'description': income['description'],
            'date': income['date'],
            'account_id': income['account_id'],
            'deletedAt': now,
          });
        }

        await txn.delete(
          'income',
          where: 'account_id = ? AND category = ?',
          whereArgs: [accountId, category],
        );
      }
      // FIX #3: Delete category atomically in same transaction
      await txn.delete(
        'categories',
        where: 'id = ? AND isDefault = 0',
        whereArgs: [categoryId],
      );
    });
  }

  /// Bulk delete all transactions in a specific category
  /// This is much faster than deleting one-by-one in a loop
  Future<void> bulkDeleteTransactionsByCategory(int accountId, String category, String type) async {
    final db = await database;

    // Use a transaction for atomicity
    await db.transaction((txn) async {
      if (type == 'expense') {
        // Move all expenses to deleted table first
        final expenses = await txn.query(
          'expenses',
          where: 'account_id = ? AND category = ?',
          whereArgs: [accountId, category],
        );

        // FIX: Use UTC to avoid timezone-dependent expiration
        final now = DateTime.now().toUtc().toIso8601String();
        for (final expense in expenses) {
          await txn.insert('deleted_expenses', {
            'original_id': expense['id'],
            'amount': expense['amount'],
            'category': expense['category'],
            'description': expense['description'],
            'date': expense['date'],
            'account_id': expense['account_id'],
            'amountPaid': expense['amountPaid'],
            'paymentMethod': expense['paymentMethod'],
            'deletedAt': now,
          });
        }

        // Then delete all expenses in one SQL statement
        await txn.delete(
          'expenses',
          where: 'account_id = ? AND category = ?',
          whereArgs: [accountId, category],
        );
      } else if (type == 'income') {
        // Move all income to deleted table first
        final incomes = await txn.query(
          'income',
          where: 'account_id = ? AND category = ?',
          whereArgs: [accountId, category],
        );

        // FIX: Use UTC to avoid timezone-dependent expiration
        final now = DateTime.now().toUtc().toIso8601String();
        for (final income in incomes) {
          await txn.insert('deleted_income', {
            'original_id': income['id'],
            'amount': income['amount'],
            'category': income['category'],
            'description': income['description'],
            'date': income['date'],
            'account_id': income['account_id'],
            'deletedAt': now,
          });
        }

        // Then delete all income in one SQL statement
        await txn.delete(
          'income',
          where: 'account_id = ? AND category = ?',
          whereArgs: [accountId, category],
        );
      }
    });
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete(
      'categories',
      where: 'id = ? AND isDefault = 0',
      whereArgs: [id],
    );
  }

  // ============== LAZY LOADING METHODS (FIX #3) ==============

  /// Count expenses by category (for category deletion check)
  Future<int> countExpensesByCategory(int accountId, String category) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM expenses WHERE account_id = ? AND category = ?',
      [accountId, category],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Count incomes by category (for category deletion check)
  Future<int> countIncomesByCategory(int accountId, String category) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM income WHERE account_id = ? AND category = ?',
      [accountId, category],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get expenses for a specific date range (for lazy loading)
  Future<List<Expense>> getExpensesInRange(int accountId, DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.query(
      'expenses',
      where: 'account_id = ? AND date >= ? AND date <= ?',
      whereArgs: [accountId, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return result.map((map) => Expense.fromMap(map)).toList();
  }

  /// Get income for a specific date range (for lazy loading)
  Future<List<Income>> getIncomeInRange(int accountId, DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.query(
      'income',
      where: 'account_id = ? AND date >= ? AND date <= ?',
      whereArgs: [accountId, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return result.map((map) => Income.fromMap(map)).toList();
  }

  /// Get expense count for performance monitoring
  Future<int> getExpenseCount(int accountId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM expenses WHERE account_id = ?',
      [accountId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // FIX #5: Atomic batch creation of recurring expenses
  /// Creates multiple expenses and updates recurring expense in a single transaction
  /// This ensures either all operations succeed or none do (atomicity)
  Future<void> createRecurringExpensesBatch({
    required List<Expense> expenses,
    required RecurringExpense recurringToUpdate,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      // Create all expenses
      for (final expense in expenses) {
        await txn.insert('expenses', expense.toMap());
      }

      // Update the recurring expense's lastCreated timestamp
      await txn.update(
        'recurring_expenses',
        recurringToUpdate.toMap(),
        where: 'id = ?',
        whereArgs: [recurringToUpdate.id],
      );
    });
  }

  // ============== DATABASE MAINTENANCE ==============

  /// CRITICAL FIX: Run database vacuum to reclaim space and optimize performance
  /// Should be called periodically (e.g., on app startup every 30 days)
  /// WARNING: This can take several seconds for large databases
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  /// CRITICAL FIX: Run ANALYZE to update query planner statistics
  /// Helps SQLite choose optimal query execution plans
  Future<void> analyze() async {
    final db = await database;
    await db.execute('ANALYZE');
  }

  /// CRITICAL FIX: Get database size in bytes
  Future<int> getDatabaseSize() async {
    final dbPath = await getDatabasePath();
    final file = File(dbPath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// CRITICAL FIX: Check if database needs maintenance (vacuum if > 20% bloat)
  Future<bool> needsMaintenance() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA page_count');
    final pageCount = Sqflite.firstIntValue(result) ?? 0;

    final freeResult = await db.rawQuery('PRAGMA freelist_count');
    final freePages = Sqflite.firstIntValue(freeResult) ?? 0;

    // If more than 20% of pages are free, vacuum is recommended
    if (pageCount > 0) {
      final bloatPercent = (freePages / pageCount) * 100;
      return bloatPercent > 20;
    }
    return false;
  }

  /// CRITICAL FIX: Run periodic database maintenance
  /// Call this on app startup (with rate limiting to avoid running too frequently)
  Future<void> performMaintenance({bool force = false}) async {
    if (force || await needsMaintenance()) {
      if (kDebugMode) debugPrint('Running database maintenance (vacuum + analyze)...');
      await vacuum();
      await analyze();
      if (kDebugMode) debugPrint('Database maintenance complete');
    }

    // FIX: Clean up orphaned backup files periodically
    try {
      final cleaned = await cleanOrphanedBackupFiles();
      if (kDebugMode && cleaned > 0) {
        debugPrint('Cleaned $cleaned orphaned backup files');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error during orphaned file cleanup: $e');
    }
  }

  // ============== BACKUP & RESTORE ==============

  Future<String> getDatabasePath() async {
    final databasePath = await getDatabasesPath();
    return path.join(databasePath, 'expense_tracker_v4.db');
  }

  // FIX #9: Close and reopen database after restore
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // ============== RECURRING INCOME METHODS ==============

  Future<int> createRecurringIncome(RecurringIncome income) async {
    final db = await database;
    return await db.insert('recurring_income', income.toMap());
  }

  Future<List<RecurringIncome>> readAllRecurringIncome(int accountId) async {
    final db = await database;
    final result = await db.query(
      'recurring_income',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    return result.map((map) => RecurringIncome.fromMap(map)).toList();
  }

  /// FIX: Optimized method to read only active recurring income
  /// This prevents iterating over inactive transactions during daily processing
  Future<List<RecurringIncome>> readActiveRecurringIncome(int accountId) async {
    final db = await database;
    final result = await db.query(
      'recurring_income',
      where: 'account_id = ? AND isActive = 1',
      whereArgs: [accountId],
    );
    return result.map((map) => RecurringIncome.fromMap(map)).toList();
  }

  Future<int> updateRecurringIncome(RecurringIncome income) async {
    final db = await database;
    return await db.update(
      'recurring_income',
      income.toMap(),
      where: 'id = ?',
      whereArgs: [income.id],
    );
  }

  Future<int> deleteRecurringIncome(int id) async {
    final db = await database;
    return await db.delete(
      'recurring_income',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Atomic batch creation of recurring income
  Future<void> createRecurringIncomeBatch({
    required List<Income> incomes,
    required RecurringIncome recurringToUpdate,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      for (final income in incomes) {
        await txn.insert('income', income.toMap());
      }

      await txn.update(
        'recurring_income',
        recurringToUpdate.toMap(),
        where: 'id = ?',
        whereArgs: [recurringToUpdate.id],
      );
    });
  }

  // ============== TAG METHODS ==============

  Future<int> createTag(String name, int accountId, {String? color}) async {
    final db = await database;
    return await db.insert('tags', {
      'name': name,
      'color': color,
      'account_id': accountId,
    });
  }

  Future<List<Map<String, dynamic>>> readAllTags(int accountId) async {
    final db = await database;
    return await db.query(
      'tags',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'name ASC',
    );
  }

  Future<int> updateTag(int id, String name, {String? color}) async {
    final db = await database;
    return await db.update(
      'tags',
      {'name': name, 'color': color},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTag(int id) async {
    final db = await database;
    // Delete tag and all its associations (cascade handled by FK)
    return await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addTagToTransaction(int transactionId, String transactionType, int tagId) async {
    final db = await database;
    await db.insert('transaction_tags', {
      'transaction_id': transactionId,
      'transaction_type': transactionType,
      'tag_id': tagId,
    });
  }

  Future<void> removeTagFromTransaction(int transactionId, String transactionType, int tagId) async {
    final db = await database;
    await db.delete(
      'transaction_tags',
      where: 'transaction_id = ? AND transaction_type = ? AND tag_id = ?',
      whereArgs: [transactionId, transactionType, tagId],
    );
  }

  Future<List<Map<String, dynamic>>> getTagsForTransaction(int transactionId, String transactionType) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.* FROM tags t
      INNER JOIN transaction_tags tt ON t.id = tt.tag_id
      WHERE tt.transaction_id = ? AND tt.transaction_type = ?
    ''', [transactionId, transactionType]);
  }

  Future<List<int>> getTransactionIdsForTag(int tagId, String transactionType) async {
    final db = await database;
    final result = await db.query(
      'transaction_tags',
      columns: ['transaction_id'],
      where: 'tag_id = ? AND transaction_type = ?',
      whereArgs: [tagId, transactionType],
    );
    return result.map((r) => r['transaction_id'] as int).toList();
  }

  // ============== SEARCH METHODS ==============

  Future<List<Expense>> searchExpenses(int accountId, String query, {int? limit, int offset = 0}) async {
    final db = await database;

    // FIX: Sanitize search query to prevent LIKE performance issues
    final sanitizedQuery = _sanitizeSearchQuery(query);
    if (sanitizedQuery.isEmpty) return [];

    final result = await _queryWithTimeout(() => db.query(
      'expenses',
      where: 'account_id = ? AND (description LIKE ? OR category LIKE ?)',
      whereArgs: [accountId, '%$sanitizedQuery%', '%$sanitizedQuery%'],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    ));

    if (result == null) return []; // Timeout occurred
    return result.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Income>> searchIncome(int accountId, String query, {int? limit, int offset = 0}) async {
    final db = await database;

    // FIX: Sanitize search query to prevent LIKE performance issues
    final sanitizedQuery = _sanitizeSearchQuery(query);
    if (sanitizedQuery.isEmpty) return [];

    final result = await _queryWithTimeout(() => db.query(
      'income',
      where: 'account_id = ? AND (description LIKE ? OR category LIKE ?)',
      whereArgs: [accountId, '%$sanitizedQuery%', '%$sanitizedQuery%'],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    ));

    if (result == null) return []; // Timeout occurred
    return result.map((map) => Income.fromMap(map)).toList();
  }

  /// FIX: Sanitize search query to prevent LIKE performance issues and injection
  /// Removes/escapes special SQL LIKE characters that could cause problems
  String _sanitizeSearchQuery(String query) {
    if (query.isEmpty) return '';

    // Remove excessive special characters that cause LIKE performance issues
    // Limit consecutive wildcards to prevent pathological cases
    String sanitized = query.trim();

    // Escape SQL LIKE wildcards if user wants literal search
    // Replace user-intended wildcards with placeholders temporarily
    sanitized = sanitized.replaceAll('%', '\\%');
    sanitized = sanitized.replaceAll('_', '\\_');

    // Limit query length to prevent excessive processing
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }

    return sanitized;
  }

  /// Parse search query into tokens, respecting quoted strings
  /// Examples:
  /// - "Coffee 50" -> ["Coffee", "50"]
  /// - '"Coffee Shop" 20' -> ["Coffee Shop", "20"]
  /// - 'Grocery "Food Market"' -> ["Grocery", "Food Market"]
  List<String> _parseSearchTokens(String query) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    bool escaped = false;

    for (var i = 0; i < query.length; i++) {
      final char = query[i];

      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }

      if (char == '\\') {
        escaped = true;
        continue;
      }

      if (char == '"' || char == "'") {
        inQuotes = !inQuotes;
        continue;
      }

      if (char == ' ' && !inQuotes) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }

      buffer.write(char);
    }

    // Add remaining buffer
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens.where((t) => t.isNotEmpty).toList();
  }

  /// FIX: Unified search that merges expenses and income chronologically
  /// This prevents timeline fragmentation when paginating
  Future<Map<String, dynamic>> searchTransactionsUnified(
    int accountId,
    String query, {
    int limit = 50,
    int offset = 0,
    String? category, // FIX: Add category filter parameter
    String? startDate, // FIX: Add date range parameters
    String? endDate,
    String sortOrder = 'newest', // Sort order: newest, oldest, highest, lowest, category
  }) async {
    final db = await database;

    // FIX: Sanitize search query
    final sanitizedQuery = _sanitizeSearchQuery(query.trim());

    // CRITICAL FIX: Multi-token search with quoted string support
    // Allows: "Food 50" -> ["Food", "50"] (two tokens)
    // Allows: '"Coffee Shop" 20' -> ["Coffee Shop", "20"] (quoted phrase kept together)
    final tokens = _parseSearchTokens(sanitizedQuery);

    if (tokens.isEmpty) {
      return {'expenses': <Expense>[], 'income': <Income>[], 'hasMore': false};
    }

    // Build WHERE clause for each token - all must match
    String buildTokenConditions(String prefix) {
      final conditions = <String>[];

      // Search token conditions
      for (final token in tokens) {
        final isNumeric = double.tryParse(token) != null;
        if (isNumeric) {
          conditions.add('($prefix.description LIKE ? OR $prefix.category LIKE ? OR CAST($prefix.amount AS TEXT) LIKE ?)');
        } else {
          conditions.add('($prefix.description LIKE ? OR $prefix.category LIKE ?)');
        }
      }

      // FIX: Add category filter if specified
      if (category != null && category != 'All') {
        conditions.add('$prefix.category = ?');
      }

      // FIX: Add date range filter if specified
      if (startDate != null) {
        conditions.add('$prefix.date >= ?');
      }
      if (endDate != null) {
        conditions.add('$prefix.date <= ?');
      }

      return conditions.join(' AND ');
    }

    final expenseConditions = buildTokenConditions('expenses');
    final incomeConditions = buildTokenConditions('income');

    // Determine ORDER BY clause based on sort order
    // Use ID as secondary sort to ensure consistent ordering for items with same date/amount
    String orderByClause;
    switch (sortOrder) {
      case 'oldest':
        orderByClause = 'ORDER BY date ASC, id ASC';
        break;
      case 'highest':
        orderByClause = 'ORDER BY amount DESC, date DESC, id DESC';
        break;
      case 'lowest':
        orderByClause = 'ORDER BY amount ASC, date DESC, id DESC';
        break;
      case 'category':
        orderByClause = 'ORDER BY category ASC, date DESC, id DESC';
        break;
      case 'newest':
      default:
        orderByClause = 'ORDER BY date DESC, id DESC';
        break;
    }

    // Use UNION ALL to combine expenses and income into a single query
    final sql = '''
      SELECT
        id, amount, category, description, date, 'expense' as type, amountPaid, paymentMethod
      FROM expenses
      WHERE account_id = ? AND ($expenseConditions)

      UNION ALL

      SELECT
        id, amount, category, description, date, 'income' as type, NULL as amountPaid, NULL as paymentMethod
      FROM income
      WHERE account_id = ? AND ($incomeConditions)

      $orderByClause
      LIMIT ? OFFSET ?
    ''';

    // Build args list for each token and filter
    final args = <dynamic>[];

    // Args for expenses
    args.add(accountId);
    for (final token in tokens) {
      final pattern = '%$token%';
      final isNumeric = double.tryParse(token) != null;
      if (isNumeric) {
        args.addAll([pattern, pattern, pattern]); // description, category, amount
      } else {
        args.addAll([pattern, pattern]); // description, category
      }
    }
    // FIX: Add category and date range args for expenses
    if (category != null && category != 'All') {
      args.add(category);
    }
    if (startDate != null) {
      args.add(startDate);
    }
    if (endDate != null) {
      args.add(endDate);
    }

    // Args for income
    args.add(accountId);
    for (final token in tokens) {
      final pattern = '%$token%';
      final isNumeric = double.tryParse(token) != null;
      if (isNumeric) {
        args.addAll([pattern, pattern, pattern]);
      } else {
        args.addAll([pattern, pattern]);
      }
    }
    // FIX: Add category and date range args for income
    if (category != null && category != 'All') {
      args.add(category);
    }
    if (startDate != null) {
      args.add(startDate);
    }
    if (endDate != null) {
      args.add(endDate);
    }

    args.addAll([limit, offset]);

    // FIX: Add timeout to prevent UI freeze on large datasets
    final result = await _queryWithTimeout(() => db.rawQuery(sql, args));

    if (result == null) {
      // Timeout occurred - return empty results
      return {'expenses': <Expense>[], 'income': <Income>[], 'hasMore': false};
    }

    // Separate the results back into expenses and income
    final expenses = <Expense>[];
    final income = <Income>[];

    for (final row in result) {
      if (row['type'] == 'expense') {
        expenses.add(Expense.fromMap(row));
      } else {
        income.add(Income.fromMap(row));
      }
    }

    return {
      'expenses': expenses,
      'income': income,
      'hasMore': result.length >= limit,
    };
  }
}