import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../utils/currency_helper.dart';
import '../utils/validators.dart';
import '../constants/spacing.dart';

class AdvancedFilterDialog extends StatefulWidget {
  const AdvancedFilterDialog({super.key});

  @override
  State<AdvancedFilterDialog> createState() => _AdvancedFilterDialogState();
}

class _AdvancedFilterDialogState extends State<AdvancedFilterDialog> {
  String _filterCategory = 'All';
  DateTimeRange? _dateRange;
  double? _minAmount;
  double? _maxAmount;
  bool? _paidStatus;

  late TextEditingController _minController;
  late TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _filterCategory = appState.filterCategory;
    _dateRange = appState.dateRange;

    _minController = TextEditingController();
    _maxController = TextEditingController();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Select only the fields rendered in this dialog
    final (categoryNames, currency) =
        context.select<AppState, (List<String>, String)>(
      (s) => (s.categoryNames, s.currency),
    );
    final categories = ['All', ...categoryNames];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(Spacing.screenPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Filters',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Spacing.screenPadding),

          // Category Filter
          Text(
            'CATEGORY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          DropdownButtonFormField<String>(
            initialValue: _filterCategory,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Spacing.radiusSmall),
              ),
            ),
            items: categories.map((cat) {
              return DropdownMenuItem(value: cat, child: Text(cat));
            }).toList(),
            onChanged: (value) => setState(() => _filterCategory = value!),
          ),

          const SizedBox(height: Spacing.lg),

          // Date Range
          Text(
            'DATE RANGE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          InkWell(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(Spacing.radiusSmall),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dateRange == null
                        ? 'Any date'
                        : '${DateFormat('MMM d, y').format(_dateRange!.start)} - ${DateFormat('MMM d, y').format(_dateRange!.end)}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_dateRange != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _dateRange = null),
              child: const Text('Clear date range'),
            ),
          ],

          const SizedBox(height: Spacing.lg),

          // Amount Range
          Text(
            'AMOUNT RANGE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [CurrencyHelper.decimalInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Min',
                    prefixText: '$currency ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                    ),
                  ),
                  onChanged: (value) {
                    // FIX: Use parseDecimal to support both comma and dot as decimal separator
                    _minAmount = CurrencyHelper.parseDecimal(value);
                  },
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: TextField(
                  controller: _maxController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [CurrencyHelper.decimalInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Max',
                    prefixText: '$currency ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                    ),
                  ),
                  onChanged: (value) {
                    // FIX: Use parseDecimal to support both comma and dot as decimal separator
                    _maxAmount = CurrencyHelper.parseDecimal(value);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: Spacing.lg),

          // Payment Status
          Text(
            'PAYMENT STATUS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _paidStatus == null,
                onSelected: (selected) {
                  setState(() => _paidStatus = null);
                },
              ),
              ChoiceChip(
                label: const Text('Paid'),
                selected: _paidStatus == true,
                onSelected: (selected) {
                  setState(() => _paidStatus = selected ? true : null);
                },
              ),
              ChoiceChip(
                label: const Text('Unpaid'),
                selected: _paidStatus == false,
                onSelected: (selected) {
                  setState(() => _paidStatus = selected ? false : null);
                },
              ),
            ],
          ),

          const SizedBox(height: Spacing.xxl),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearFilters,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                    ),
                  ),
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.onSurface,
                    foregroundColor: theme.colorScheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                    ),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    // CRITICAL FIX: Use centralized date range helpers for consistency
    final picked = await showDateRangePicker(
      context: context,
      firstDate: Validators.getFilterMinDate(),
      lastDate: Validators.getFilterMaxDate(),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _clearFilters() {
    context.read<AppState>().clearFilters();
    Navigator.pop(context);
  }

  void _applyFilters() {
    // Validate min/max cross-check
    if (_minAmount != null && _maxAmount != null && _minAmount! > _maxAmount!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Min amount cannot be greater than max amount'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final appState = context.read<AppState>();
    appState.setFilterCategory(_filterCategory);
    appState.setDateRange(_dateRange?.start, _dateRange?.end);
    appState.setAmountRange(_minAmount, _maxAmount);
    appState.setPaidStatusFilter(_paidStatus);
    Navigator.pop(context);
  }
}
