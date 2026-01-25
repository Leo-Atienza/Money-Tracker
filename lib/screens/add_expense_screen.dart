import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/expense_model.dart';
import '../utils/currency_helper.dart';
import '../utils/decimal_helper.dart';
import '../utils/validators.dart';
import '../utils/dialog_helpers.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense;

  const AddExpenseScreen({super.key, this.expense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _categoryNameController = TextEditingController(); // FIX #34: For inline category creation

  // FIX: Don't hardcode category - will be set in initState from available categories
  String? _selectedCategory;
  String _paymentMethod = 'Cash';
  // FIX: Will be set in initState to use selectedMonth from AppState (not today)
  late DateTime _selectedDate;
  bool _isSaving = false;
  Set<int> _selectedTagIds = {}; // FIX: Track selected tags

  // FIX: Track initial date to detect month changes
  DateTime? _initialDate;

  // FIX: Track initial values to detect form changes
  String? _initialAmount;
  String? _initialDescription;
  String? _initialAmountPaid;
  String? _initialCategory;
  String? _initialPaymentMethod;

  // FIX #12: Track success animation state
  // REMOVED: _showSuccessAnimation - replaced with SnackBar feedback

  @override
  void initState() {
    super.initState();

    if (widget.expense != null) {
      _amountController.text = widget.expense!.amount.toString();
      _descriptionController.text = widget.expense!.description;
      _amountPaidController.text = widget.expense!.amountPaid.toString();
      _selectedCategory = widget.expense!.category;
      _paymentMethod = widget.expense!.paymentMethod;
      _selectedDate = widget.expense!.date;
      _initialDate = widget.expense!.date; // FIX: Remember initial date
      // FIX: Remember initial values
      _initialAmount = widget.expense!.amount.toString();
      _initialDescription = widget.expense!.description;
      _initialAmountPaid = widget.expense!.amountPaid.toString();
      _initialCategory = widget.expense!.category;
      _initialPaymentMethod = widget.expense!.paymentMethod;
      // FIX: Load existing tags
      _loadExistingTags();
    } else {
      // FIX: For new expenses, use selectedMonth from AppState (not today)
      // This ensures expenses default to the month being viewed, not current date
      // Date will be set in didChangeDependencies when we have access to AppState
      _amountPaidController.text = '0';
      // FIX: For new expenses, empty is the initial state
      _initialAmount = '';
      _initialDescription = '';
      _initialAmountPaid = '0';
      _initialCategory = null; // Will be set to first available category
      _initialPaymentMethod = _paymentMethod;
    }
  }

  bool _dateInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // FIX: Initialize date from AppState selectedMonth for new expenses
    if (!_dateInitialized && widget.expense == null) {
      final appState = context.read<AppState>();
      final selectedMonth = appState.selectedMonth;
      // Default to first day of selected month at noon for consistent sorting
      _selectedDate = DateTime(selectedMonth.year, selectedMonth.month, 1, 12, 0, 0);
      _initialDate = _selectedDate;
      _dateInitialized = true;
    }
  }

  // FIX: Load tags for existing expense
  Future<void> _loadExistingTags() async {
    if (widget.expense?.id != null) {
      final appState = context.read<AppState>();
      final tags = await appState.getTagsForTransaction(widget.expense!.id!, 'expense');
      setState(() {
        _selectedTagIds = tags.map((tag) => tag.id!).toSet();
      });
    }
  }

  // FIX: Check if form has been modified
  bool _isFormDirty() {
    return _amountController.text != _initialAmount ||
        _descriptionController.text != _initialDescription ||
        _amountPaidController.text != _initialAmountPaid ||
        _selectedCategory != _initialCategory ||
        _paymentMethod != _initialPaymentMethod ||
        _selectedDate != _initialDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _amountPaidController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    // FIX #16: Check for future date and show confirmation
    if (Validators.isFutureDate(_selectedDate)) {
      final confirmed = await DialogHelpers.showFutureDateConfirmation(
        context,
        _selectedDate,
      );
      if (!confirmed) return;
    }

    // FIX #17: Add haptic feedback
    HapticFeedback.mediumImpact();

    if (!mounted) return;

    final appState = context.read<AppState>();
    final amount = CurrencyHelper.parseDecimal(_amountController.text)!;

    // Check budget before saving (for both new and edited expenses)
    final budgetWarning = _checkBudgetWarning(appState, amount);
    if (budgetWarning != null && mounted) {
      final proceed = await _showBudgetWarningDialog(budgetWarning);
      if (!proceed) return;
    }

    setState(() => _isSaving = true);

    try {
      final amountPaidText = _amountPaidController.text.trim();
      final amountPaid = amountPaidText.isEmpty ? 0.0 : (CurrencyHelper.parseDecimal(amountPaidText) ?? 0.0);

      // CRITICAL FIX: Validate category exists before saving
      // If all categories were deleted while form was open, offer to navigate to category manager
      if (_selectedCategory == null || !appState.expenseCategories.any((cat) => cat.name == _selectedCategory)) {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please select a valid category. The selected category may have been deleted.'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Add Category',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pop(context); // Close add expense screen
                  // Navigate to settings would be ideal but requires navigation refactoring
                  // User will need to go to Settings → Categories manually
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final category = _selectedCategory!;
      // CRITICAL FIX: Sanitize description input before database storage
      final rawDescription = _descriptionController.text.trim();
      final description = rawDescription.isEmpty
          ? '$category expense'
          : CurrencyHelper.sanitizeText(rawDescription, maxLength: 200);

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

      int? expenseId;
      if (widget.expense == null) {
        expenseId = await appState.addExpense(expense);
      } else {
        await appState.updateExpense(expense);
        expenseId = expense.id;
      }

      // FIX: Save tags for this expense
      if (expenseId != null) {
        // Get existing tags to compare
        final existingTags = await appState.getTagsForTransaction(expenseId, 'expense');
        final existingTagIds = existingTags.map((t) => t.id!).toSet();

        // Add new tags
        for (final tagId in _selectedTagIds) {
          if (!existingTagIds.contains(tagId)) {
            await appState.addTagToTransaction(expenseId, 'expense', tagId);
          }
        }

        // Remove unselected tags
        for (final tagId in existingTagIds) {
          if (!_selectedTagIds.contains(tagId)) {
            await appState.removeTagFromTransaction(expenseId, 'expense', tagId);
          }
        }
      }

      // CRITICAL FIX: Use SnackBar instead of blocking overlay for success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(widget.expense == null ? 'Expense added successfully' : 'Expense updated successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // FIX: Show feedback if saved to different month than currently viewed
      final currentViewedMonth = appState.selectedMonth;
      final isDifferentMonth = _selectedDate.month != currentViewedMonth.month ||
          _selectedDate.year != currentViewedMonth.year;

      if (mounted && isDifferentMonth) {
        final monthName = DateFormat.MMMM().format(_selectedDate);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense saved to $monthName (not visible in current month)'),
            action: SnackBarAction(
              label: 'Switch to $monthName',
              onPressed: () {
                appState.goToMonth(_selectedDate);
              },
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Map<String, dynamic>? _checkBudgetWarning(AppState appState, double amount) {
    // FIX: Handle null category
    if (_selectedCategory == null) return null;

    // FIX #47: Find budget for selected category in the EXPENSE's month (not current month)
    final budgets = appState.budgets.where((b) =>
        b.category == _selectedCategory &&
        b.month.year == _selectedDate.year &&
        b.month.month == _selectedDate.month).toList();

    if (budgets.isEmpty) return null;

    final budget = budgets.first;

    // CRITICAL FIX: Calculate budget spent without changing app state to avoid race conditions
    // Query expenses directly for the expense's month instead of temporarily switching months
    final expensesInMonth = appState.expenses.where((e) =>
        e.category == _selectedCategory &&
        e.date.year == _selectedDate.year &&
        e.date.month == _selectedDate.month).toList();
    var currentSpent = expensesInMonth.fold<double>(0.0, (sum, e) => sum + e.amount);

    // When editing, subtract the original expense amount if it was in the same category and month
    if (widget.expense != null &&
        widget.expense!.category == _selectedCategory &&
        widget.expense!.date.year == _selectedDate.year &&
        widget.expense!.date.month == _selectedDate.month) {
      currentSpent -= widget.expense!.amount;
    }

    final newTotal = currentSpent + amount;
    final budgetAmount = budget.amount;

    if (newTotal > budgetAmount) {
      final overBy = newTotal - budgetAmount;
      return {
        'type': 'exceed',
        'budgetAmount': budgetAmount,
        'currentSpent': currentSpent,
        'newTotal': newTotal,
        'overBy': overBy,
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
    final appState = context.read<AppState>();
    final isExceed = warning['type'] == 'exceed';
    final categoryName = warning['category'] as String;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        // FIX #16: Make category name prominent in title
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isExceed ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: isExceed ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 12),
                Text(
                  isExceed ? 'Budget Exceeded' : 'Budget Warning',
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (isExceed ? Colors.orange : Colors.blue).withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isExceed ? Colors.orange : Colors.blue).withAlpha(100),
                ),
              ),
              child: Text(
                categoryName.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: isExceed ? Colors.orange : Colors.blue,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CRITICAL FIX: Clarify which month's budget is being checked
            Text(
              'For ${DateFormat.MMMM().format(_selectedDate)}:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (isExceed) ...[
              Text(
                'This expense will exceed your ${warning['category']} budget by ${appState.currency}${(warning['overBy'] as double).toStringAsFixed(2)}',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _buildBudgetProgressBar(warning, theme, appState),
            ] else ...[
              Text(
                'This expense will use ${warning['percentage']}% of your ${warning['category']} budget.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _buildBudgetProgressBar(warning, theme, appState),
            ],
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
              foregroundColor: isExceed ? Colors.orange : theme.colorScheme.primary,
            ),
            child: Text(isExceed ? 'Add Anyway' : 'Continue'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget _buildBudgetProgressBar(Map<String, dynamic> warning, ThemeData theme, AppState appState) {
    final budgetAmount = warning['budgetAmount'] as double;
    final newTotal = warning['newTotal'] as double;
    final progress = (newTotal / budgetAmount).clamp(0.0, 1.5);
    final isExceed = warning['type'] == 'exceed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'After this expense:',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
            Text(
              '${appState.currency}${newTotal.toStringAsFixed(2)} / ${appState.currency}${budgetAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isExceed ? Colors.orange : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress > 1 ? 1 : progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: isExceed ? Colors.orange : Colors.blue,
          ),
        ),
        if (isExceed) ...[
          const SizedBox(height: 4),
          Text(
            '${((progress) * 100).round()}% of budget',
            style: const TextStyle(fontSize: 11, color: Colors.orange),
          ),
        ],
      ],
    );
  }

  Future<void> _deleteExpense() async {
    if (widget.expense == null) return;

    // FIX #17: Add haptic feedback
    HapticFeedback.lightImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      await appState.deleteExpense(widget.expense!.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Expense moved to trash'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await appState.undoDelete();
              },
            ),
          ),
        );
      }
    }
  }

  // FIX: Show dialog to create a new tag
  Future<void> _showCreateTagDialog(BuildContext context, AppState appState) async {
    final tagNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Tag'),
        content: StatefulBuilder(
          builder: (context, setState) => Form(
            key: formKey,
            child: TextFormField(
              controller: tagNameController,
              autofocus: true,
              maxLength: 50,
              onChanged: (value) {
                // FIX #13: Trigger rebuild to update character counter
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Tag name',
                border: const OutlineInputBorder(),
                counterText: '${tagNameController.text.length}/50',
                counterStyle: TextStyle(
                  color: tagNameController.text.length > 45
                      ? Colors.orange
                      : null,
                ),
                helperText: 'Max 50 characters',
                helperStyle: const TextStyle(fontSize: 11),
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

    // FIX: Get the tag name before disposing controller to avoid "used after dispose" error
    final tagName = tagNameController.text.trim();
    tagNameController.dispose();

    if (result == true && tagName.isNotEmpty) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
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

  // FIX #34: Show dialog to create a new category with name length validation
  Future<void> _showCreateCategoryDialog(BuildContext context, AppState appState) async {
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
              helperStyle: TextStyle(
                fontSize: 11,
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
              // Check for duplicate category
              if (appState.expenseCategories.any((cat) => cat.name.toLowerCase() == value.trim().toLowerCase())) {
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
      final categoryName = _categoryNameController.text.trim();
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      final messenger = ScaffoldMessenger.of(context);
      await appState.addCategory(categoryName, type: 'expense');
      if (!mounted) return;
      setState(() {
        _selectedCategory = categoryName;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Category "$categoryName" created'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _categoryNameController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // CRITICAL FIX: Optimize rebuilds - only watch specific fields needed
    final expenseCategories = context.select<AppState, List<dynamic>>((s) => s.expenseCategories);
    // Use read() for one-time access in callbacks to avoid unnecessary rebuilds
    final appState = context.read<AppState>();

    // FIX: Set default category to first available if not set (prevents ghost categories)
    final availableCategories = expenseCategories;
    if (_selectedCategory == null && availableCategories.isNotEmpty) {
      _selectedCategory = availableCategories[0].name;
      _initialCategory = _selectedCategory;
    }

    // FIX: Wrap with PopScope to warn about unsaved changes
    return PopScope(
      canPop: !_isFormDirty(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Form is dirty, show confirmation dialog
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Discard'),
              ),
            ],
          ),
        );

        if (shouldDiscard == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      // FIX #4: Use Scaffold with bottomNavigationBar instead of Stack + Positioned
      // This ensures the framework properly handles keyboard + button positioning
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: theme.colorScheme.surface,
            // FIX #4: resizeToAvoidBottomInset ensures content scrolls above keyboard
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
              ),
              actions: widget.expense != null
                  ? [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteExpense,
            tooltip: 'Delete expense',
          ),
        ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.expense == null ? 'Add Expense' : 'Edit Expense',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 40),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount
                  Text(
                    'AMOUNT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [CurrencyHelper.decimalInputFormatter()],
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
                    decoration: InputDecoration(
                      prefixText: appState.currency,
                      prefixStyle: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
                      hintText: '0.00',
                      border: InputBorder.none,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }
                      final parsed = CurrencyHelper.parseDecimal(value);
                      if (parsed == null) {
                        return 'Please enter a valid number';
                      }
                      if (parsed <= 0) {
                        return 'Amount must be greater than 0';
                      }
                      // FIX #4: Add max amount validation
                      if (parsed > 999999999.99) {
                        return 'Amount cannot exceed 999,999,999.99';
                      }
                      return null;
                    },
                  ),

                  Divider(color: theme.colorScheme.outline),
                  const SizedBox(height: 32),

                  // Category
                  Text(
                    'CATEGORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // FIX: Improved scrollable category selection for better UX with many categories
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // FIX: Show deleted/archived category if editing expense with deleted category
                          // FIX #9: Add tooltip explaining what "Archived" means
                          if (widget.expense != null &&
                              _selectedCategory != null &&
                              !appState.expenseCategories.any((cat) => cat.name == _selectedCategory))
                            Tooltip(
                              message: 'This category was deleted but is preserved for historical data. You can reassign this expense to an active category.',
                              child: Chip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.archive_outlined, size: 16, color: theme.colorScheme.error),
                                    const SizedBox(width: 4),
                                    Text('$_selectedCategory (Archived)'),
                                    const SizedBox(width: 4),
                                    Icon(Icons.info_outline, size: 14, color: theme.colorScheme.error),
                                  ],
                                ),
                                backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                                labelStyle: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                                side: BorderSide(color: theme.colorScheme.error),
                              ),
                            ),
                          // Regular category chips
                          ...appState.expenseCategories.map((cat) {
                            final isSelected = _selectedCategory == cat.name;
                            return ChoiceChip(
                              label: Text(cat.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() => _selectedCategory = cat.name);
                              },
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              selectedColor: theme.colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                              ),
                            );
                          }),
                          // FIX #34: Add button to create new category with visual distinction
                          ActionChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline, size: 16, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                const Text('New Category'),
                              ],
                            ),
                            onPressed: () => _showCreateCategoryDialog(context, appState),
                            backgroundColor: theme.colorScheme.primaryContainer.withAlpha(100),
                            labelStyle: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(color: theme.colorScheme.primary, width: 1.5, style: BorderStyle.solid),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Payment Method
                  Text(
                    'PAYMENT METHOD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Cash', 'Credit', 'Debit', 'Other'].map((method) {
                      final isSelected = _paymentMethod == method;
                      return ChoiceChip(
                        label: Text(method),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _paymentMethod = method;
                          });
                        },
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        selectedColor: theme.colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Description
                  Text(
                    'DESCRIPTION (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // FIX #29: Add character counter, FIX #30: Show truncation warning
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _descriptionController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 200,
                        onChanged: (value) {
                          // Trigger rebuild to update counter
                          setState(() {});
                        },
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
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                          // FIX #29: Character counter
                          counterText: '${_descriptionController.text.length}/200',
                          counterStyle: TextStyle(
                            color: _descriptionController.text.length > 180
                                ? Colors.orange
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        maxLines: 3,
                      ),
                      // FIX #30: Show warning when approaching limit
                      if (_descriptionController.text.length > 180)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Approaching character limit (${200 - _descriptionController.text.length} remaining)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Date
                  Text(
                    'DATE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      // CRITICAL FIX: Use centralized date range helpers for consistency
                      final now = DateTime.now();
                      final minDate = Validators.getTransactionMinDate();
                      final maxDate = Validators.getTransactionMaxDate();

                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate.isAfter(maxDate)
                            ? now
                            : (_selectedDate.isBefore(minDate) ? now : _selectedDate),
                        firstDate: minDate,
                        lastDate: maxDate,
                        helpText: 'Select Transaction Date',
                      );
                      if (date != null) {
                        // FIX #6: Make future date picker PREVENTIVE with confirmation dialog
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        if (date.isAfter(today)) {
                          if (!mounted) return;
                          // Show confirmation dialog for future dates
                          if (!context.mounted) return;
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: theme.colorScheme.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Future Date Selected'),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You selected ${DateFormat.yMMMMd().format(date)}, which is in the future.',
                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withAlpha(30),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.withAlpha(100)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.orange, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'This expense will appear in ${DateFormat.MMMM().format(date)}\'s transactions, not in the current month.',
                                            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Do you want to continue?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
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
                                    foregroundColor: Colors.orange,
                                  ),
                                  child: const Text('Continue'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed != true) {
                            return; // Don't update the date if user cancelled
                          }
                        }

                        // FIX: Preserve time precision to maintain sort order
                        // Without this, edited dates default to midnight causing sorting issues
                        setState(() => _selectedDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          _selectedDate.hour,
                          _selectedDate.minute,
                          _selectedDate.second,
                        ));
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat.yMMMMEEEEd().format(_selectedDate), // FIX: Locale-aware long date
                            style: TextStyle(
                              fontSize: 15,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // FIX: Tags Section
                  Text(
                    'TAGS (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...appState.allTags.map((tag) {
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
                          selectedColor: theme.colorScheme.primary.withAlpha((255 * 0.2).round()),
                          labelStyle: TextStyle(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                          ),
                        );
                      }),
                      // Add tag button
                      ActionChip(
                        label: const Text('+ New Tag'),
                        onPressed: () => _showCreateTagDialog(context, appState),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        side: BorderSide(color: theme.colorScheme.outline, style: BorderStyle.solid),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Quick "Mark as Paid" button for editing unpaid expenses
                  // FIX #5: Auto-save when Mark as Fully Paid is clicked
                  if (widget.expense != null && !widget.expense!.isPaid)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : () async {
                          // Set amount paid to full amount and immediately save
                          setState(() => _isSaving = true);
                          try {
                            final amount = CurrencyHelper.parseDecimal(_amountController.text) ?? widget.expense!.amount;
                            final appState = context.read<AppState>();

                            final updatedExpense = widget.expense!.copyWith(
                              amountPaid: amount,
                            );

                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);

                            await appState.updateExpense(updatedExpense);

                            if (!mounted) return;
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Marked as fully paid'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _isSaving = false);
                            }
                          }
                        },
                        icon: Icon(
                          Icons.check_circle_outline,
                          color: Colors.green.shade600,
                        ),
                        label: Text(
                          'Mark as Fully Paid',
                          style: TextStyle(color: Colors.green.shade600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.green.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  // Amount Paid (Optional)
                  Text(
                    'AMOUNT PAID (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // CRITICAL FIX: Clarify the difference between empty and 0
                  Text(
                    'Track partial payments (e.g., credit card). Leave at 0 if unpaid.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountPaidController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [CurrencyHelper.decimalInputFormatter()],
                    style: const TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                      prefixText: appState.currency,
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
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null; // Optional field
                      }
                      final amountPaid = CurrencyHelper.parseDecimal(value);
                      if (amountPaid == null) {
                        return 'Please enter a valid number';
                      }
                      final totalAmount = CurrencyHelper.parseDecimal(_amountController.text) ?? 0;
                      if (amountPaid < 0) {
                        return 'Amount paid cannot be negative';
                      }
                      if (amountPaid > totalAmount) {
                        return 'Amount paid cannot exceed total amount';
                      }
                      return null;
                    },
                  ),

                  // Extra padding at bottom for keyboard
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      // FIX #4: Use bottomNavigationBar instead of Positioned widget
      // This properly handles keyboard appearance and safe area
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outline),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveExpense,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.onSurface,
              foregroundColor: theme.colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Text(
              widget.expense == null ? 'Add Expense' : 'Update Expense',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
            ), // Close Scaffold
          // FIX #12: Show success animation overlay when saving completes
          // REMOVED: Success overlay - replaced with non-blocking SnackBar
        ], // Close Stack children
      ), // Close Stack
    ); // Close PopScope
  }

  // REMOVED: _buildSuccessOverlay method - replaced with SnackBar feedback
}
