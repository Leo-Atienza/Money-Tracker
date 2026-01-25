// FIX #49: Centralized database constants to avoid magic strings throughout the codebase
// This prevents typos and provides compile-time checking

class DatabaseConstants {
  // Database metadata
  static const String databaseName = 'expense_tracker_v4.db';
  static const int databaseVersion = 12;

  // Table names
  static const String tableAccounts = 'accounts';
  static const String tableExpenses = 'expenses';
  static const String tableIncome = 'income';
  static const String tableBudgets = 'budgets';
  static const String tableRecurringExpenses = 'recurring_expenses';
  static const String tableRecurringIncome = 'recurring_income';
  static const String tableCategories = 'categories';
  static const String tableDeletedExpenses = 'deleted_expenses';
  static const String tableDeletedIncome = 'deleted_income';
  static const String tableDeletedAccounts = 'deleted_accounts';
  static const String tableQuickTemplates = 'quick_templates';
  static const String tableTags = 'tags';
  static const String tableTransactionTags = 'transaction_tags';

  // Common column names
  static const String columnId = 'id';
  static const String columnAmount = 'amount';
  static const String columnCategory = 'category';
  static const String columnDescription = 'description';
  static const String columnDate = 'date';
  static const String columnAccountId = 'account_id';
  static const String columnName = 'name';
  static const String columnIsDefault = 'isDefault';
  static const String columnIsActive = 'isActive';
  static const String columnType = 'type';
  static const String columnDeletedAt = 'deletedAt';
  static const String columnOriginalId = 'original_id';

  // Expense-specific columns
  static const String columnAmountPaid = 'amountPaid';
  static const String columnPaymentMethod = 'paymentMethod';

  // Recurring-specific columns
  static const String columnDayOfMonth = 'dayOfMonth';
  static const String columnLastCreated = 'lastCreated';
  static const String columnEndDate = 'endDate';
  static const String columnMaxOccurrences = 'maxOccurrences';
  static const String columnOccurrenceCount = 'occurrenceCount';
  static const String columnFrequency = 'frequency';
  static const String columnStartDate = 'startDate';

  // Account-specific columns
  static const String columnIcon = 'icon';
  static const String columnColor = 'color';
  static const String columnCurrencyCode = 'currencyCode';

  // Budget-specific columns
  static const String columnMonth = 'month';

  // Template-specific columns
  static const String columnSortOrder = 'sortOrder';

  // Transaction type values
  static const String typeExpense = 'expense';
  static const String typeIncome = 'income';

  // Payment method values
  static const String paymentCash = 'Cash';
  static const String paymentCard = 'Card';
  static const String paymentBank = 'Bank Transfer';
  static const String paymentDigital = 'Digital Wallet';

  DatabaseConstants._(); // Prevent instantiation
}
