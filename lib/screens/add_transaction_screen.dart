import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/category_model.dart' as cat_model;
import '../models/expense_model.dart';
import '../models/income_model.dart';
import '../models/tag_model.dart';
import '../providers/app_state.dart';
import '../services/onboarding_service.dart';
import '../theme/app_colors.dart';
import '../theme/luminous_app_theme.dart';
import '../utils/category_icons.dart';
import '../utils/currency_helper.dart';
import '../utils/date_helper.dart';
import '../utils/decimal_helper.dart';
import '../utils/dialog_helpers.dart';
import '../utils/validators.dart';
import '../widgets/category_tile.dart';
import '../widgets/luminous/category_bento_grid.dart';
import '../widgets/luminous/glass_panel.dart';
import '../widgets/luminous/glass_segmented_control.dart';
import '../widgets/luminous/glass_top_app_bar.dart';

/// The kind of transaction being entered. Drives both the persistence
/// branch in [_AddTransactionScreenState._save] and the form's
/// type-conditional sections (amount-paid + payment method are
/// expense-only, the category list swaps).
enum TransactionType { expense, income }

/// Phase 5.5 — unified Add Transaction screen. Replaces the legacy
/// `AddHubScreen` (chooser), `AddExpenseScreen` (1,380 lines), and
/// `AddIncomeScreen` (1,033 lines) with a single Luminous-styled form
/// driven by a [GlassSegmentedControl] toggle.
///
/// Used in two contexts:
///   * As the **center tab** of the floating glass nav (`main.dart`) —
///     constructed without a navigator route above it, so
///     `Navigator.canPop` is false. The leading slot stays empty and
///     `_save` resets the form instead of popping.
///   * **Pushed** from Home / History / empty-state callbacks — the
///     leading slot shows a [BackButton] and `_save` pops back to the
///     pushing route, matching the legacy AddExpense / AddIncome UX.
///
/// **R15 mitigation (field state on toggle):** every controller value
/// survives the Expense ↔ Income switch except `_selectedCategory`
/// (lists differ) and `_amountPaid` (expense-only — cleared when
/// toggling to income; one-way). Payment method is preserved
/// internally even though it's hidden on Income.
class AddTransactionScreen extends StatefulWidget {
  /// Which side the segmented control starts on.
  final TransactionType initialType;

  /// Expense being edited. When non-null, [initialType] must be
  /// [TransactionType.expense]; the segmented control is hidden and the
  /// form swaps to "Update Expense".
  final Expense? expense;

  /// Income being edited. When non-null, [initialType] must be
  /// [TransactionType.income].
  final Income? income;

  const AddTransactionScreen({
    super.key,
    this.initialType = TransactionType.expense,
    this.expense,
    this.income,
  })  : assert(expense == null || income == null,
            'Pass at most one of expense/income for edit mode'),
        assert(expense == null || initialType == TransactionType.expense,
            'expense edit must use initialType: expense'),
        assert(income == null || initialType == TransactionType.income,
            'income edit must use initialType: income');

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _categoryNameController = TextEditingController();

  late TransactionType _type;
  String? _selectedCategory;
  String _paymentMethod = 'Cash';
  late DateTime _selectedDate;
  bool _isSaving = false;
  Set<int> _selectedTagIds = {};
  bool _dateInitialized = false;
  bool _showTypeTooltip = false;
  bool _checkedTooltip = false;

  // Initial values for the unsaved-changes guard.
  String? _initialAmount;
  String? _initialDescription;
  String? _initialAmountPaid;
  String? _initialCategory;
  String _initialPaymentMethod = 'Cash';
  DateTime? _initialDate;

  bool get _isEdit => widget.expense != null || widget.income != null;
  bool get _isExpense => _type == TransactionType.expense;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;

    if (widget.expense != null) {
      final e = widget.expense!;
      _amountController.text = e.amount.toString();
      _descriptionController.text = e.description;
      _amountPaidController.text = e.amountPaid.toString();
      _selectedCategory = e.category;
      _paymentMethod = e.paymentMethod;
      _selectedDate = e.date;
      _initialDate = e.date;
      _initialAmount = e.amount.toString();
      _initialDescription = e.description;
      _initialAmountPaid = e.amountPaid.toString();
      _initialCategory = e.category;
      _initialPaymentMethod = e.paymentMethod;
      _loadExistingTags();
    } else if (widget.income != null) {
      final i = widget.income!;
      _amountController.text = i.amount.toString();
      _descriptionController.text = i.description;
      _selectedCategory = i.category;
      _selectedDate = i.date;
      _initialDate = i.date;
      _initialAmount = i.amount.toString();
      _initialDescription = i.description;
      _initialCategory = i.category;
      _loadExistingTags();
    } else {
      _amountPaidController.text = '0';
      _initialAmount = '';
      _initialDescription = '';
      _initialAmountPaid = '0';
      _initialCategory = null;
      _initialPaymentMethod = _paymentMethod;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_dateInitialized && !_isEdit) {
      final appState = context.read<AppState>();
      final selectedMonth = appState.selectedMonth;
      final now = DateTime.now();
      // Default to today if the month being viewed is the current one;
      // otherwise default to the first of that month so the entry lands
      // in the visible month without further user action.
      if (selectedMonth.year == now.year && selectedMonth.month == now.month) {
        _selectedDate = DateHelper.today();
      } else {
        _selectedDate = DateHelper.startOfMonth(selectedMonth);
      }
      _initialDate = _selectedDate;
      _dateInitialized = true;
    }

    if (!_checkedTooltip && !_isEdit) {
      _checkedTooltip = true;
      _maybeShowFirstLaunchTooltip();
    }
  }

  Future<void> _maybeShowFirstLaunchTooltip() async {
    final seen = await OnboardingService().hasSeenAddTransactionTooltip();
    if (!mounted || seen) return;
    setState(() => _showTypeTooltip = true);
  }

  Future<void> _dismissTooltip() async {
    if (!_showTypeTooltip) return;
    setState(() => _showTypeTooltip = false);
    await OnboardingService().markAddTransactionTooltipSeen();
  }

  Future<void> _loadExistingTags() async {
    final id = widget.expense?.id ?? widget.income?.id;
    if (id == null) return;
    final appState = context.read<AppState>();
    final type = widget.expense != null ? 'expense' : 'income';
    final tags = await appState.getTagsForTransaction(id, type);
    if (!mounted) return;
    setState(() => _selectedTagIds = tags.map((t) => t.id!).toSet());
  }

  bool _isFormDirty() {
    final amountDirty = _amountController.text != _initialAmount;
    final descDirty = _descriptionController.text != _initialDescription;
    final categoryDirty = _selectedCategory != _initialCategory;
    final dateDirty = _selectedDate != _initialDate;
    if (_isExpense) {
      return amountDirty ||
          descDirty ||
          categoryDirty ||
          dateDirty ||
          _amountPaidController.text != _initialAmountPaid ||
          _paymentMethod != _initialPaymentMethod;
    }
    return amountDirty || descDirty || categoryDirty || dateDirty;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _amountPaidController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  void _onTypeChanged(TransactionType v) {
    if (v == _type) return;
    // R15: shared fields (amount, description, date, tags, payment method)
    // survive the toggle. Only _category swaps (lists differ) and
    // _amountPaid clears (expense-only field has no income analog).
    setState(() {
      _type = v;
      _selectedCategory = null;
      if (v == TransactionType.income) {
        _amountPaidController.clear();
      } else {
        // Toggling back to expense restores the default amount-paid hint
        // so the field is not silently empty when the user starts typing.
        if (_amountPaidController.text.isEmpty) {
          _amountPaidController.text = '0';
        }
      }
    });
    _dismissTooltip();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (Validators.isFutureDate(_selectedDate)) {
      final confirmed = await DialogHelpers.showFutureDateConfirmation(
        context,
        _selectedDate,
      );
      if (!confirmed) return;
    }

    HapticFeedback.mediumImpact();
    if (!mounted) return;

    final appState = context.read<AppState>();
    final appColors = Theme.of(context).extension<AppColors>()!;
    final amount = CurrencyHelper.parseDecimal(_amountController.text);
    if (amount == null) return; // Validator should have caught this.

    // Expense-only budget warning. Income has no budgets.
    if (_isExpense) {
      final budgetWarning = _checkBudgetWarning(appState, amount);
      if (budgetWarning != null && mounted) {
        final proceed = await _showBudgetWarningDialog(budgetWarning);
        if (!proceed) return;
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      final activeCategories = _isExpense
          ? appState.expenseCategories
          : appState.incomeCategories;
      if (_selectedCategory == null ||
          !activeCategories.any((c) => c.name == _selectedCategory)) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please select a valid ${_isExpense ? "expense" : "income"} category.',
              ),
              backgroundColor: appColors.expenseRed,
            ),
          );
        }
        return;
      }

      final category = _selectedCategory!;
      final rawDescription = _descriptionController.text.trim();
      final description = rawDescription.isEmpty
          ? '$category ${_isExpense ? "expense" : "income"}'
          : CurrencyHelper.sanitizeText(rawDescription, maxLength: 200);

      int? savedId;
      String txType;
      if (_isExpense) {
        final amountPaidText = _amountPaidController.text.trim();
        final amountPaid = amountPaidText.isEmpty
            ? 0.0
            : (CurrencyHelper.parseDecimal(amountPaidText) ?? 0.0);
        final expense = Expense(
          id: widget.expense?.id,
          amount: DecimalHelper.fromDouble(amount),
          category: category,
          description: description,
          date: _selectedDate,
          accountId: appState.currentAccountId,
          amountPaid: DecimalHelper.fromDouble(amountPaid),
          paymentMethod: _paymentMethod,
        );
        if (widget.expense == null) {
          savedId = await appState.addExpense(expense);
        } else {
          await appState.updateExpense(expense);
          savedId = expense.id;
        }
        txType = 'expense';
      } else {
        final income = Income(
          id: widget.income?.id,
          amount: DecimalHelper.fromDouble(amount),
          category: category,
          description: description,
          date: _selectedDate,
          accountId: appState.currentAccountId,
        );
        if (widget.income == null) {
          savedId = await appState.addIncome(income);
        } else {
          await appState.updateIncome(income);
          savedId = income.id;
        }
        txType = 'income';
      }

      if (savedId != null) {
        await _syncTags(appState, savedId, txType);
      }

      if (!mounted) return;

      final currentViewedMonth = appState.selectedMonth;
      final isDifferentMonth =
          _selectedDate.month != currentViewedMonth.month ||
              _selectedDate.year != currentViewedMonth.year;

      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final canPop = navigator.canPop();
      final saveLabel = _isExpense ? 'Expense' : 'Income';
      final monthName = DateFormat.MMMM().format(_selectedDate);

      // Build the success snackbar BEFORE popping so the captured
      // [messenger] (which lives on the root MaterialApp's State and
      // outlives this route) can show it after the pop unmounts us.
      final SnackBar snack = isDifferentMonth
          ? SnackBar(
              content: Text('$saveLabel saved to $monthName'),
              action: SnackBarAction(
                label: 'Switch to $monthName',
                onPressed: () => appState.goToMonth(_selectedDate),
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            )
          : SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    _isEdit ? '$saveLabel updated' : '$saveLabel added',
                  ),
                ],
              ),
              backgroundColor: appColors.incomeGreen,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            );

      if (canPop) {
        navigator.pop();
      } else if (mounted) {
        _resetForm();
      }
      messenger.showSnackBar(snack);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: appColors.expenseRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncTags(AppState appState, int id, String type) async {
    final existingTags = await appState.getTagsForTransaction(id, type);
    final existingTagIds = existingTags.map((t) => t.id!).toSet();
    for (final tagId in _selectedTagIds) {
      if (!existingTagIds.contains(tagId)) {
        await appState.addTagToTransaction(id, type, tagId);
      }
    }
    for (final tagId in existingTagIds) {
      if (!_selectedTagIds.contains(tagId)) {
        await appState.removeTagFromTransaction(id, type, tagId);
      }
    }
  }

  /// Reset the form to its "blank new transaction" state after a save
  /// while embedded as the center nav tab — there is no parent route to
  /// pop to, so we wipe the controllers and refresh the initial-values
  /// snapshot so the dirty guard reports "clean" until the user types.
  void _resetForm() {
    final appState = context.read<AppState>();
    final selectedMonth = appState.selectedMonth;
    final now = DateTime.now();
    final newDate =
        (selectedMonth.year == now.year && selectedMonth.month == now.month)
            ? DateHelper.today()
            : DateHelper.startOfMonth(selectedMonth);
    setState(() {
      _amountController.clear();
      _descriptionController.clear();
      _amountPaidController.text = _isExpense ? '0' : '';
      _selectedCategory = null;
      _selectedTagIds = {};
      _selectedDate = newDate;
      _paymentMethod = 'Cash';
      _initialAmount = '';
      _initialDescription = '';
      _initialAmountPaid = _isExpense ? '0' : '';
      _initialCategory = null;
      _initialPaymentMethod = 'Cash';
      _initialDate = newDate;
    });
  }

  Map<String, dynamic>? _checkBudgetWarning(AppState appState, double amount) {
    if (_selectedCategory == null) return null;
    final budgets = appState.budgets
        .where((b) =>
            b.category == _selectedCategory &&
            b.month.year == _selectedDate.year &&
            b.month.month == _selectedDate.month)
        .toList();
    if (budgets.isEmpty) return null;
    final budget = budgets.first;

    final expensesInMonth = appState.expenses
        .where((e) =>
            e.category == _selectedCategory &&
            e.date.year == _selectedDate.year &&
            e.date.month == _selectedDate.month)
        .toList();
    var currentSpent =
        expensesInMonth.fold<double>(0.0, (sum, e) => sum + e.amount);
    if (widget.expense != null &&
        widget.expense!.category == _selectedCategory &&
        widget.expense!.date.year == _selectedDate.year &&
        widget.expense!.date.month == _selectedDate.month) {
      currentSpent -= widget.expense!.amount;
    }

    final newTotal = currentSpent + amount;
    final budgetAmount = budget.amount;
    if (newTotal > budgetAmount) {
      return {
        'type': 'exceed',
        'budgetAmount': budgetAmount,
        'currentSpent': currentSpent,
        'newTotal': newTotal,
        'overBy': newTotal - budgetAmount,
        'category': _selectedCategory,
      };
    } else if (newTotal > budgetAmount * 0.9) {
      return {
        'type': 'approaching',
        'budgetAmount': budgetAmount,
        'currentSpent': currentSpent,
        'newTotal': newTotal,
        'percentage': (newTotal / budgetAmount * 100).round(),
        'category': _selectedCategory,
      };
    }
    return null;
  }

  Future<bool> _showBudgetWarningDialog(Map<String, dynamic> warning) async {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final appState = context.read<AppState>();
    final isExceed = warning['type'] == 'exceed';
    final categoryName = warning['category'] as String;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isExceed
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline,
                  color: isExceed
                      ? appColors.warningOrange
                      : appColors.infoBlue,
                ),
                const SizedBox(width: 12),
                Text(isExceed ? 'Budget Exceeded' : 'Budget Warning',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (isExceed
                        ? appColors.warningOrange
                        : appColors.infoBlue)
                    .withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isExceed
                          ? appColors.warningOrange
                          : appColors.infoBlue)
                      .withAlpha(100),
                ),
              ),
              child: Text(
                categoryName.toUpperCase(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: isExceed
                      ? appColors.warningOrange
                      : appColors.infoBlue,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For ${DateFormat.MMMM().format(_selectedDate)}:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (isExceed)
              Text(
                'This expense will exceed your ${warning['category']} budget by ${appState.currency}${(warning['overBy'] as double).toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              )
            else
              Text(
                'This expense will use ${warning['percentage']}% of your ${warning['category']} budget.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isExceed
                  ? appColors.warningOrange
                  : theme.colorScheme.primary,
            ),
            child: Text(isExceed ? 'Add Anyway' : 'Continue'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _deleteTransaction() async {
    if (!_isEdit) return;
    HapticFeedback.lightImpact();
    final appColors = Theme.of(context).extension<AppColors>()!;
    final label = _isExpense ? 'Expense' : 'Income';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $label'),
        content: Text('Are you sure you want to delete this $label?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: appColors.expenseRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final appState = context.read<AppState>();
    if (_isExpense && widget.expense?.id != null) {
      await appState.deleteExpense(widget.expense!.id!);
    } else if (!_isExpense && widget.income?.id != null) {
      await appState.deleteIncome(widget.income!.id!);
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
            '${_isExpense ? "Expense" : "Income"} moved to trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => appState.undoDelete(),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final minDate = Validators.getTransactionMinDate();
    final maxDate = Validators.getTransactionMaxDate();
    final initial = _selectedDate.isAfter(maxDate)
        ? now
        : (_selectedDate.isBefore(minDate) ? now : _selectedDate);

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: maxDate,
      helpText: 'Select Transaction Date',
    );
    if (date == null || !mounted) return;

    if (DateHelper.isFuture(date)) {
      final confirmed = await DialogHelpers.showFutureDateConfirmation(
        context,
        date,
      );
      if (!confirmed) return;
    }
    if (!mounted) return;
    setState(() => _selectedDate = DateHelper.normalize(date));
  }

  Future<void> _markFullyPaid() async {
    if (!_isExpense || widget.expense == null) return;
    final appColors = Theme.of(context).extension<AppColors>()!;
    setState(() => _isSaving = true);
    try {
      final amount = CurrencyHelper.parseDecimal(_amountController.text) ??
          widget.expense!.amount;
      final appState = context.read<AppState>();
      final updated = widget.expense!.copyWith(
        amountPaid: amount,
      );
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      await appState.updateExpense(updated);
      if (!mounted) return;
      if (navigator.canPop()) navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Marked as fully paid'),
          backgroundColor: appColors.incomeGreen,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: appColors.expenseRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showCreateCategoryDialog() async {
    final appState = context.read<AppState>();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: _categoryNameController,
            autofocus: true,
            maxLength: 50,
            decoration: InputDecoration(
              hintText: 'Category name',
              border: const OutlineInputBorder(),
              helperText: 'Max 50 characters',
              helperStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a category name';
              }
              if (value.trim().length > 50) {
                return 'Category name cannot exceed 50 characters';
              }
              final existing = _isExpense
                  ? appState.expenseCategories
                  : appState.incomeCategories;
              if (existing.any((c) =>
                  c.name.toLowerCase() == value.trim().toLowerCase())) {
                return 'This category already exists';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && _categoryNameController.text.trim().isNotEmpty) {
      final name = _categoryNameController.text.trim();
      if (!mounted) return;
      await appState.addCategory(name,
          type: _isExpense ? 'expense' : 'income');
      if (!mounted) return;
      setState(() => _selectedCategory = name);
      _categoryNameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category "$name" created'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showCreateTagDialog() async {
    final appState = context.read<AppState>();
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Tag'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 50,
            decoration: const InputDecoration(
              hintText: 'Tag name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a tag name';
              }
              if (value.trim().length > 50) {
                return 'Tag name cannot exceed 50 characters';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final tagName = controller.text.trim();
    controller.dispose();
    if (result == true && tagName.isNotEmpty) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      await appState.addTag(tagName);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Tag "$tagName" created'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;

    // Phase 2.5 lint forbids a global AppState watch because every
    // unrelated `notifyListeners` would rebuild this whole form. Narrow
    // to the three slices the UI actually displays via context.select.
    final categories = context.select<AppState, List<cat_model.Category>>(
      (s) => _isExpense ? s.expenseCategories : s.incomeCategories,
    );
    final currency = context.select<AppState, String>((s) => s.currency);
    final allTags = context.select<AppState, List<Tag>>((s) => s.allTags);

    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = categories[0].name;
      _initialCategory ??= _selectedCategory;
    }

    final canPop = Navigator.canPop(context);
    final saveLabel = _isEdit
        ? 'Update ${_isExpense ? "Expense" : "Income"}'
        : 'Add ${_isExpense ? "Expense" : "Income"}';

    return PopScope(
      canPop: !_isFormDirty(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text(
                'You have unsaved changes. Are you sure you want to discard them?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style:
                    TextButton.styleFrom(foregroundColor: appColors.expenseRed),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (shouldDiscard == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassTopAppBar(
              title: _isEdit
                  ? (_isExpense ? 'Edit Expense' : 'Edit Income')
                  : 'Add Transaction',
              leading: canPop ? const BackButton() : null,
              actions: _isEdit
                  ? [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _isSaving ? null : _deleteTransaction,
                        tooltip: 'Delete',
                      ),
                    ]
                  : const [],
            ),
            if (!_isEdit)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LuminousTokens.containerPadding,
                  LuminousTokens.stackGap,
                  LuminousTokens.containerPadding,
                  LuminousTokens.basePx,
                ),
                child: GlassSegmentedControl<TransactionType>(
                  values: const [
                    TransactionType.expense,
                    TransactionType.income,
                  ],
                  labels: const ['Expense', 'Income'],
                  selected: _type,
                  onChanged: _onTypeChanged,
                ),
              ),
            if (_showTypeTooltip && !_isEdit)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LuminousTokens.containerPadding,
                  0,
                  LuminousTokens.containerPadding,
                  LuminousTokens.basePx,
                ),
                child: GlassPanel(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Switch between Expense and Income at the top — '
                          'amount and notes survive the toggle.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: _dismissTooltip,
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  LuminousTokens.containerPadding,
                  LuminousTokens.basePx,
                  LuminousTokens.containerPadding,
                  120 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAmountCard(theme, currency),
                      const SizedBox(height: 16),
                      _buildCategoryCard(theme, categories),
                      const SizedBox(height: 16),
                      _buildDescriptionAndDateCard(theme, appColors),
                      if (_isExpense) ...[
                        const SizedBox(height: 16),
                        _buildPaymentCard(theme),
                        const SizedBox(height: 16),
                        _buildAmountPaidCard(theme, appColors, currency),
                      ],
                      const SizedBox(height: 16),
                      _buildTagsCard(theme, allTags),
                      if (_isExpense &&
                          widget.expense != null &&
                          !widget.expense!.isPaid) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _markFullyPaid,
                          icon: Icon(Icons.check_circle_outline,
                              color: appColors.incomeGreen),
                          label: Text(
                            'Mark as Fully Paid',
                            style: TextStyle(color: appColors.incomeGreen),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: appColors.incomeGreen),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              LuminousTokens.containerPadding,
              LuminousTokens.basePx,
              LuminousTokens.containerPadding,
              LuminousTokens.basePx,
            ),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isExpense
                    ? theme.colorScheme.onSurface
                    : appColors.incomeGreen,
                foregroundColor:
                    _isExpense ? theme.colorScheme.surface : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(saveLabel, style: theme.textTheme.titleMedium),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard(ThemeData theme, String currency) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AMOUNT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [CurrencyHelper.decimalInputFormatter()],
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
            decoration: InputDecoration(
              prefixText: currency,
              prefixStyle:
                  const TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
              hintText: '0.00',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
              final parsed = CurrencyHelper.parseDecimal(value);
              if (parsed == null) return 'Please enter a valid number';
              if (parsed <= 0) return 'Amount must be greater than 0';
              if (parsed > 999999999.99) {
                return 'Amount cannot exceed 999,999,999.99';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
      ThemeData theme, List<cat_model.Category> categories) {
    final type = _isExpense ? 'expense' : 'income';
    final items = [
      // Archived category placeholder when editing a transaction whose
      // category was deleted — preserves the historical attribution.
      // Label kept to the bare name so it fits the bento cell; the
      // archive icon + error tint signal the archived state.
      if (_isEdit &&
          _selectedCategory != null &&
          !categories.any((c) => c.name == _selectedCategory))
        CategoryBentoItem(
          id: '__archived__$_selectedCategory',
          label: _selectedCategory!,
          icon: Icons.archive_outlined,
          color: theme.colorScheme.error,
        ),
      ...categories.map((c) => CategoryBentoItem(
            id: c.name,
            label: c.name,
            icon: CategoryIcons.getIcon(c.icon, c.name, type),
            color: CategoryColors.getDefaultColor(c.name, type),
          )),
    ];

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CATEGORY',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              TextButton.icon(
                onPressed: _showCreateCategoryDialog,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('New'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No ${_isExpense ? "expense" : "income"} categories yet — tap New to add one.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            CategoryBentoGrid(
              items: items,
              selectedId: _selectedCategory,
              onSelected: (id) {
                if (id is String && !id.startsWith('__archived__')) {
                  setState(() => _selectedCategory = id);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDescriptionAndDateCard(
      ThemeData theme, AppColors appColors) {
    final descLen = _descriptionController.text.length;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DESCRIPTION (OPTIONAL)',
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 200,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Add notes (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
              counterText: '$descLen/200',
              counterStyle: TextStyle(
                color: descLen > 180
                    ? appColors.warningOrange
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'DATE',
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      DateFormat.yMMMMEEEEd().format(_selectedDate),
                      style: theme.textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(ThemeData theme) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAYMENT METHOD',
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Cash', 'Credit', 'Debit', 'Other'].map((method) {
              final isSelected = _paymentMethod == method;
              return ChoiceChip(
                label: Text(method),
                selected: isSelected,
                onSelected: (_) => setState(() => _paymentMethod = method),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                selectedColor: theme.colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountPaidCard(
      ThemeData theme, AppColors appColors, String currency) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AMOUNT PAID (OPTIONAL)',
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Track partial payments (e.g., credit card). Leave at 0 if unpaid.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountPaidController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [CurrencyHelper.decimalInputFormatter()],
            decoration: InputDecoration(
              prefixText: currency,
              hintText: '0.00',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            validator: (value) {
              if (!_isExpense) return null;
              if (value == null || value.isEmpty) return null;
              final amountPaid = CurrencyHelper.parseDecimal(value);
              if (amountPaid == null) return 'Please enter a valid number';
              final total =
                  CurrencyHelper.parseDecimal(_amountController.text) ?? 0;
              if (amountPaid < 0) return 'Amount paid cannot be negative';
              if (amountPaid > total) {
                return 'Amount paid cannot exceed total amount';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTagsCard(ThemeData theme, List<Tag> allTags) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TAGS (OPTIONAL)',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              TextButton.icon(
                onPressed: _showCreateTagDialog,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('New'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (allTags.isEmpty)
            Text(
              'No tags yet — tap New to label your transactions.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allTags.map((tag) {
                final isSelected = _selectedTagIds.contains(tag.id);
                return FilterChip(
                  label: Text(tag.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTagIds.add(tag.id!);
                      } else {
                        _selectedTagIds.remove(tag.id);
                      }
                    });
                  },
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  selectedColor:
                      theme.colorScheme.primary.withAlpha((255 * 0.2).round()),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
