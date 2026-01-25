import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/recurring_income_model.dart';
import '../utils/currency_helper.dart';
import '../utils/decimal_helper.dart';
import '../utils/validators.dart';
import '../utils/date_helper.dart';

class RecurringIncomeScreen extends StatelessWidget {
  const RecurringIncomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFFAFAFA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            pinned: true,
            title: Text(
              'Recurring Income',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _RecurringIncomeList(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecurring(context),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddRecurring(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _AddRecurringIncomeDialog(),
    );
  }
}

class _RecurringIncomeList extends StatelessWidget {
  const _RecurringIncomeList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Watch specific data, read for methods
    final recurring = context.select<AppState, List<RecurringIncome>>((s) => s.recurringIncomes);
    final appState = context.read<AppState>(); // For method calls

    if (recurring.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      children: recurring.map((rec) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: rec.isActive ? Colors.green.withAlpha(100) : theme.colorScheme.outline,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getFrequencyIcon(rec.frequency),
                color: rec.isActive ? Colors.green : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              rec.description,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: rec.isActive
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.category,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rec.frequencyDescription,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.withAlpha(200),
                      fontWeight: FontWeight.w500,
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: rec.isActive ? Colors.green : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: rec.isActive,
                  onChanged: (value) async {
                    final updated = rec.copyWith(isActive: value);
                    await context.read<AppState>().updateRecurringIncome(updated);
                  },
                  activeTrackColor: Colors.green.withAlpha(150),
                  activeThumbColor: Colors.green,
                ),
              ],
            ),
            onTap: () => _showEditRecurring(context, rec),
            onLongPress: () => _confirmDelete(context, rec.id!),
          ),
        );
      }).toList(),
    );
  }

  IconData _getFrequencyIcon(RecurringFrequency frequency) {
    switch (frequency) {
      case RecurringFrequency.monthly:
        return Icons.calendar_month;
      case RecurringFrequency.biweekly:
        return Icons.date_range;
      case RecurringFrequency.weekly:
        return Icons.view_week;
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.repeat,
            size: 48,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            'No recurring income',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add salary, freelance income, etc.',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showEditRecurring(BuildContext context, RecurringIncome recurring) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AddRecurringIncomeDialog(recurring: recurring),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Delete Recurring Income?',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          'This will stop auto-creating this income.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppState>().deleteRecurringIncome(id);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AddRecurringIncomeDialog extends StatefulWidget {
  final RecurringIncome? recurring;

  const _AddRecurringIncomeDialog({this.recurring});

  @override
  State<_AddRecurringIncomeDialog> createState() => _AddRecurringIncomeDialogState();
}

class _AddRecurringIncomeDialogState extends State<_AddRecurringIncomeDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late TextEditingController _dayController;
  String? _selectedCategory;
  RecurringFrequency _selectedFrequency = RecurringFrequency.monthly;
  int _selectedDayOfWeek = 0; // 0 = Monday
  DateTime _startDate = DateHelper.today();
  bool _isSaving = false;

  static const List<String> _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
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

      if (_selectedFrequency == RecurringFrequency.monthly) {
        _dayController = TextEditingController(
          text: widget.recurring!.dayOfMonth.toString(),
        );
        _selectedDayOfWeek = 0;
      } else {
        _dayController = TextEditingController(text: '1');
        _selectedDayOfWeek = widget.recurring!.dayOfMonth.clamp(0, 6);
      }
    } else {
      _dayController = TextEditingController(text: '1');
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Watch specific data, read for methods
    final categories = context.select<AppState, List<String>>(
      (s) => s.incomeCategories.map((c) => c.name).toList(),
    );
    final appState = context.read<AppState>(); // For method calls

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_downward, color: Colors.green),
                  const SizedBox(width: 12),
                  Text(
                    widget.recurring != null ? 'Edit Recurring Income' : 'Add Recurring Income',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Description
              TextFormField(
                controller: _descriptionController,
                autofocus: true,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g., Monthly Salary, Freelance',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Amount
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
              ),
              const SizedBox(height: 24),

              // Frequency Selection
              Text(
                'FREQUENCY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _buildFrequencySelector(theme),
              const SizedBox(height: 20),

              // Day/Date Selection based on frequency
              _buildDaySelector(theme),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

  Widget _buildFrequencySelector(ThemeData theme) {
    return Row(
      children: [
        _buildFrequencyChip(
          theme,
          RecurringFrequency.monthly,
          'Monthly',
          Icons.calendar_month,
        ),
        const SizedBox(width: 8),
        _buildFrequencyChip(
          theme,
          RecurringFrequency.biweekly,
          'Bi-weekly',
          Icons.date_range,
        ),
        const SizedBox(width: 8),
        _buildFrequencyChip(
          theme,
          RecurringFrequency.weekly,
          'Weekly',
          Icons.view_week,
        ),
      ],
    );
  }

  Widget _buildFrequencyChip(
    ThemeData theme,
    RecurringFrequency frequency,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedFrequency == frequency;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFrequency = frequency),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green.withAlpha(20) : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.green : theme.colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.green : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.green : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector(ThemeData theme) {
    if (_selectedFrequency == RecurringFrequency.monthly) {
      return _buildMonthlyDaySelector(theme);
    } else {
      return _buildWeeklyDaySelector(theme);
    }
  }

  Widget _buildMonthlyDaySelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAY OF MONTH',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dayController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            labelText: 'Day of Month',
            hintText: '1-31',
            helperText: 'Enter a day between 1-31. For 29-31, months without those days will use the last day.',
            helperMaxLines: 2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            suffixIcon: const Icon(Icons.calendar_today, size: 20),
          ),
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
        ),
        // FIX #22: Add visible warning for days 29-31
        if (int.tryParse(_dayController.text) != null &&
            int.parse(_dayController.text) >= 29 &&
            int.parse(_dayController.text) <= 31) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withAlpha(100)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    int.parse(_dayController.text) == 31
                        ? 'Day 31: Will occur on the last day for months with fewer than 31 days (Feb: 28/29, Apr/Jun/Sep/Nov: 30)'
                        : int.parse(_dayController.text) == 30
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
      ],
    );
  }

  Widget _buildWeeklyDaySelector(ThemeData theme) {
    final isBiweekly = _selectedFrequency == RecurringFrequency.biweekly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAY OF WEEK',
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
          children: List.generate(7, (index) {
            final isSelected = _selectedDayOfWeek == index;
            return InkWell(
              onTap: () => setState(() => _selectedDayOfWeek = index),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.green : theme.colorScheme.outline,
                  ),
                ),
                child: Center(
                  child: Text(
                    _dayNames[index].substring(0, 3),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (isBiweekly) ...[
          const SizedBox(height: 16),
          Text(
            'START DATE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickStartDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(_startDate),
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This date is used as reference for the bi-weekly cycle',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          isBiweekly
              ? 'Income will auto-create every 2 weeks on ${_dayNames[_selectedDayOfWeek]}'
              : 'Income will auto-create every ${_dayNames[_selectedDayOfWeek]}',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.green,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _pickStartDate() async {
    // CRITICAL FIX: Use centralized date range helpers for consistency
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: Validators.getTransactionMinDate(),
      lastDate: Validators.getRecurringEndMaxDate(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
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

    int dayValue;
    if (_selectedFrequency == RecurringFrequency.monthly) {
      final day = int.tryParse(_dayController.text);
      if (day == null || day < 1 || day > 31) {
        _showError('Day must be between 1 and 31');
        return;
      }
      dayValue = day;
    } else {
      dayValue = _selectedDayOfWeek;
    }

    setState(() => _isSaving = true);

    try {
      final appState = context.read<AppState>();

      // FIX #4: Check for duplicate recurring income (only when creating new)
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
        );
        await appState.updateRecurringIncome(updated);
      } else {
        final recurring = RecurringIncome(
          description: _descriptionController.text,
          amount: DecimalHelper.fromDouble(amount),
          category: _selectedCategory!,
          accountId: appState.currentAccount!.id!,
          dayOfMonth: dayValue,
          frequency: _selectedFrequency,
          startDate: _startDate,
        );

        // FIX: Check if due date has passed for current month (only for monthly frequency)
        await appState.addRecurringIncome(recurring);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('Failed to save');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );
  }

  /// FIX #4: Check for similar recurring income to prevent duplicates
  /// Returns the duplicate transaction if found, null otherwise
  Future<RecurringIncome?> _checkForDuplicate(
    AppState appState,
    String description,
    double amount,
    String category,
    int dayValue,
    RecurringFrequency frequency,
  ) async {
    // Check for similar recurring income
    final existingRecurring = appState.recurringIncomes;

    for (final existing in existingRecurring) {
      // Check if all key fields match (description, amount, category, day, frequency)
      // Use toLowerCase for case-insensitive comparison
      final descMatch = existing.description.toLowerCase() == description.toLowerCase();
      final amountMatch = (existing.amount - amount).abs() < 0.01; // Floating point comparison
      final catMatch = existing.category == category;
      final dayMatch = existing.dayOfMonth == dayValue;
      final freqMatch = existing.frequency == frequency;

      // If all fields match, it's a duplicate
      if (descMatch && amountMatch && catMatch && dayMatch && freqMatch && existing.isActive) {
        return existing;
      }
    }

    return null;
  }

  /// FIX #4: Show warning dialog when duplicate recurring income is detected
  Future<bool> _showDuplicateWarning(RecurringIncome duplicate) async {
    final theme = Theme.of(context);
    final currencySymbol = context.read<AppState>().currency;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Similar Income Found',
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You already have a similar recurring income:',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withAlpha(100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    duplicate.description,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$currencySymbol${duplicate.amount.toStringAsFixed(2)} • ${duplicate.category} • Day ${duplicate.dayOfMonth}',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Creating this will result in duplicate income every ${duplicate.frequency == RecurringFrequency.monthly ? 'month' : duplicate.frequency == RecurringFrequency.weekly ? 'week' : '2 weeks'}.',
              style: TextStyle(
                fontSize: 13,
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
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Create Anyway'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // FIX: Removed unused _showMissedMonthDialog method (legacy code no longer needed)
}
