import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/recurring_expense_model.dart';
import '../utils/currency_helper.dart';
import '../utils/decimal_helper.dart';
import '../utils/validators.dart';
import '../utils/date_helper.dart';
import '../utils/premium_animations.dart';
import '../utils/haptic_helper.dart';
import '../constants/spacing.dart';
import '../main.dart';

class RecurringExpensesScreen extends StatelessWidget {
  const RecurringExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            pinned: true,
            title: Text(
              'Recurring',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(Spacing.screenPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _RecurringList(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecurring(context),
        backgroundColor: theme.colorScheme.onSurface,
        child: Icon(Icons.add, color: theme.colorScheme.surface),
      ),
    );
  }

  void _showAddRecurring(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _AddRecurringDialog(),
    );
  }
}

class _RecurringList extends StatelessWidget {
  const _RecurringList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Watch specific data, read for methods
    final recurring = context.select<AppState, List<RecurringExpense>>(
      (s) => s.recurringExpenses,
    );
    final appState = context.read<AppState>(); // For method calls

    if (recurring.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recurring.length,
      itemBuilder: (context, index) {
        final rec = recurring[index];
        return StaggeredListItem(
          index: index,
          child: AnimatedPressCard(
            onTap: () => _showEditRecurring(context, rec),
            onLongPress: () {
              final id = rec.id;
              if (id == null) return;
              _confirmDelete(context, id);
            },
            borderRadius: BorderRadius.circular(Spacing.radiusLarge),
            border: Border.all(color: theme.colorScheme.outline),
            child: Container(
              margin: const EdgeInsets.only(bottom: Spacing.md),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.cardPadding,
                  vertical: Spacing.sm,
                ),
                title: Text(
                  rec.description,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: rec.isActive
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: Spacing.xxs),
                  child: Row(
                    children: [
                      Text(
                        rec.category,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        ' • Day ${rec.dayOfMonth}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${appState.currency}${rec.amount.toStringAsFixed(0)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: rec.isActive
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Switch(
                      value: rec.isActive,
                      onChanged: (value) async {
                        HapticHelper.selectionClick();
                        final updated = rec.copyWith(isActive: value);
                        await context.read<AppState>().updateRecurringExpense(
                              updated,
                            );
                      },
                      activeTrackColor: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(Spacing.xxl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Spacing.radiusLarge),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          BounceAnimation(
            child: Icon(
              Icons.repeat,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.md),
          FadeInOnLoad(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'No recurring expenses',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          // FIX #5: Add descriptive explanation of recurring expenses feature
          Text(
            'Automate monthly or weekly expenses like rent, subscriptions, and bills',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.md),
          // FIX #5: Example use cases to help users understand
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withAlpha(30),
              borderRadius: BorderRadius.circular(Spacing.radiusSmall),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      'Examples',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Netflix \$15 on day 1 • Rent \$1200 on day 5',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'Tap + to add your first recurring expense',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditRecurring(BuildContext context, RecurringExpense recurring) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AddRecurringDialog(recurring: recurring),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusXLarge),
        ),
        title: Text(
          'Delete Recurring Expense?',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will stop creating future expenses.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: appColors.infoBlue.withAlpha(20),
                borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                border: Border.all(color: appColors.infoBlue.withAlpha(100)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: appColors.infoBlue, size: 20),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      'Past transactions will NOT be deleted and will remain in your history.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppState>().deleteRecurringExpense(id);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).extension<AppColors>()!.expenseRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AddRecurringDialog extends StatefulWidget {
  final RecurringExpense? recurring;

  const _AddRecurringDialog({this.recurring});

  @override
  State<_AddRecurringDialog> createState() => _AddRecurringDialogState();
}

class _AddRecurringDialogState extends State<_AddRecurringDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late TextEditingController _dayController;
  late TextEditingController _maxOccurrencesController;
  String? _selectedCategory;
  bool _isSaving = false;
  RecurringExpenseFrequency _selectedFrequency =
      RecurringExpenseFrequency.monthly;
  int _selectedDayOfWeek = 0; // 0 = Monday
  DateTime _startDate = DateHelper.today();
  DateTime? _endDate;
  bool _hasEndDate = false;
  bool _hasMaxOccurrences = false;

  static const List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.recurring?.description ?? '',
    );
    _amountController = TextEditingController(
      text: widget.recurring?.amount.toString() ?? '',
    );

    if (widget.recurring != null) {
      _selectedFrequency = widget.recurring!.frequency;
      _selectedCategory = widget.recurring!.category;
      _startDate = widget.recurring!.startDate ?? DateHelper.today();
      _endDate = widget.recurring!.endDate;
      _hasEndDate = widget.recurring!.endDate != null;
      _hasMaxOccurrences = widget.recurring!.maxOccurrences != null;

      if (_selectedFrequency == RecurringExpenseFrequency.monthly) {
        _dayController = TextEditingController(
          text: widget.recurring!.dayOfMonth.toString(),
        );
        _selectedDayOfWeek = 0;
      } else {
        _selectedDayOfWeek = widget.recurring!.dayOfMonth.clamp(0, 6);
        _dayController = TextEditingController(text: '1');
      }

      _maxOccurrencesController = TextEditingController(
        text: widget.recurring!.maxOccurrences?.toString() ?? '',
      );
    } else {
      _dayController = TextEditingController(text: '1');
      _selectedCategory = null;
      _maxOccurrencesController = TextEditingController();
    }

    // FIX #22: Add listener to rebuild when day changes (for day 29-31 warning)
    _dayController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _dayController.dispose();
    _maxOccurrencesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Watch specific data, read for methods
    final categories = context.select<AppState, List<String>>(
      (s) => s.categoryNames,
    );
    final appState = context.read<AppState>(); // For method calls

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Spacing.radiusXLarge),
          ),
        ),
        padding: const EdgeInsets.all(Spacing.screenPadding),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.recurring != null ? 'Edit Recurring' : 'Add Recurring',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: Spacing.screenPadding),
              TextFormField(
                controller: _descriptionController,
                autofocus: true,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g., Netflix, Rent, Gym',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '${appState.currency} ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                  ),
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
              ),
              const SizedBox(height: Spacing.screenPadding),

              // FIX: Frequency selector
              Text(
                'FREQUENCY',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  _buildFrequencyChip(
                    theme,
                    RecurringExpenseFrequency.monthly,
                    'Monthly',
                    Icons.calendar_month,
                  ),
                  const SizedBox(width: Spacing.xs),
                  _buildFrequencyChip(
                    theme,
                    RecurringExpenseFrequency.weekly,
                    'Weekly',
                    Icons.calendar_today,
                  ),
                  const SizedBox(width: Spacing.xs),
                  _buildFrequencyChip(
                    theme,
                    RecurringExpenseFrequency.biweekly,
                    'Bi-weekly',
                    Icons.date_range,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.screenPadding),

              // FIX: Conditional day selector based on frequency
              _buildDaySelector(theme),
              const SizedBox(height: Spacing.xs),
              Text(
                _selectedFrequency == RecurringExpenseFrequency.monthly
                    ? 'Expense will auto-create on this day each month'
                    : _selectedFrequency == RecurringExpenseFrequency.weekly
                        ? 'Expense will auto-create every week'
                        : 'Expense will auto-create every two weeks',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.screenPadding),

              // FIX: Optional end conditions
              Text(
                'END CONDITIONS (OPTIONAL)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),

              // End Date checkbox and picker
              CheckboxListTile(
                title: const Text('Stop on specific date'),
                value: _hasEndDate,
                onChanged: (value) {
                  setState(() {
                    _hasEndDate = value ?? false;
                    if (_hasEndDate && _endDate == null) {
                      _endDate = DateHelper.today().add(
                        const Duration(days: 365),
                      );
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasEndDate) ...[
                ListTile(
                  title: Text(
                    _endDate != null
                        ? DateFormat.yMMMd().format(_endDate!)
                        : 'Select date',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    // CRITICAL FIX: Use centralized date range helpers for consistency
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ??
                          DateHelper.today().add(const Duration(days: 365)),
                      firstDate: Validators.getRecurringEndMinDate(),
                      lastDate: Validators.getRecurringEndMaxDate(),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                    }
                  },
                  contentPadding: const EdgeInsets.only(left: 32),
                ),
              ],
              const SizedBox(height: 8),

              // Max Occurrences checkbox and input
              CheckboxListTile(
                title: const Text('Stop after number of times'),
                value: _hasMaxOccurrences,
                onChanged: (value) {
                  setState(() => _hasMaxOccurrences = value ?? false);
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasMaxOccurrences) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: TextFormField(
                    controller: _maxOccurrencesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Number of occurrences',
                      hintText: 'e.g., 12 for one year',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Spacing.screenPadding),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.onSurface,
                    foregroundColor: theme.colorScheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_descriptionController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _selectedCategory == null) {
      _showError('Please fill all fields');
      return;
    }

    // FIX: Use parseDecimal to support both comma and dot as decimal separator
    final amount = CurrencyHelper.parseDecimal(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    // FIX: Validate day based on frequency
    int dayValue;
    if (_selectedFrequency == RecurringExpenseFrequency.monthly) {
      final day = int.tryParse(_dayController.text);
      if (day == null || day < 1 || day > 31) {
        _showError('Day must be between 1 and 31');
        return;
      }
      dayValue = day;
    } else {
      dayValue = _selectedDayOfWeek;
    }

    // FIX: Validate max occurrences if enabled
    int? maxOccurrences;
    if (_hasMaxOccurrences) {
      maxOccurrences = int.tryParse(_maxOccurrencesController.text);
      if (maxOccurrences == null || maxOccurrences <= 0) {
        _showError('Please enter a valid number of occurrences');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final appState = context.read<AppState>();

      // FIX #4: Check for duplicate recurring transactions (only when creating new)
      if (widget.recurring == null) {
        final duplicate = await _checkForDuplicate(
          appState,
          _descriptionController.text,
          amount,
          _selectedCategory!,
          dayValue,
          _selectedFrequency,
        );

        if (duplicate != null) {
          final shouldContinue = await _showDuplicateWarning(duplicate);
          if (!shouldContinue) {
            if (mounted) setState(() => _isSaving = false);
            return;
          }
        }
      }

      if (widget.recurring != null) {
        final updated = widget.recurring!.copyWithDecimal(
          description: _descriptionController.text,
          amount: DecimalHelper.fromDouble(amount),
          category: _selectedCategory!,
          dayOfMonth: dayValue,
          frequency: _selectedFrequency,
          startDate: _startDate,
          endDate: _hasEndDate ? _endDate : null,
          maxOccurrences: maxOccurrences,
        );
        await appState.updateRecurringExpense(updated);
      } else {
        final recurring = RecurringExpense(
          description: _descriptionController.text,
          amount: DecimalHelper.fromDouble(amount),
          category: _selectedCategory!,
          accountId: appState.currentAccount!.id!,
          dayOfMonth: dayValue,
          frequency: _selectedFrequency,
          startDate: _startDate,
          endDate: _hasEndDate ? _endDate : null,
          maxOccurrences: maxOccurrences,
        );

        await appState.addRecurringExpense(recurring);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('Failed to save');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // FIX: Removed unused _showMissedMonthDialog method (legacy code no longer needed)

  void _showError(String message) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: appColors.expenseRed,
      ),
    );
  }

  /// FIX #4: Check for similar recurring transactions to prevent duplicates
  /// Returns the duplicate transaction if found, null otherwise
  Future<RecurringExpense?> _checkForDuplicate(
    AppState appState,
    String description,
    double amount,
    String category,
    int dayValue,
    RecurringExpenseFrequency frequency,
  ) async {
    // Check for similar recurring transactions
    final existingRecurring = appState.recurringExpenses;

    for (final existing in existingRecurring) {
      // Check if all key fields match (description, amount, category, day, frequency)
      // Use toLowerCase for case-insensitive comparison
      final descMatch =
          existing.description.toLowerCase() == description.toLowerCase();
      final amountMatch =
          (existing.amount - amount).abs() < 0.01; // Floating point comparison
      final catMatch = existing.category == category;
      final dayMatch = existing.dayOfMonth == dayValue;
      final freqMatch = existing.frequency == frequency;

      // If all fields match, it's a duplicate
      if (descMatch &&
          amountMatch &&
          catMatch &&
          dayMatch &&
          freqMatch &&
          existing.isActive) {
        return existing;
      }
    }

    return null;
  }

  /// FIX #4: Show warning dialog when duplicate recurring transaction is detected
  Future<bool> _showDuplicateWarning(RecurringExpense duplicate) async {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final currencySymbol = context.read<AppState>().currency;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusXLarge),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: appColors.warningOrange,
              size: 28,
            ),
            const SizedBox(width: Spacing.sm),
            Text(
              'Similar Transaction Found',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You already have a similar recurring expense:',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: appColors.warningOrange.withAlpha(20),
                borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                border: Border.all(color: appColors.warningOrange.withAlpha(100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    duplicate.description,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$currencySymbol${duplicate.amount.toStringAsFixed(2)} • ${duplicate.category} • Day ${duplicate.dayOfMonth}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Creating this will result in duplicate expenses every ${duplicate.frequency == RecurringExpenseFrequency.monthly ? 'month' : 'week'}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
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
            style: TextButton.styleFrom(foregroundColor: appColors.warningOrange),
            child: const Text('Create Anyway'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget _buildFrequencyChip(
    ThemeData theme,
    RecurringExpenseFrequency frequency,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedFrequency == frequency;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFrequency = frequency),
        borderRadius: BorderRadius.circular(Spacing.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Spacing.radiusMedium),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: Spacing.xxs),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector(ThemeData theme) {
    if (_selectedFrequency == RecurringExpenseFrequency.monthly) {
      // FIX #22: Build day field with warning for days 29-31
      final dayField = TextFormField(
        controller: _dayController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Day of Month',
          hintText: '1-31',
          helperText:
              'Enter a day between 1-31. For 29-31, months without those days will use the last day.',
          helperMaxLines: 2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Spacing.radiusSmall),
          ),
        ),
        // FIX #24: Add real-time validation for day of month
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Day is required';
          }
          final day = int.tryParse(value);
          if (day == null) {
            return 'Please enter a valid number';
          }
          if (day < 1 || day > 31) {
            return 'Day must be between 1 and 31';
          }
          return null;
        },
      );

      // FIX #22: Add visible warning for days 29-31
      final dayValue = int.tryParse(_dayController.text);
      if (dayValue != null && dayValue >= 29 && dayValue <= 31) {
        final appColors = Theme.of(context).extension<AppColors>()!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            dayField,
            const SizedBox(height: Spacing.xs),
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: appColors.warningOrange.withAlpha(20),
                borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                border: Border.all(color: appColors.warningOrange.withAlpha(100)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: appColors.warningOrange,
                    size: 20,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      dayValue == 31
                          ? 'Day 31: Will occur on the last day for months with fewer than 31 days (Feb: 28/29, Apr/Jun/Sep/Nov: 30)'
                          : dayValue == 30
                              ? 'Day 30: Will occur on Feb 28/29 (last day of February)'
                              : 'Day 29: Will occur on Feb 28 in non-leap years',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      return dayField;
    } else {
      // Weekly/Bi-weekly day selector
      final isBiweekly =
          _selectedFrequency == RecurringExpenseFrequency.biweekly;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAY OF WEEK',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: List.generate(7, (index) {
              final isSelected = _selectedDayOfWeek == index;
              return ChoiceChip(
                label: Text(_dayNames[index].substring(0, 3)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedDayOfWeek = index);
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
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              );
            }),
          ),
          if (isBiweekly) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              'Starting from ${DateFormat.yMMMd().format(_startDate)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }
  }
}
