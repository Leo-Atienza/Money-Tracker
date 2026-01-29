import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import '../database/database_helper.dart';
import '../models/expense_model.dart';
import '../models/income_model.dart';
import '../models/budget_model.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/quick_template_model.dart';
import '../models/recurring_expense_model.dart';
import '../models/recurring_income_model.dart';
import '../models/tag_model.dart';
import '../models/monthly_balance_model.dart';
import '../utils/settings_helper.dart';
import '../utils/currency_helper.dart';
import '../utils/notification_helper.dart';
import '../utils/async_mutex.dart';
import '../utils/decimal_helper.dart';
import '../utils/date_helper.dart';
import '../services/onboarding_service.dart';
import '../utils/pin_security_helper.dart';
import '../utils/home_widget_helper.dart';
import 'dart:async';

class AppState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final NotificationHelper _notificationHelper = NotificationHelper();
  final OnboardingService _onboardingService = OnboardingService();

  final AsyncMutex _writeMutex = AsyncMutex();

  // ============== DATA LISTS ==============
  List<Expense> _expenses = [];
  List<Income> _incomes = [];
  List<Budget> _budgets = [];
  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<QuickTemplate> _quickTemplates = [];
  List<RecurringExpense> _recurringExpenses = [];
  List<RecurringIncome> _recurringIncomes = [];
  List<Map<String, dynamic>> _tags = [];
  Map<String, MonthlyBalance> _monthlyBalances = {}; // Key: "year-month"

  // ============== CURRENT STATE ==============
  Account? _currentAccount;
  DateTime _selectedMonth = DateHelper.startOfMonth(DateTime.now());
  bool _isOnboardingComplete = false;
  bool _isInitialized = false;
  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get isInitialized => _isInitialized;

  int _lastAutoCreatedCount = 0;
  int get lastAutoCreatedCount => _lastAutoCreatedCount;
  void clearAutoCreatedCount() => _lastAutoCreatedCount = 0;

  bool _categoryRenameInProgress = false;

  // ============== SETTINGS ==============
  bool _isDarkMode = false;
  String _themeMode = 'system';
  String _currencyCode = 'USD';
  bool _billRemindersEnabled = true;
  bool _budgetAlertsEnabled = true;
  bool _monthlySummaryEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _showTransactionColors = false; // Optional transparent background colors on transaction cards
  double _transactionColorIntensity = 0.5; // 0.0 - 1.0, how visible the background color is

  // ============== PIN LOCK STATE ==============
  bool _isLocked = true; // App starts locked if PIN is enabled
  Timer? _lockTimer;
  static const Duration _lockTimeout = Duration(minutes: 3);
  bool _isDisposed = false; // FIX: Track disposed state to prevent timer callback crashes

  // ============== FILTERS ==============
  String _filterCategory = 'All';
  DateTimeRange? _dateRange;
  double? _minAmount;
  double? _maxAmount;
  bool? _paidStatusFilter;

  // ============== GETTERS ==============
  // FIX: Cache filtered expenses to avoid recalculating on every access
  List<Expense>? _cachedFilteredExpenses;
  DateTime? _cacheMonth;
  String? _cacheCategory;
  DateTimeRange? _cacheDateRange;
  double? _cacheMinAmount;
  double? _cacheMaxAmount;
  bool? _cachePaidStatus;
  int? _cacheExpenseCount;
  int? _cacheExpenseHash; // FIX: Track content changes, not just length

  List<Expense> get expenses {
    // FIX: Calculate a comprehensive hash of expense fields to detect any content changes
    // Includes: id, amount, description, category, amountPaid, and date
    // This catches all cases where an expense is updated
    final currentHash = _expenses.isEmpty ? 0 : _expenses.fold(0, (hash, e) {
      return hash ^
          (e.id ?? 0) ^
          e.amountDecimal.hashCode ^
          e.description.hashCode ^
          e.category.hashCode ^
          e.amountPaidDecimal.hashCode ^
          e.date.millisecondsSinceEpoch;
    });

    // Check if cache is valid
    final cacheValid = _cachedFilteredExpenses != null &&
        _cacheMonth == _selectedMonth &&
        _cacheCategory == _filterCategory &&
        _cacheDateRange == _dateRange &&
        _cacheMinAmount == _minAmount &&
        _cacheMaxAmount == _maxAmount &&
        _cachePaidStatus == _paidStatusFilter &&
        _cacheExpenseCount == _expenses.length &&
        _cacheExpenseHash == currentHash;

    if (!cacheValid) {
      _cachedFilteredExpenses = _getFilteredExpenses();
      _cacheMonth = _selectedMonth;
      _cacheCategory = _filterCategory;
      _cacheDateRange = _dateRange;
      _cacheMinAmount = _minAmount;
      _cacheMaxAmount = _maxAmount;
      _cachePaidStatus = _paidStatusFilter;
      _cacheExpenseCount = _expenses.length;
      _cacheExpenseHash = currentHash;
    }
    return _cachedFilteredExpenses!;
  }

  /// Invalidate the filtered expenses cache
  void _invalidateExpenseCache() {
    _cachedFilteredExpenses = null;
  }

  List<Expense> get allExpenses => _expenses;
  List<Income> get incomes => _incomes;
  List<Budget> get budgets => _budgets;
  List<Account> get accounts => _accounts;
  List<Category> get categories => _categories;
  List<QuickTemplate> get quickTemplates => _quickTemplates;
  List<RecurringExpense> get recurringExpenses => _recurringExpenses;
  List<RecurringIncome> get recurringIncomes => _recurringIncomes;
  List<Map<String, dynamic>> get tags => _tags;
  /// FIX P2-12: Expose monthly balances for complete backup export
  Map<String, MonthlyBalance> get monthlyBalances => _monthlyBalances;

  List<Category> get expenseCategories =>
      _categories.where((c) => c.type == 'expense').toList();
  List<Category> get incomeCategories =>
      _categories.where((c) => c.type == 'income').toList();
  List<String> get categoryNames =>
      expenseCategories.map((c) => c.name).toList();

  Account? get currentAccount => _currentAccount;
  int get currentAccountId => _currentAccount?.id ?? 1;

  DateTime get selectedMonth => _selectedMonth;
  String get selectedMonthName {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  bool get isDarkMode => _isDarkMode;
  String get themeMode => _themeMode;
  String get currencyCode => _currencyCode;
  String get currency => CurrencyHelper.getSymbol(_currencyCode);
  bool get billRemindersEnabled => _billRemindersEnabled;
  bool get budgetAlertsEnabled => _budgetAlertsEnabled;
  bool get monthlySummaryEnabled => _monthlySummaryEnabled;
  TimeOfDay get reminderTime => _reminderTime;
  bool get showTransactionColors => _showTransactionColors;
  double get transactionColorIntensity => _transactionColorIntensity;

  String formatAmount(double amount, {int decimalDigits = 2}) {
    return CurrencyHelper.formatAmount(amount, _currencyCode, decimalDigits: decimalDigits);
  }

  String formatWithCurrency(double amount, {int decimalDigits = 2}) {
    return CurrencyHelper.formatWithSymbol(amount, currency, _currencyCode, decimalDigits: decimalDigits);
  }

  String formatCompact(double amount) {
    return CurrencyHelper.formatCompact(amount, _currencyCode);
  }

  String get filterCategory => _filterCategory;
  DateTimeRange? get dateRange => _dateRange;

  List<Budget> get currentMonthBudgets => _budgets
      .where((b) => b.month.year == _selectedMonth.year && b.month.month == _selectedMonth.month)
      .toList();

  /// Get the total budget for the selected month (sum of all category budgets)
  double get totalCategoryBudget {
    final budgets = currentMonthBudgets;
    if (budgets.isEmpty) return 0.0;
    return _decimalToDouble(
      budgets.map((b) => b.amountDecimal).fold(Decimal.zero, (sum, amount) => sum + amount)
    );
  }

  /// Get the overall monthly budget if set, otherwise null
  double? get overallMonthlyBudget {
    final key = _monthKey(_selectedMonth);
    final balance = _monthlyBalances[key];
    return balance?.overallBudget;
  }

  /// Check if an overall monthly budget is set for the selected month
  bool get hasOverallMonthlyBudget {
    final key = _monthKey(_selectedMonth);
    final balance = _monthlyBalances[key];
    return balance?.hasOverallBudget ?? false;
  }

  /// Get the effective total budget for display
  /// Returns overall budget if set, otherwise returns sum of category budgets
  double get totalMonthlyBudget {
    if (hasOverallMonthlyBudget) {
      return overallMonthlyBudget!;
    }
    return totalCategoryBudget;
  }

  /// Get the carryover amount for the selected month (from previous month)
  double get carryoverForSelectedMonth {
    final key = _monthKey(_selectedMonth);
    final balance = _monthlyBalances[key];
    return balance?.carryoverFromPrevious ?? 0.0;
  }

  /// Get the carryover as Decimal for precise calculations
  Decimal get carryoverForSelectedMonthDecimal {
    final key = _monthKey(_selectedMonth);
    final balance = _monthlyBalances[key];
    return balance?.carryoverFromPreviousDecimal ?? Decimal.zero;
  }

  /// Get total available cash for the selected month
  /// This is: Income + Carryover from previous month - Expenses paid
  double get totalAvailableCash {
    return totalIncomeThisMonth + carryoverForSelectedMonth - totalPaid;
  }

  /// Get total available cash including carryover
  /// This is: Income + Carryover
  double get totalIncomeWithCarryover {
    return totalIncomeThisMonth + carryoverForSelectedMonth;
  }

  /// Get the projected end-of-month balance
  /// This is: Income + Carryover - Total Expenses
  double get projectedEndOfMonthBalance {
    return totalIncomeThisMonth + carryoverForSelectedMonth - totalExpensesThisMonth;
  }

  /// Check if there's a carryover for the selected month
  /// FIX: Use Decimal comparison to avoid floating point precision issues
  bool get hasCarryover => carryoverForSelectedMonthDecimal != Decimal.zero;

  double _decimalToDouble(Decimal value) {
    return DecimalHelper.toDouble(value);
  }

  // ============== INITIALIZATION ==============

  bool _processingRecurring = false;
  bool get isProcessingRecurring => _processingRecurring;
  int _backgroundProcessingEpoch = 0;

  Future<void> loadData() async {
    _backgroundProcessingEpoch++;
    _categoryRenameInProgress = false;

    _isOnboardingComplete = await _onboardingService.isOnboardingComplete();

    await _loadSettings();
    await _loadAccounts();

    await Future.wait([
      _loadCategories(),
      _loadExpenses(),
      _loadIncomes(),
      _loadBudgets(),
      _loadQuickTemplates(),
      _loadRecurringExpenses(),
      _loadRecurringIncomes(),
      _loadTags(),
      _loadMonthlyBalances(),
    ]);

    // FIX: Simplified null check - no need to check _currentAccount twice
    if (_categories.isEmpty && _currentAccount?.id != null) {
      await _createDefaultCategoriesForAccount(_currentAccount!.id!);
      await _loadCategories();
    }

    await _autoRolloverBudgets();
    await _calculateAndStoreCarryover();

    _isInitialized = true;
    notifyListeners();

    // Update home screen widget with latest data
    _updateHomeWidget();

    _processRecurringInBackground();
  }

  /// Update the home screen widget with current financial summary
  Future<void> _updateHomeWidget() async {
    try {
      await HomeWidgetHelper.updateWidget(this);
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating home widget: $e');
    }
  }

  Future<void> completeOnboarding() async {
    await _onboardingService.completeOnboarding();
    _isOnboardingComplete = true;
    notifyListeners();
  }

  Future<void> _processRecurringInBackground() async {
    // FIX: Prevent concurrent processing by checking flag at start
    if (_processingRecurring) {
      return;
    }

    final epochAtStart = _backgroundProcessingEpoch;
    final accountIdAtStart = currentAccountId;
    _processingRecurring = true;

    try {
      if (epochAtStart != _backgroundProcessingEpoch) {
        return;
      }
      await _processRecurringExpenses();

      if (epochAtStart != _backgroundProcessingEpoch) {
        return;
      }
      await _processRecurringIncomes();

      if (epochAtStart != _backgroundProcessingEpoch) {
        return;
      }
      await _db.clearOldDeleted();

      if (epochAtStart != _backgroundProcessingEpoch) {
        return;
      }
      await _db.performMaintenance();

      if (epochAtStart != _backgroundProcessingEpoch) {
        return;
      }
      await _initializeNotifications();
    } catch (e) {
      if (kDebugMode) debugPrint('Error processing recurring transactions in background: $e');
    } finally {
      _processingRecurring = false;
    }

    if (_lastAutoCreatedCount > 0 &&
        epochAtStart == _backgroundProcessingEpoch &&
        accountIdAtStart == currentAccountId) {
      notifyListeners();
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationHelper.initialize();
      final notificationsEnabled = await _notificationHelper.areNotificationsEnabled();
      if (!notificationsEnabled) {
        return;
      }

      if (_billRemindersEnabled) {
        await _scheduleAllBillReminders();
      }
      if (_monthlySummaryEnabled) {
        await _notificationHelper.scheduleMonthlyReports();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to initialize notifications: $e');
    }
  }

  Future<void> _scheduleAllBillReminders() async {
    for (final recurring in _recurringExpenses) {
      if (recurring.shouldBeActive && recurring.id != null) {
        await _notificationHelper.scheduleBillReminder(recurring);
      }
    }
  }

  Future<void> _loadSettings() async {
    _themeMode = await SettingsHelper.getThemeMode();
    _isDarkMode = _themeMode == 'dark';
    _billRemindersEnabled = await SettingsHelper.getBillReminders();
    _budgetAlertsEnabled = await SettingsHelper.getBudgetAlerts();
    _monthlySummaryEnabled = await SettingsHelper.getMonthlySummary();
    _showTransactionColors = await SettingsHelper.getShowTransactionColors();
    _transactionColorIntensity = await SettingsHelper.getTransactionColorIntensity();
    final hour = await SettingsHelper.getReminderHour();
    final minute = await SettingsHelper.getReminderMinute();
    _reminderTime = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _loadAccounts() async {
    _accounts = await _db.readAllAccounts();
    if (_accounts.isEmpty) {
      final currencyFromPrefs = await SettingsHelper.getCurrencyCode();
      await _db.createAccount(Account(name: 'Main Account', isDefault: true, currencyCode: currencyFromPrefs));
      _accounts = await _db.readAllAccounts();
    }
    if (_accounts.isNotEmpty) {
      _currentAccount = _accounts.firstWhere(
            (a) => a.isDefault,
        orElse: () => _accounts[0],
      );
    }
    _currencyCode = _currentAccount?.currencyCode ?? 'USD';
  }

  Future<void> _loadCategories() async {
    _categories = (await _db.readAllCategories(currentAccountId)).cast<Category>();
  }

  // FIX P3-15: Documented memory management constants
  /// Tracks which months have been loaded to enable lazy-loading
  final Set<String> _loadedExpenseMonths = {};
  final Set<String> _loadedIncomeMonths = {};
  /// Tracks last access time per month for LRU-style pruning
  final Map<String, DateTime> _monthAccessTimes = {};
  /// Maximum number of months to keep in memory to balance performance vs memory usage.
  /// 6 months allows viewing recent history while keeping memory footprint reasonable.
  /// Older months are pruned when this limit is exceeded.
  static const int _maxMonthsInMemory = 6;

  String _monthKey(DateTime date) => '${date.year}-${date.month}';

  Future<void> _loadExpensesInternal() async {
    final now = DateHelper.today();
    final currentMonthStart = DateHelper.startOfMonth(now);
    final prevMonthStart = DateHelper.startOfMonth(DateHelper.subtractMonths(now, 1));
    final currentMonthEnd = DateHelper.endOfMonth(now);

    final expenses = await _db.getExpensesInRange(currentAccountId, prevMonthStart, currentMonthEnd);

    _expenses = expenses;
    _loadedExpenseMonths.clear();
    _loadedExpenseMonths.add(_monthKey(currentMonthStart));
    _loadedExpenseMonths.add(_monthKey(prevMonthStart));
  }

  Future<void> _loadExpenses() async {
    return await _writeMutex.synchronized(() async {
      await _loadExpensesInternal();
    });
  }

  Future<void> _loadIncomesInternal() async {
    final now = DateHelper.today();
    final currentMonthStart = DateHelper.startOfMonth(now);
    final prevMonthStart = DateHelper.startOfMonth(DateHelper.subtractMonths(now, 1));
    final currentMonthEnd = DateHelper.endOfMonth(now);

    final incomes = await _db.getIncomeInRange(currentAccountId, prevMonthStart, currentMonthEnd);

    _incomes = incomes;
    _loadedIncomeMonths.clear();
    _loadedIncomeMonths.add(_monthKey(currentMonthStart));
    _loadedIncomeMonths.add(_monthKey(prevMonthStart));
  }

  Future<void> _loadIncomes() async {
    return await _writeMutex.synchronized(() async {
      await _loadIncomesInternal();
    });
  }

  Future<void> ensureMonthLoaded(DateTime month) async {
    final key = _monthKey(month);
    if (_loadedExpenseMonths.contains(key) && _loadedIncomeMonths.contains(key)) {
      _monthAccessTimes[key] = DateTime.now();
      return;
    }

    if (!_loadedExpenseMonths.contains(key)) {
      final monthStart = DateHelper.startOfMonth(month);
      final monthEnd = DateHelper.endOfMonth(month);
      final newExpenses = await _db.getExpensesInRange(currentAccountId, monthStart, monthEnd);
      final existingIds = _expenses.map((e) => e.id).toSet();
      for (final expense in newExpenses) {
        if (!existingIds.contains(expense.id)) {
          _expenses.add(expense);
        }
      }
      _loadedExpenseMonths.add(key);
      _monthAccessTimes[key] = DateTime.now();
    }

    if (!_loadedIncomeMonths.contains(key)) {
      final monthStart = DateHelper.startOfMonth(month);
      final monthEnd = DateHelper.endOfMonth(month);
      final newIncomes = await _db.getIncomeInRange(currentAccountId, monthStart, monthEnd);
      final existingIds = _incomes.map((i) => i.id).toSet();
      for (final income in newIncomes) {
        if (!existingIds.contains(income.id)) {
          _incomes.add(income);
        }
      }
      _loadedIncomeMonths.add(key);
      _monthAccessTimes[key] = DateTime.now();
    }

    _pruneDistantMonths(month);
  }

  void _pruneDistantMonths(DateTime currentMonth) {
    if (_loadedExpenseMonths.length <= _maxMonthsInMemory &&
        _loadedIncomeMonths.length <= _maxMonthsInMemory) {
      return;
    }
    final now = DateTime.now();
    int monthScore(String key) {
      final parts = key.split('-');
      if (parts.length < 2) {
        return 999999;
      }
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year == null || month == null) {
        return 999999;
      }
      final distance = ((currentMonth.year - year) * 12 + (currentMonth.month - month)).abs();
      final distanceScore = (distance * 10).clamp(0, 100);
      final lastAccess = _monthAccessTimes[key];
      final recencyScore = lastAccess != null ? (100 - now.difference(lastAccess).inMinutes).clamp(0, 100) : 0;
      return distanceScore - recencyScore;
    }

    if (_loadedExpenseMonths.length > _maxMonthsInMemory) {
      final sortedMonths = _loadedExpenseMonths.toList()..sort((a, b) => monthScore(a).compareTo(monthScore(b)));
      final monthsToRemove = sortedMonths.reversed.take(_loadedExpenseMonths.length - _maxMonthsInMemory).toSet();
      for (final monthKey in monthsToRemove) {
        final parts = monthKey.split('-');
        if (parts.length >= 2) {
          final year = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          if (year != null && month != null) {
            _expenses.removeWhere((e) => e.date.year == year && e.date.month == month);
          }
        }
        _loadedExpenseMonths.remove(monthKey);
        _monthAccessTimes.remove(monthKey);
      }
    }

    if (_loadedIncomeMonths.length > _maxMonthsInMemory) {
      final sortedMonths = _loadedIncomeMonths.toList()..sort((a, b) => monthScore(a).compareTo(monthScore(b)));
      final monthsToRemove = sortedMonths.reversed.take(_loadedIncomeMonths.length - _maxMonthsInMemory).toSet();
      for (final monthKey in monthsToRemove) {
        final parts = monthKey.split('-');
        if (parts.length >= 2) {
          final year = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          if (year != null && month != null) {
            _incomes.removeWhere((i) => i.date.year == year && i.date.month == month);
          }
        }
        _loadedIncomeMonths.remove(monthKey);
        _monthAccessTimes.remove(monthKey);
      }
    }
  }

  Future<void> _loadBudgets() async {
    _budgets = await _db.readAllBudgets(currentAccountId);
  }

  Future<void> _loadQuickTemplates() async {
    _quickTemplates = await _db.readAllTemplates(currentAccountId);
  }

  Future<void> _loadRecurringExpenses() async {
    _recurringExpenses = await _db.readAllRecurringExpenses(currentAccountId);
  }

  Future<void> _loadRecurringIncomes() async {
    _recurringIncomes = await _db.readAllRecurringIncome(currentAccountId);
  }

  Future<void> _loadTags() async {
    _tags = await _db.readAllTags(currentAccountId);
  }

  Future<void> _loadMonthlyBalances() async {
    final balances = await _db.getMonthlyBalances(currentAccountId, limit: 12);
    _monthlyBalances = {
      for (final b in balances) _monthKey(b.month): b
    };
  }

  // ============== EXPENSE METHODS ==============

  Future<int> addExpense(Expense expense) async {
    if (expense.amountDecimal <= Decimal.zero) {
      throw ArgumentError('Expense amount must be greater than zero');
    }
    if (expense.category.isEmpty) {
      throw ArgumentError('Expense must have a category');
    }
    if (expense.description.isEmpty) {
      throw ArgumentError('Expense must have a description');
    }

    return await _writeMutex.synchronized(() async {
      final expenseId = await _db.createExpense(expense);
      await _loadExpensesInternal();
      await _checkBudgetAlerts(expense.category);
      notifyListeners();
      _updateHomeWidget();
      return expenseId;
    });
  }

  Future<int> addExpenseRaw({
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required String paymentMethod,
    required double amountPaid,
  }) async {
    final expense = Expense(
      amount: DecimalHelper.fromDouble(amount),
      category: category,
      description: description,
      date: date,
      accountId: currentAccountId,
      amountPaid: DecimalHelper.fromDouble(amountPaid),
      paymentMethod: paymentMethod,
    );
    return await addExpense(expense);
  }

  Future<void> updateExpense(Expense expense) async {
    await _writeMutex.synchronized(() async {
      await _db.updateExpense(expense);
      await _loadExpensesInternal();
      _invalidateExpenseCache(); // FIX: Invalidate cache to ensure UI updates immediately
      notifyListeners();
      _updateHomeWidget(); // FIX: Update home widget after expense update
    });
  }

  Future<void> deleteExpense(int id) async {
    await _writeMutex.synchronized(() async {
      // FIX: Properly handle case when expense is not found in memory
      final expenseIndex = _expenses.indexWhere((e) => e.id == id);
      if (expenseIndex != -1) {
        // Expense found in memory - use it for deletion
        await _db.moveToDeleted(_expenses[expenseIndex]);
      } else {
        // Expense not in memory (e.g., from a different month) - delete by ID
        await _db.moveToDeletedById(id);
      }
      await _loadExpensesInternal();
      notifyListeners();
      _updateHomeWidget();
    });
  }

  Future<void> undoDelete() async {
    await _db.restoreLastDeleted(currentAccountId);
    await _loadExpenses();
    _invalidateExpenseCache(); // FIX: Invalidate cache after undo
    notifyListeners();
    _updateHomeWidget(); // FIX: Update home widget after undo
  }

  Future<void> addPayment(Expense expense, double amount) async {
    await _writeMutex.synchronized(() async {
      final paymentDecimal = DecimalHelper.fromDouble(amount);
      final newAmountPaidDecimal = expense.amountPaidDecimal + paymentDecimal;
      final remainingDecimal = expense.amountDecimal - newAmountPaidDecimal;
      final tenCents = Decimal.parse('0.10');
      final Decimal finalAmountPaid;
      if (newAmountPaidDecimal >= expense.amountDecimal) {
        // Cap at expense amount to prevent overpayment
        finalAmountPaid = expense.amountDecimal;
      } else if (remainingDecimal > Decimal.zero && remainingDecimal < tenCents) {
        // Auto-round up if less than 10 cents remaining
        finalAmountPaid = expense.amountDecimal;
      } else {
        finalAmountPaid = newAmountPaidDecimal;
      }
      final updated = expense.copyWithDecimal(amountPaid: finalAmountPaid);
      await _db.updateExpense(updated);
      await _loadExpensesInternal();
      _invalidateExpenseCache(); // FIX: Invalidate cache to ensure UI updates immediately
      notifyListeners();
      _updateHomeWidget(); // FIX: Update home widget after payment
    });
  }

  List<Expense> getExpensesForSelectedMonth() {
    return _expenses.where((e) => _isSameMonth(e.date, _selectedMonth)).toList();
  }

  List<Expense> _getFilteredExpenses() {
    var filtered = getExpensesForSelectedMonth();
    if (_filterCategory != 'All') {
      filtered = filtered.where((e) => e.category == _filterCategory).toList();
    }
    if (_dateRange != null) {
      filtered = filtered.where((e) {
        // FIX: Use consistent date range logic - include transactions on exact start/end dates
        final dateOnly = DateHelper.normalize(e.date);
        final startOnly = DateHelper.normalize(_dateRange!.start);
        final endOnly = DateHelper.normalize(_dateRange!.end);
        return !dateOnly.isBefore(startOnly) && !dateOnly.isAfter(endOnly);
      }).toList();
    }
    if (_minAmount != null) {
      filtered = filtered.where((e) => e.amount >= _minAmount!).toList();
    }
    if (_maxAmount != null) {
      filtered = filtered.where((e) => e.amount <= _maxAmount!).toList();
    }
    if (_paidStatusFilter != null) {
      filtered = filtered.where((e) => e.isPaid == _paidStatusFilter).toList();
    }
    // FIX: Ensure consistent sorting - by date DESC, then by ID DESC (newest first for same day)
    filtered.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      // For same date, sort by ID descending (newest entries have higher IDs)
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });
    return filtered;
  }

  // ============== INCOME METHODS ==============

  Future<void> addIncome(Income income) async {
    if (income.amountDecimal <= Decimal.zero) {
      throw ArgumentError('Income amount must be greater than zero');
    }
    if (income.category.isEmpty) {
      throw ArgumentError('Income must have a category');
    }

    await _writeMutex.synchronized(() async {
      await _db.createIncome(income);
      await _loadIncomesInternal();
      notifyListeners();
      _updateHomeWidget();
    });
  }

  Future<void> addIncomeRaw({
    required double amount,
    required String category,
    required String description,
    required DateTime date,
  }) async {
    final income = Income(
      amount: DecimalHelper.fromDouble(amount),
      category: category,
      description: description,
      date: date,
      accountId: currentAccountId,
    );
    await addIncome(income);
  }

  Future<void> updateIncome(Income income) async {
    await _writeMutex.synchronized(() async {
      await _db.updateIncome(income);
      await _loadIncomesInternal();
      notifyListeners();
      _updateHomeWidget(); // FIX: Update home widget after income update
    });
  }

  Future<void> deleteIncome(int id) async {
    await _writeMutex.synchronized(() async {
      // FIX: Properly handle case when income is not found in memory
      final incomeIndex = _incomes.indexWhere((i) => i.id == id);
      if (incomeIndex != -1) {
        // Income found in memory - use it for deletion
        await _db.moveIncomeToDeleted(_incomes[incomeIndex]);
      } else {
        // Income not in memory (e.g., from a different month) - delete by ID
        await _db.moveIncomeToDeletedById(id);
      }
      await _loadIncomesInternal();
      notifyListeners();
      _updateHomeWidget();
    });
  }

  // ============== TRASH METHODS ==============

  Future<List<Map<String, dynamic>>> getDeletedExpenses() async {
    return await _db.getAllDeletedExpenses(currentAccountId);
  }

  Future<List<Map<String, dynamic>>> getDeletedIncome() async {
    return await _db.getAllDeletedIncome(currentAccountId);
  }

  Future<void> restoreDeletedExpense(int deletedId) async {
    await _db.restoreDeletedExpense(deletedId);
    await _loadExpenses();
    _invalidateExpenseCache(); // FIX: Invalidate cache after restore
    notifyListeners();
    _updateHomeWidget(); // FIX: Update home widget after restore
  }

  Future<void> restoreDeletedIncome(int deletedId) async {
    await _db.restoreDeletedIncome(deletedId);
    await _loadIncomes();
    notifyListeners();
    _updateHomeWidget(); // FIX: Update home widget after restore
  }

  Future<void> permanentlyDeleteExpense(int deletedId) async {
    await _db.permanentlyDeleteExpense(deletedId);
    notifyListeners();
  }

  Future<void> permanentlyDeleteIncome(int deletedId) async {
    await _db.permanentlyDeleteIncome(deletedId);
    notifyListeners();
  }

  Future<void> emptyTrash() async {
    await _writeMutex.synchronized(() async {
      await _db.emptyTrash(currentAccountId);
      notifyListeners();
    });
  }

  // ============== BUDGET METHODS ==============

  Budget? _lastDeletedBudget;

  Future<void> _autoRolloverBudgets() async {
    final now = DateHelper.today();
    final currentMonthStart = DateHelper.startOfMonth(now);
    final currentMonthBudgetsExist = _budgets.any((b) => _isSameMonth(b.month, currentMonthStart));

    if (!currentMonthBudgetsExist) {
      final prevMonth = DateHelper.startOfMonth(DateHelper.subtractMonths(now, 1));
      final prevMonthBudgets = _budgets.where((b) => _isSameMonth(b.month, prevMonth)).toList();
      for (final budget in prevMonthBudgets) {
        final newBudget = Budget(category: budget.category, amount: budget.amountDecimal, accountId: budget.accountId, month: currentMonthStart);
        await _db.createBudget(newBudget);
      }
      if (prevMonthBudgets.isNotEmpty) {
        await _loadBudgets();
      }
    }
  }

  /// Set a budget for a category in the selected month.
  /// FIX: Validates that the category exists before creating a budget.
  /// Throws ArgumentError if amount <= 0 or category doesn't exist.
  Future<void> setBudget(String category, double amount) async {
    if (amount <= 0) {
      throw ArgumentError('Budget amount must be greater than zero');
    }
    if (category.isEmpty) {
      throw ArgumentError('Category cannot be empty');
    }

    await _writeMutex.synchronized(() async {
      // FIX: Validate that the category exists before creating a budget
      final categoryExists = expenseCategories.any((c) => c.name == category);
      if (!categoryExists) {
        throw ArgumentError('Category "$category" does not exist');
      }

      final existing = _budgets.where((b) => b.category == category && _isSameMonth(b.month, _selectedMonth)).toList();
      if (existing.isNotEmpty) {
        final updated = existing.first.copyWithDecimal(amount: DecimalHelper.fromDouble(amount));
        await _db.updateBudget(updated);
      } else {
        final budget = Budget(category: category, amount: DecimalHelper.fromDouble(amount), accountId: currentAccountId, month: DateHelper.startOfMonth(_selectedMonth));
        await _db.createBudget(budget);
      }
      await _loadBudgets();
      notifyListeners();
    });
  }

  Future<void> deleteBudget(int id) async {
    await _writeMutex.synchronized(() async {
      // Store the budget before deleting for undo
      final budgetIndex = _budgets.indexWhere((b) => b.id == id);
      if (budgetIndex != -1) {
        _lastDeletedBudget = _budgets[budgetIndex];
      }
      await _db.deleteBudget(id);
      await _loadBudgets();
      notifyListeners();
    });
  }

  Future<void> undoBudgetDeletion() async {
    if (_lastDeletedBudget == null) {
      return;
    }

    await _writeMutex.synchronized(() async {
      // Create a new budget with the same properties (without id for auto-increment)
      final budget = Budget(
        category: _lastDeletedBudget!.category,
        amount: _lastDeletedBudget!.amountDecimal,
        accountId: _lastDeletedBudget!.accountId,
        month: _lastDeletedBudget!.month,
      );
      await _db.createBudget(budget);
      _lastDeletedBudget = null;
      await _loadBudgets();
      notifyListeners();
    });
  }

  Map<String, double> getBudgetSpentBreakdown(String category) {
    final actualSpentDecimal = getExpensesForSelectedMonth().where((e) => e.category == category).map((e) => e.amountDecimal).fold(Decimal.zero, (sum, amount) => sum + amount);
    Decimal projectedRecurringDecimal = Decimal.zero;
    for (final recurring in _recurringExpenses) {
      if (!recurring.shouldBeActive || recurring.category != category) {
        continue;
      }
      final occurrencesInMonth = _countRecurringOccurrencesInMonth(recurring, _selectedMonth);
      if (occurrencesInMonth == 0) {
        continue;
      }
      final alreadyCreatedCount = _expenses.where((e) => e.description == recurring.description && e.category == recurring.category && e.amountDecimal == recurring.amountDecimal && _isSameMonth(e.date, _selectedMonth)).length;
      final remainingOccurrences = occurrencesInMonth - alreadyCreatedCount;
      if (remainingOccurrences > 0) {
        projectedRecurringDecimal += recurring.amountDecimal * Decimal.fromInt(remainingOccurrences);
      }
    }
    return {'actual': _decimalToDouble(actualSpentDecimal), 'projected': _decimalToDouble(projectedRecurringDecimal), 'total': _decimalToDouble(actualSpentDecimal + projectedRecurringDecimal)};
  }

  double getBudgetSpent(String category) => getBudgetSpentBreakdown(category)['total'] ?? 0.0;
  double getBudgetSpentActual(String category) {
    final actualSpentDecimal = getExpensesForSelectedMonth().where((e) => e.category == category).map((e) => e.amountDecimal).fold(Decimal.zero, (sum, amount) => sum + amount);
    return _decimalToDouble(actualSpentDecimal);
  }

  int _countRecurringOccurrencesInMonth(RecurringExpense recurring, DateTime month) {
    if (recurring.startDate != null && DateHelper.normalize(recurring.startDate!).isAfter(DateHelper.endOfMonth(month))) {
      return 0;
    }
    if (recurring.endDate != null && DateHelper.normalize(recurring.endDate!).isBefore(DateHelper.startOfMonth(month))) {
      return 0;
    }
    switch (recurring.frequency) {
      case RecurringExpenseFrequency.monthly: return 1;
      case RecurringExpenseFrequency.weekly: return _countWeeklyOccurrencesInMonth(recurring, month);
      case RecurringExpenseFrequency.biweekly: return _countBiweeklyOccurrencesInMonth(recurring, month);
    }
  }

  int _countWeeklyOccurrencesInMonth(RecurringExpense recurring, DateTime month) {
    final monthStart = DateHelper.startOfMonth(month);
    final monthEnd = DateHelper.lastDayOfMonth(month);
    int count = 0;
    DateTime current = monthStart;
    while (!DateHelper.normalize(current).isAfter(monthEnd)) {
      if (current.weekday - 1 == recurring.dayOfMonth) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  /// Counts biweekly occurrences within a given month.
  /// FIX P1-5: Removed redundant weekday check. Since we iterate by 14 days from startDate,
  /// the weekday remains constant. We trust that startDate was set to the correct weekday.
  int _countBiweeklyOccurrencesInMonth(RecurringExpense recurring, DateTime month) {
    if (recurring.startDate == null) {
      return 0;
    }
    final monthStart = DateHelper.startOfMonth(month);
    final monthEnd = DateHelper.lastDayOfMonth(month);
    int count = 0;
    DateTime current = recurring.startDate!;

    // Fast-forward to the first occurrence at or after monthStart
    while (DateHelper.normalize(current).isBefore(monthStart)) {
      current = current.add(const Duration(days: 14));
    }

    // Count all occurrences within the month
    while (!DateHelper.normalize(current).isAfter(monthEnd)) {
      // Ensure we're still within the month (inclusive)
      if (!DateHelper.normalize(current).isBefore(monthStart)) {
        count++;
      }
      current = current.add(const Duration(days: 14));
    }
    return count;
  }

  double getBudgetProgress(Budget budget) {
    // FIX: Use Decimal.zero comparison to avoid floating-point precision issues
    if (budget.amountDecimal == Decimal.zero) {
      return 0.0;
    }
    return (getBudgetSpent(budget.category) / budget.amount).clamp(0.0, 1.0);
  }

  Future<void> _checkBudgetAlerts(String category) async {
    if (!_budgetAlertsEnabled) {
      return;
    }
    final today = DateHelper.today();
    final currentMonth = DateHelper.startOfMonth(today);
    final matchingBudgets = _budgets.where((b) => b.category == category && _isSameMonth(b.month, currentMonth)).toList();
    if (matchingBudgets.isEmpty) {
      return;
    }
    final budget = matchingBudgets.first;
    final spent = getBudgetSpent(category);
    final progress = budget.amount > 0 ? spent / budget.amount : 0.0;
    if (progress >= 0.8) {
      await _notificationHelper.showBudgetAlert(budget, spent, progress);
    }
  }

  // ============== CARRYOVER METHODS ==============

  /// Calculate and store the carryover for the current month from the previous month
  /// This should be called during app initialization and when navigating to a new month
  Future<void> _calculateAndStoreCarryover() async {
    final now = DateHelper.today();
    final currentMonthStart = DateHelper.startOfMonth(now);

    // Calculate carryover for current month from previous month
    await _calculateCarryoverForMonth(currentMonthStart);
  }

  /// Calculate the carryover for a specific month from its previous month
  Future<void> _calculateCarryoverForMonth(DateTime month) async {
    final prevMonth = DateHelper.startOfMonth(DateHelper.subtractMonths(month, 1));
    final monthKey = _monthKey(month);

    // Check if we already have a carryover stored for this month
    final existingBalance = _monthlyBalances[monthKey];

    // Get the previous month's carryover (if any)
    final prevMonthKey = _monthKey(prevMonth);
    final prevBalance = _monthlyBalances[prevMonthKey];
    final prevCarryover = prevBalance?.carryoverFromPreviousDecimal ?? Decimal.zero;

    // Calculate previous month's balance (income - expenses)
    final prevMonthBalance = await _db.calculateMonthBalance(
      currentAccountId,
      prevMonth.year,
      prevMonth.month,
    );

    // Total carryover = previous month's (balance + carryover)
    final totalCarryover = DecimalHelper.fromDouble(prevMonthBalance) + prevCarryover;

    // Only update if the calculated carryover is different or doesn't exist
    if (existingBalance == null ||
        existingBalance.carryoverFromPreviousDecimal != totalCarryover) {
      final newBalance = MonthlyBalance(
        id: existingBalance?.id,
        carryoverFromPrevious: totalCarryover,
        accountId: currentAccountId,
        month: month,
      );

      await _db.upsertMonthlyBalance(newBalance);
      _monthlyBalances[monthKey] = newBalance;
    }
  }

  /// Get the carryover for a specific month
  Future<double> getCarryoverForMonth(DateTime month) async {
    final key = _monthKey(month);

    // Check cache first
    if (_monthlyBalances.containsKey(key)) {
      return _monthlyBalances[key]!.carryoverFromPrevious;
    }

    // Load from database
    final balance = await _db.getMonthlyBalance(currentAccountId, month);
    if (balance != null) {
      _monthlyBalances[key] = balance;
      return balance.carryoverFromPrevious;
    }

    // Calculate if not found
    await _calculateCarryoverForMonth(month);
    return _monthlyBalances[key]?.carryoverFromPrevious ?? 0.0;
  }

  /// Recalculate carryover for the selected month and all subsequent months
  /// Call this after adding/editing/deleting transactions that affect past months
  Future<void> recalculateCarryovers() async {
    await _writeMutex.synchronized(() async {
      final now = DateHelper.today();
      final currentMonthStart = DateHelper.startOfMonth(now);

      // Recalculate for current month
      await _calculateCarryoverForMonth(currentMonthStart);

      // Also recalculate for the selected month if different
      if (!_isSameMonth(_selectedMonth, currentMonthStart)) {
        await _calculateCarryoverForMonth(_selectedMonth);
      }

      await _loadMonthlyBalances();
      notifyListeners();
    });
  }

  // ============== OVERALL MONTHLY BUDGET METHODS ==============

  /// Set the overall monthly budget for the selected month
  Future<void> setOverallMonthlyBudget(double amount) async {
    if (amount <= 0) {
      throw ArgumentError('Overall budget must be greater than zero');
    }

    await _writeMutex.synchronized(() async {
      final monthKey = _monthKey(_selectedMonth);
      final existingBalance = _monthlyBalances[monthKey];

      final newBalance = MonthlyBalance(
        id: existingBalance?.id,
        carryoverFromPrevious: existingBalance?.carryoverFromPreviousDecimal ?? Decimal.zero,
        overallBudget: DecimalHelper.fromDouble(amount),
        accountId: currentAccountId,
        month: _selectedMonth,
      );

      await _db.upsertMonthlyBalance(newBalance);
      _monthlyBalances[monthKey] = newBalance;
      notifyListeners();
    });
  }

  /// Remove the overall monthly budget for the selected month
  Future<void> removeOverallMonthlyBudget() async {
    await _writeMutex.synchronized(() async {
      final monthKey = _monthKey(_selectedMonth);
      final existingBalance = _monthlyBalances[monthKey];

      if (existingBalance != null) {
        final newBalance = existingBalance.copyWithDecimal(
          overallBudget: null,
          clearOverallBudget: true,
        );

        await _db.upsertMonthlyBalance(newBalance);
        _monthlyBalances[monthKey] = newBalance;
        notifyListeners();
      }
    });
  }

  // ============== ACCOUNT METHODS ==============

  /// Adds a new account with the given name.
  /// FIX P3-16: Standardized error handling with validation.
  /// Throws ArgumentError if name is empty or only whitespace.
  Future<void> addAccount(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Account name cannot be empty');
    }

    await _writeMutex.synchronized(() async {
      final account = Account(name: trimmedName, isDefault: false);
      final accountId = await _db.createAccount(account);
      await _createDefaultCategoriesForAccount(accountId);
      await _loadAccounts();
      notifyListeners();
    });
  }

  Future<void> updateAccount(Account account) async {
    await _writeMutex.synchronized(() async {
      await _db.updateAccount(account);
      await _loadAccounts();
      notifyListeners();
    });
  }

  Future<void> setDefaultAccount(int accountId) async {
    await _writeMutex.synchronized(() async {
      for (final account in _accounts) {
        if (account.isDefault && account.id != accountId) {
          await _db.updateAccount(account.copyWith(isDefault: false));
        }
      }
      final accountIndex = _accounts.indexWhere((a) => a.id == accountId);
      if (accountIndex == -1) return; // Account not found, do nothing
      final newDefault = _accounts[accountIndex];
      await _db.updateAccount(newDefault.copyWith(isDefault: true));
      await _loadAccounts();
      notifyListeners();
    });
  }

  /// Deletes an account by ID.
  /// FIX P0-1: Prevents deleting the last account to avoid invalid state.
  /// Throws ArgumentError if attempting to delete the last remaining account.
  Future<void> deleteAccount(int id) async {
    await _writeMutex.synchronized(() async {
      // FIX P0-1: Prevent deleting the last account - app requires at least one account
      if (_accounts.length <= 1) {
        throw ArgumentError('Cannot delete the last account. At least one account must exist.');
      }

      await _db.deleteAccount(id);
      await _loadAccounts();

      if (_currentAccount?.id == id) {
        // FIX P0-1: _accounts is guaranteed non-empty due to the check above
        // Try to find a default account first, otherwise use the first available
        _currentAccount = _accounts.firstWhere(
          (a) => a.isDefault,
          orElse: () => _accounts.first, // Safe: _accounts is not empty
        );
        clearFilters();
        await _reloadAccountData();
      }
      notifyListeners();
    });
  }

  Future<void> resetAccount(int accountId) async {
    await _writeMutex.synchronized(() async {
      final db = await _db.database;
      await db.transaction((txn) async {
        await txn.delete('expenses', where: 'account_id = ?', whereArgs: [accountId]);
        await txn.delete('income', where: 'account_id = ?', whereArgs: [accountId]);
        await txn.delete('budgets', where: 'account_id = ?', whereArgs: [accountId]);
        await txn.delete('recurring_expenses', where: 'account_id = ?', whereArgs: [accountId]);
        await txn.delete('recurring_income', where: 'account_id = ?', whereArgs: [accountId]);
        await txn.delete('quick_templates', where: 'account_id = ?', whereArgs: [accountId]);
        await txn.delete('categories', where: 'account_id = ? AND isDefault = 0', whereArgs: [accountId]);
        await txn.delete('tags', where: 'account_id = ?', whereArgs: [accountId]);
        await txn.delete('transaction_tags', where: '1=1');
        await txn.delete('deleted_expenses', where: 'account_id = ?', whereArgs: [accountId]);
        await txn.delete('deleted_income', where: 'account_id = ?', whereArgs: [accountId]);
      });
      if (_currentAccount?.id == accountId) {
        clearFilters();
        await _reloadAccountData();
      }
      notifyListeners();
    });
  }

  Future<List<Map<String, dynamic>>> getDeletedAccounts() async => await _db.getDeletedAccounts();

  Future<void> restoreDeletedAccount(int deletedId) async {
    final newAccountId = await _db.restoreDeletedAccount(deletedId);
    await _loadAccounts();
    final restoredAccount = _accounts.firstWhere((a) => a.id == newAccountId);
    await switchAccount(restoredAccount);
  }

  Future<void> permanentlyDeleteAccount(int deletedId) async => await _db.permanentlyDeleteAccount(deletedId);

  Future<void> switchAccount(Account account) async {
    _currentAccount = account;
    _currencyCode = account.currencyCode;
    _accountJustSwitched = true;
    clearFilters();
    await _reloadAccountData();
    // FIX: Simplified null check
    final accountId = account.id;
    if (_categories.isEmpty && accountId != null) {
      await _createDefaultCategoriesForAccount(accountId);
      await _loadCategories();
    }
    notifyListeners();
  }

  bool _accountJustSwitched = false;
  bool get accountJustSwitched => _accountJustSwitched;
  void clearAccountSwitchFlag() => _accountJustSwitched = false;

  Future<void> _reloadAccountData() async {
    await _loadCategories();
    await _loadExpenses();
    await _loadIncomes();
    await _loadBudgets();
    await _loadQuickTemplates();
    await _loadRecurringExpenses();
    await _loadRecurringIncomes();
    await _loadTags();
    await _loadMonthlyBalances();
    await _calculateAndStoreCarryover();
  }

  Future<void> _createDefaultCategoriesForAccount(int accountId) async {
    final defaultExpenseCategories = ['Food', 'Transport', 'Shopping', 'Entertainment', 'Health', 'Education', 'Bills', 'Other'];
    for (var cat in defaultExpenseCategories) {
      await _db.createCategory(Category(name: cat, accountId: accountId, isDefault: true, type: 'expense'));
    }
    final defaultIncomeCategories = ['Salary', 'Freelance', 'Investment', 'Gift', 'Other'];
    for (var cat in defaultIncomeCategories) {
      await _db.createCategory(Category(name: cat, accountId: accountId, isDefault: true, type: 'income'));
    }
  }

  Future<void> refreshCurrentMonthData() async {
    await _loadExpenses();
    await _loadIncomes();
    _invalidateExpenseCache(); // FIX: Invalidate cache after refresh to ensure fresh data is displayed
    notifyListeners();
  }

  // ============== CATEGORY METHODS ==============

  /// Add a new category with validation.
  /// FIX: Validates for duplicate category names (case-insensitive) at the data layer
  /// to prevent duplicates even when called programmatically.
  /// Throws ArgumentError if name is empty or already exists.
  Future<void> addCategory(String name, {String type = 'expense', String? color, String? icon}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }

    await _writeMutex.synchronized(() async {
      // FIX: Check for duplicate names (case-insensitive) before insertion
      final existingCategories = type == 'expense' ? expenseCategories : incomeCategories;
      final lowerCaseName = trimmedName.toLowerCase();
      final isDuplicate = existingCategories.any((c) => c.name.toLowerCase() == lowerCaseName);

      if (isDuplicate) {
        throw ArgumentError('A category with this name already exists');
      }

      final category = Category(name: trimmedName, accountId: currentAccountId, isDefault: false, type: type, color: color, icon: icon);
      await _db.createCategory(category);
      await _loadCategories();
      notifyListeners();
    });
  }

  Future<void> updateCategory(Category category, {String? oldName}) async {
    await _writeMutex.synchronized(() async {
      if (_categoryRenameInProgress) {
        return;
      }
      _categoryRenameInProgress = true;
      try {
        if (oldName != null && oldName != category.name) {
          await _db.renameCategoryInAllTables(currentAccountId, oldName, category.name, category.type);
        }
        await _db.updateCategory(category);
        await _loadCategories();
        if (oldName != null && oldName != category.name) {
          await Future.wait([_loadExpensesInternal(), _loadIncomesInternal(), _loadBudgets(), _loadQuickTemplates(), _loadRecurringExpenses()]);
        }
        notifyListeners();
      } finally {
        _categoryRenameInProgress = false;
      }
    });
  }

  Future<void> deleteCategory(int id) async {
    await _writeMutex.synchronized(() async {
      await _db.deleteCategory(id);
      await _loadCategories();
      notifyListeners();
    });
  }

  Future<void> bulkReassignCategory(String oldCategory, String newCategory, String type) async {
    await _writeMutex.synchronized(() async {
      await _db.bulkReassignCategory(currentAccountId, oldCategory, newCategory, type);
      await Future.wait([_loadExpensesInternal(), _loadIncomesInternal(), _loadBudgets(), _loadQuickTemplates(), _loadRecurringExpenses(), _loadRecurringIncomes()]);
      notifyListeners();
    });
  }

  Future<void> bulkDeleteTransactionsByCategory(String category, String type) async {
    await _writeMutex.synchronized(() async {
      await _db.bulkDeleteTransactionsByCategory(currentAccountId, category, type);
      await Future.wait([_loadExpensesInternal(), _loadIncomesInternal()]);
      notifyListeners();
    });
  }

  Future<void> reassignCategoryAndDelete(int categoryId, String oldCategory, String newCategory, String type) async {
    await _writeMutex.synchronized(() async {
      await _db.bulkReassignCategoryAndDelete(currentAccountId, categoryId, oldCategory, newCategory, type);
      await Future.wait([_loadCategories(), _loadExpensesInternal(), _loadIncomesInternal(), _loadBudgets(), _loadQuickTemplates(), _loadRecurringExpenses(), _loadRecurringIncomes()]);
      notifyListeners();
    });
  }

  Future<void> deleteTransactionsAndCategory(int categoryId, String category, String type) async {
    await _writeMutex.synchronized(() async {
      await _db.bulkDeleteTransactionsAndCategory(currentAccountId, categoryId, category, type);
      await Future.wait([_loadCategories(), _loadExpensesInternal(), _loadIncomesInternal()]);
      notifyListeners();
    });
  }

  Map<String, int> getCategoryUsageInRecurring(String categoryName) {
    return {
      'recurringExpenses': _recurringExpenses.where((r) => r.category == categoryName).length,
      'recurringIncome': _recurringIncomes.where((r) => r.category == categoryName).length,
    };
  }

  Future<int> countTransactionsByCategory(String categoryName, String type) async {
    if (type == 'expense') {
      return await _db.countExpensesByCategory(currentAccountId, categoryName);
    }
    return await _db.countIncomesByCategory(currentAccountId, categoryName);
  }

  // ============== QUICK TEMPLATES ==============

  Future<void> addTemplate(QuickTemplate template) async {
    await _writeMutex.synchronized(() async {
      await _db.createTemplate(template);
      await _loadQuickTemplates();
      notifyListeners();
    });
  }

  Future<void> updateTemplate(QuickTemplate template) async {
    await _writeMutex.synchronized(() async {
      await _db.updateTemplate(template);
      await _loadQuickTemplates();
      notifyListeners();
    });
  }

  Future<void> deleteTemplate(int id) async {
    await _writeMutex.synchronized(() async {
      await _db.deleteTemplate(id);
      await _loadQuickTemplates();
      notifyListeners();
    });
  }

  /// Use a quick template to create a new transaction.
  /// FIX: Validates that the template's category still exists before creating transaction.
  /// If category was deleted, falls back to 'Uncategorized' or first available category.
  Future<void> useTemplate(QuickTemplate template) async {
    final now = DateTime.now();
    final date = DateTime.utc(now.year, now.month, now.day, 12, 0, 0);

    // FIX: Validate category still exists
    String categoryToUse = template.category;
    if (template.type == 'expense') {
      final categoryExists = expenseCategories.any((c) => c.name == template.category);
      if (!categoryExists) {
        // Try to find 'Uncategorized' or use first available category
        final uncategorized = expenseCategories.firstWhere(
          (c) => c.name.toLowerCase() == 'uncategorized',
          orElse: () => expenseCategories.isNotEmpty ? expenseCategories.first : throw ArgumentError('No expense categories available'),
        );
        categoryToUse = uncategorized.name;
      }
      await addExpense(Expense(amount: template.amountDecimal, category: categoryToUse, description: template.name, date: date, accountId: currentAccountId, amountPaid: template.amountDecimal, paymentMethod: template.paymentMethod));
    } else {
      final categoryExists = incomeCategories.any((c) => c.name == template.category);
      if (!categoryExists) {
        final uncategorized = incomeCategories.firstWhere(
          (c) => c.name.toLowerCase() == 'uncategorized',
          orElse: () => incomeCategories.isNotEmpty ? incomeCategories.first : throw ArgumentError('No income categories available'),
        );
        categoryToUse = uncategorized.name;
      }
      await addIncome(Income(amount: template.amountDecimal, category: categoryToUse, description: template.name, date: date, accountId: currentAccountId));
    }
  }

  // ============== RECURRING METHODS ==============

  Future<void> addRecurringExpense(RecurringExpense recurring) async {
    await _writeMutex.synchronized(() async {
      await _db.createRecurringExpense(recurring);
      await _loadRecurringExpenses();
      notifyListeners();
    });
  }

  Future<void> updateRecurringExpense(RecurringExpense recurring) async {
    await _writeMutex.synchronized(() async {
      await _db.updateRecurringExpense(recurring);
      await _loadRecurringExpenses();
      // FIX: Simplified null check
      final recurringId = recurring.id;
      if (recurringId != null) {
        if (recurring.isActive && _billRemindersEnabled) {
          await _notificationHelper.scheduleBillReminder(recurring);
        } else {
          await _notificationHelper.cancelBillReminder(recurringId);
        }
      }
      notifyListeners();
    });
  }

  Future<void> deleteRecurringExpense(int id) async {
    await _writeMutex.synchronized(() async {
      await _notificationHelper.cancelBillReminder(id);
      await _db.deleteRecurringExpense(id);
      await _loadRecurringExpenses();
      notifyListeners();
    });
  }

  Future<void> addRecurringIncome(RecurringIncome recurring) async {
    await _writeMutex.synchronized(() async {
      await _db.createRecurringIncome(recurring);
      await _loadRecurringIncomes();
      notifyListeners();
    });
  }

  Future<void> updateRecurringIncome(RecurringIncome recurring) async {
    await _writeMutex.synchronized(() async {
      await _db.updateRecurringIncome(recurring);
      await _loadRecurringIncomes();
      notifyListeners();
    });
  }

  Future<void> deleteRecurringIncome(int id) async {
    await _writeMutex.synchronized(() async {
      await _db.deleteRecurringIncome(id);
      await _loadRecurringIncomes();
      notifyListeners();
    });
  }

  /// Process recurring expenses, creating any that are due today.
  /// FIX: Added individual try-catch to handle partial failures gracefully.
  Future<void> _processRecurringExpenses() async {
    await _writeMutex.synchronized(() async {
      final today = DateHelper.today();
      int totalCreated = 0;
      // FIX: Query only active recurring expenses from database to avoid iterating inactive ones
      final activeRecurring = await _db.readActiveRecurringExpenses(currentAccountId);
      for (final recurring in activeRecurring) {
        // FIX: Wrap individual recurring item processing in try-catch
        // so one failure doesn't prevent processing of other items
        try {
          if (!recurring.shouldBeActive) {
            continue; // Double-check in case of race condition
          }
          final lastCreated = recurring.lastCreated;
          if (lastCreated != null && DateHelper.isSameDay(lastCreated, today)) {
            continue;
          }
          final expensesToCreate = _processMonthlyRecurring<Expense>(lastCreated: lastCreated, dayOfMonth: recurring.dayOfMonth, now: today, createTransaction: (date) => Expense(amount: recurring.amountDecimal, category: recurring.category, description: recurring.description, date: date, accountId: recurring.accountId, amountPaid: Decimal.zero, paymentMethod: recurring.paymentMethod));
          if (expensesToCreate.isNotEmpty) {
            final updatedRecurring = recurring.copyWith(lastCreated: today, occurrenceCount: recurring.occurrenceCount + expensesToCreate.length);
            await _db.createRecurringExpensesBatch(expenses: expensesToCreate, recurringToUpdate: updatedRecurring);
            totalCreated += expensesToCreate.length;
          }
        } catch (e) {
          // Log error but continue processing other recurring items
          if (kDebugMode) debugPrint('Error processing recurring expense ${recurring.id}: $e');
        }
      }
      _lastAutoCreatedCount += totalCreated;
      await _loadExpensesInternal();
      await _loadRecurringExpenses();
    });
  }

  /// Process recurring incomes, creating any that are due today.
  /// FIX: Added individual try-catch to handle partial failures gracefully.
  Future<void> _processRecurringIncomes() async {
    await _writeMutex.synchronized(() async {
      final today = DateHelper.today();
      int totalCreated = 0;
      // FIX: Query only active recurring income from database to avoid iterating inactive ones
      final activeRecurring = await _db.readActiveRecurringIncome(currentAccountId);
      for (final recurring in activeRecurring) {
        // FIX: Wrap individual recurring item processing in try-catch
        // so one failure doesn't prevent processing of other items
        try {
          if (!recurring.shouldBeActive) {
            continue; // Double-check in case of race condition
          }
          if (recurring.lastCreated != null && DateHelper.isSameDay(recurring.lastCreated!, today)) {
            continue;
          }
          final incomesToCreate = _processMonthlyRecurring<Income>(lastCreated: recurring.lastCreated, dayOfMonth: recurring.dayOfMonth, now: today, createTransaction: (date) => Income(amount: recurring.amountDecimal, category: recurring.category, description: recurring.description, date: date, accountId: recurring.accountId));
          if (incomesToCreate.isNotEmpty) {
            final updatedRecurring = recurring.copyWith(lastCreated: today, occurrenceCount: recurring.occurrenceCount + incomesToCreate.length);
            await _db.createRecurringIncomeBatch(incomes: incomesToCreate, recurringToUpdate: updatedRecurring);
            totalCreated += incomesToCreate.length;
          }
        } catch (e) {
          // Log error but continue processing other recurring items
          if (kDebugMode) debugPrint('Error processing recurring income ${recurring.id}: $e');
        }
      }
      _lastAutoCreatedCount += totalCreated;
      await _loadIncomesInternal();
      await _loadRecurringIncomes();
    });
  }

  List<T> _processMonthlyRecurring<T>({required DateTime? lastCreated, required int dayOfMonth, required DateTime now, required T Function(DateTime date) createTransaction}) {
    final List<T> transactionsToCreate = [];
    DateTime currentMonth = lastCreated == null ? (now.day >= dayOfMonth ? DateHelper.startOfMonth(DateHelper.addMonths(now, 1)) : DateHelper.startOfMonth(now)) : DateHelper.addMonths(lastCreated, 1);
    final currentMonthStart = DateHelper.startOfMonth(now);
    while (!DateHelper.normalize(currentMonth).isAfter(currentMonthStart)) {
      if (DateHelper.normalize(currentMonth).isBefore(currentMonthStart) || now.day >= dayOfMonth) {
        final lastDay = DateHelper.lastDayOfMonth(currentMonth).day;
        transactionsToCreate.add(createTransaction(DateHelper.normalize(DateTime(currentMonth.year, currentMonth.month, dayOfMonth > lastDay ? lastDay : dayOfMonth))));
      }
      currentMonth = DateHelper.addMonths(currentMonth, 1);
    }
    return transactionsToCreate;
  }

  // ============== TAG METHODS ==============

  Future<void> addTag(String name, {String? color}) async {
    await _writeMutex.synchronized(() async {
      await _db.createTag(name, currentAccountId, color: color);
      await _loadTags();
      notifyListeners();
    });
  }

  Future<void> updateTag(int id, String name, {String? color}) async {
    await _writeMutex.synchronized(() async {
      await _db.updateTag(id, name, color: color);
      await _loadTags();
      notifyListeners();
    });
  }

  Future<void> deleteTag(int id) async {
    await _writeMutex.synchronized(() async {
      await _db.deleteTag(id);
      await _loadTags();
      notifyListeners();
    });
  }

  Future<void> addTagToTransaction(int transactionId, String transactionType, int tagId) async {
    await _writeMutex.synchronized(() async {
      await _db.addTagToTransaction(transactionId, transactionType, tagId);
      notifyListeners();
    });
  }

  Future<void> removeTagFromTransaction(int transactionId, String transactionType, int tagId) async {
    await _writeMutex.synchronized(() async {
      await _db.removeTagFromTransaction(transactionId, transactionType, tagId);
      notifyListeners();
    });
  }

  Future<List<Tag>> getTagsForTransaction(int transactionId, String transactionType) async {
    final tagMaps = await _db.getTagsForTransaction(transactionId, transactionType);
    return tagMaps.map((map) => Tag.fromMap(map)).toList();
  }

  // ============== SEARCH & ANALYTICS ==============

  Future<Map<String, dynamic>> searchTransactionsUnified(String query, {int limit = 50, int offset = 0, String? category, String? startDate, String? endDate, String sortOrder = 'newest'}) async {
    if (query.isEmpty) {
      return {'expenses': <Expense>[], 'income': <Income>[], 'hasMore': false};
    }
    return await _db.searchTransactionsUnified(currentAccountId, query, limit: limit, offset: offset, category: category, startDate: startDate, endDate: endDate, sortOrder: sortOrder);
  }

  Map<String, dynamic> getMonthOverMonthComparison() {
    final currentExpenses = getExpensesForSelectedMonth();
    final prevMonth = DateHelper.subtractMonths(_selectedMonth, 1);
    final prevExpenses = _expenses.where((e) => _isSameMonth(e.date, prevMonth)).toList();
    final currentTotal = currentExpenses.map((e) => e.amountDecimal).fold(Decimal.zero, (sum, a) => sum + a);
    final prevTotal = prevExpenses.map((e) => e.amountDecimal).fold(Decimal.zero, (sum, a) => sum + a);
    final change = prevTotal > Decimal.zero ? (((currentTotal - prevTotal) / prevTotal).toDecimal(scaleOnInfinitePrecision: 4) * Decimal.fromInt(100)) : Decimal.zero;

    // Calculate category-by-category comparison
    final Map<String, Map<String, double>> categoryComparison = {};
    final allCategories = {...currentExpenses.map((e) => e.category), ...prevExpenses.map((e) => e.category)};

    for (final category in allCategories) {
      final currentCategoryTotal = currentExpenses.where((e) => e.category == category).map((e) => e.amountDecimal).fold(Decimal.zero, (sum, a) => sum + a);
      final prevCategoryTotal = prevExpenses.where((e) => e.category == category).map((e) => e.amountDecimal).fold(Decimal.zero, (sum, a) => sum + a);
      final categoryChange = prevCategoryTotal > Decimal.zero ? (((currentCategoryTotal - prevCategoryTotal) / prevCategoryTotal).toDecimal(scaleOnInfinitePrecision: 4) * Decimal.fromInt(100)) : Decimal.zero;

      categoryComparison[category] = {
        'current': _decimalToDouble(currentCategoryTotal),
        'previous': _decimalToDouble(prevCategoryTotal),
        'change': _decimalToDouble(categoryChange),
      };
    }

    return {
      'currentTotal': _decimalToDouble(currentTotal),
      'previousTotal': _decimalToDouble(prevTotal),
      'percentChange': _decimalToDouble(change),
      'categoryComparison': categoryComparison,
    };
  }

  Map<String, dynamic> getIncomeMonthOverMonthComparison() {
    final currentIncome = _incomes.where((i) => _isSameMonth(i.date, _selectedMonth)).toList();
    final prevMonth = DateHelper.subtractMonths(_selectedMonth, 1);
    final prevIncome = _incomes.where((i) => _isSameMonth(i.date, prevMonth)).toList();
    final currentTotal = currentIncome.map((i) => i.amountDecimal).fold(Decimal.zero, (sum, a) => sum + a);
    final prevTotal = prevIncome.map((i) => i.amountDecimal).fold(Decimal.zero, (sum, a) => sum + a);
    final change = prevTotal > Decimal.zero ? (((currentTotal - prevTotal) / prevTotal).toDecimal(scaleOnInfinitePrecision: 4) * Decimal.fromInt(100)) : Decimal.zero;
    return {'currentTotal': _decimalToDouble(currentTotal), 'previousTotal': _decimalToDouble(prevTotal), 'percentChange': _decimalToDouble(change)};
  }

  Future<List<Map<String, dynamic>>> getSpendingTrends({int months = 6}) async {
    final List<Map<String, dynamic>> trends = [];
    // FIX: Use selected month instead of today to support viewing future/past month analytics
    final referenceMonth = _selectedMonth;
    for (int i = months - 1; i >= 0; i--) {
      final month = DateHelper.startOfMonth(DateHelper.subtractMonths(referenceMonth, i));
      await ensureMonthLoaded(month);
      final monthExpenses = _expenses.where((e) => _isSameMonth(e.date, month));
      final monthIncome = _incomes.where((i) => _isSameMonth(i.date, month));
      final expTotal = monthExpenses.map((e) => e.amountDecimal).fold(Decimal.zero, (sum, a) => sum + a);
      final incTotal = monthIncome.map((i) => i.amountDecimal).fold(Decimal.zero, (sum, a) => sum + a);
      trends.add({'month': month, 'expenses': _decimalToDouble(expTotal), 'income': _decimalToDouble(incTotal), 'savings': _decimalToDouble(incTotal - expTotal)});
    }
    return trends;
  }

  // ============== NAVIGATION ==============

  Future<void> goToPreviousMonth() async {
    final newMonth = DateHelper.subtractMonths(_selectedMonth, 1);
    await ensureMonthLoaded(newMonth);
    _selectedMonth = newMonth;
    await _ensureCarryoverLoaded(newMonth);
    notifyListeners();
  }

  Future<void> goToNextMonth() async {
    final newMonth = DateHelper.addMonths(_selectedMonth, 1);
    await ensureMonthLoaded(newMonth);
    _selectedMonth = newMonth;
    await _ensureCarryoverLoaded(newMonth);
    notifyListeners();
  }

  Future<void> goToMonth(DateTime month) async {
    final newMonth = DateHelper.startOfMonth(month);
    await ensureMonthLoaded(newMonth);
    _selectedMonth = newMonth;
    await _ensureCarryoverLoaded(newMonth);
    notifyListeners();
  }

  /// Ensure the carryover is loaded for the given month
  Future<void> _ensureCarryoverLoaded(DateTime month) async {
    final key = _monthKey(month);
    if (!_monthlyBalances.containsKey(key)) {
      await _calculateCarryoverForMonth(month);
    }
  }

  void goToToday() {
    _selectedMonth = DateHelper.startOfMonth(DateHelper.today());
    notifyListeners();
  }

  // ============== SETTINGS & FILTERS ==============

  Future<void> toggleDarkMode() async { _isDarkMode = !_isDarkMode; await SettingsHelper.setDarkMode(_isDarkMode); notifyListeners(); }
  Future<void> setThemeMode(String mode) async { _themeMode = mode; _isDarkMode = mode == 'dark'; await SettingsHelper.setThemeMode(mode); notifyListeners(); }
  Future<void> changeCurrency(String code) async { await _writeMutex.synchronized(() async { _currencyCode = code; if (_currentAccount != null) await _db.updateAccount(_currentAccount!.copyWith(currencyCode: code)); notifyListeners(); }); }
  Future<void> toggleBillReminders(bool value) async { _billRemindersEnabled = value; await SettingsHelper.setBillReminders(value); notifyListeners(); }
  Future<void> toggleBudgetAlerts(bool value) async { _budgetAlertsEnabled = value; await SettingsHelper.setBudgetAlerts(value); notifyListeners(); }
  Future<void> toggleMonthlySummary(bool value) async { _monthlySummaryEnabled = value; await SettingsHelper.setMonthlySummary(value); notifyListeners(); }
  Future<void> toggleShowTransactionColors(bool value) async { _showTransactionColors = value; await SettingsHelper.setShowTransactionColors(value); notifyListeners(); }
  Future<void> setTransactionColorIntensity(double value) async { _transactionColorIntensity = value.clamp(0.0, 1.0); await SettingsHelper.setTransactionColorIntensity(_transactionColorIntensity); notifyListeners(); }
  Future<void> setReminderTime(TimeOfDay time) async { _reminderTime = time; await SettingsHelper.setReminderHour(time.hour); await SettingsHelper.setReminderMinute(time.minute); notifyListeners(); }

  void setFilterCategory(String category) { _filterCategory = category; _invalidateExpenseCache(); notifyListeners(); }
  void setDateRange(DateTime? start, DateTime? end) { _dateRange = (start != null && end != null) ? DateTimeRange(start: start, end: end) : null; _invalidateExpenseCache(); notifyListeners(); }
  void setAmountRange(double? min, double? max) { _minAmount = min; _maxAmount = max; _invalidateExpenseCache(); notifyListeners(); }
  void setPaidStatusFilter(bool? isPaid) { _paidStatusFilter = isPaid; _invalidateExpenseCache(); notifyListeners(); }
  void clearFilters() { _filterCategory = 'All'; _dateRange = null; _minAmount = null; _maxAmount = null; _paidStatusFilter = null; _invalidateExpenseCache(); notifyListeners(); }

  // ============== CALCULATIONS & ALIASES ==============

  double get totalExpensesThisMonth => _decimalToDouble(getExpensesForSelectedMonth().map((e) => e.amountDecimal).fold(Decimal.zero, (sum, amount) => sum + amount));
  double get totalIncomeThisMonth => _decimalToDouble(_incomes.where((i) => _isSameMonth(i.date, _selectedMonth)).map((i) => i.amountDecimal).fold(Decimal.zero, (sum, amount) => sum + amount));
  double get balanceThisMonth => totalIncomeThisMonth - totalExpensesThisMonth;

  double get totalPaid => _decimalToDouble(getExpensesForSelectedMonth().map((e) => e.amountPaidDecimal).fold(Decimal.zero, (sum, amount) => sum + amount));
  double get totalRemaining => _decimalToDouble(getExpensesForSelectedMonth().map((e) => e.amountDecimal - e.amountPaidDecimal).fold(Decimal.zero, (sum, amount) => sum + amount));
  double get availableIncomeBalance => totalIncomeThisMonth - totalPaid;
  double getAvailableIncomeForMonth(DateTime month) {
    final incTotal = _incomes.where((i) => _isSameMonth(i.date, month)).map((i) => i.amountDecimal).fold(Decimal.zero, (sum, a) => sum + a);
    final expPaid = _expenses.where((e) => _isSameMonth(e.date, month)).map((e) => e.amountPaidDecimal).fold(Decimal.zero, (sum, a) => sum + a);
    return _decimalToDouble(incTotal - expPaid);
  }

  List<Map<String, dynamic>> getUpcomingBillsThisMonth() {
    final List<Map<String, dynamic>> upcoming = [];
    final today = DateHelper.today();

    for (final r in _recurringExpenses) {
      if (!r.isActive) {
        continue;
      }
      final lastDay = DateHelper.lastDayOfMonth(_selectedMonth).day;
      final due = DateHelper.normalize(DateTime(_selectedMonth.year, _selectedMonth.month, r.dayOfMonth > lastDay ? lastDay : r.dayOfMonth));
      if (!due.isBefore(today)) {
        // Calculate days until due
        final daysUntilDue = DateHelper.daysBetween(today, due);
        upcoming.add({
          'description': r.description,
          'amount': r.amount,
          'dueDate': due,
          'category': r.category,
          'daysUntilDue': daysUntilDue,
        });
      }
    }
    upcoming.sort((a, b) => (a['dueDate'] as DateTime).compareTo(b['dueDate'] as DateTime));
    return upcoming;
  }

  double get totalIncome => totalIncomeThisMonth;
  double get totalSpent => totalExpensesThisMonth;
  double get netSavings => balanceThisMonth;
  double getSpentForCategory(String category) => getBudgetSpent(category);
  Map<String, double> getCategorySpending() {
    final Map<String, Decimal> spending = {};
    for (final e in getExpensesForSelectedMonth()) {
      spending[e.category] = (spending[e.category] ?? Decimal.zero) + e.amountDecimal;
    }
    return spending.map((k, v) => MapEntry(k, _decimalToDouble(v)));
  }

  List<String> get allExpenseCategoryNames => ({...expenseCategories.map((c) => c.name), ..._expenses.map((e) => e.category)}.toList()..sort());
  List<String> get allIncomeCategoryNames => ({...incomeCategories.map((c) => c.name), ..._incomes.map((i) => i.category)}.toList()..sort());

  Future<List<Expense>> getAllExpensesForBackup() async => await _db.readAllExpenses(currentAccountId);
  Future<List<Income>> getAllIncomesForBackup() async => await _db.readAllIncome(currentAccountId);
  Future<void> closeDatabase() async {
    while (_processingRecurring) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await _db.closeDatabase();
  }
  Future<void> reloadAfterRestore() async { await closeDatabase(); await loadData(); }

  bool _isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
  List<Tag> get allTags => _tags.map((map) => Tag.fromMap(map)).toList();

  // ============== PIN LOCK FUNCTIONALITY ==============

  /// Check if app is currently locked
  bool get isLocked => _isLocked;

  /// Check if PIN protection is enabled (async operation, use carefully)
  Future<bool> isPinEnabled() async {
    return await PinSecurityHelper.isPinEnabled();
  }

  /// Initialize lock state based on PIN settings
  Future<void> initializeLockState() async {
    final pinEnabled = await PinSecurityHelper.isPinEnabled();
    _isLocked = pinEnabled; // Start locked if PIN is enabled
  }

  /// Unlock the app (called after successful PIN verification)
  void unlock() {
    _isLocked = false;
    _startLockTimer();
    notifyListeners();
  }

  /// Lock the app immediately
  void lock() {
    _cancelLockTimer();
    _isLocked = true;
    notifyListeners();
  }

  /// Reset the inactivity timer (call this on user interaction)
  void resetLockTimer() {
    if (!_isLocked) {
      _startLockTimer();
    }
  }

  /// Start or restart the 3-minute inactivity timer
  /// FIX: Added _isDisposed check to prevent calling lock() after dispose
  void _startLockTimer() {
    _cancelLockTimer();
    _lockTimer = Timer(_lockTimeout, () async {
      // FIX: Check if AppState has been disposed before accessing async resources
      if (_isDisposed) return;
      final pinEnabled = await PinSecurityHelper.isPinEnabled();
      // FIX: Check again after async gap in case dispose happened during await
      if (_isDisposed) return;
      if (pinEnabled) {
        lock();
      }
    });
  }

  /// Cancel the lock timer
  void _cancelLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = null;
  }

  @override
  void dispose() {
    _isDisposed = true; // FIX: Set disposed flag before cancelling timer
    _cancelLockTimer();
    super.dispose();
  }
}
