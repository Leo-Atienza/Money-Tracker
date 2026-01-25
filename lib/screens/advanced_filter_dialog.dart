import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../utils/currency_helper.dart';
import '../utils/validators.dart';

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
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final categories = ['All', ...appState.categoryNames];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Filters',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // Category Filter
          Text(
            'CATEGORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _filterCategory,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: categories.map((cat) {
              return DropdownMenuItem(value: cat, child: Text(cat));
            }).toList(),
            onChanged: (value) => setState(() => _filterCategory = value!),
          ),

          const SizedBox(height: 20),

          // Date Range
          Text(
            'DATE RANGE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dateRange == null
                        ? 'Any date'
                        : '${DateFormat('MMM d, y').format(_dateRange!.start)} - ${DateFormat('MMM d, y').format(_dateRange!.end)}',
                    style: TextStyle(
                      fontSize: 15,
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

          const SizedBox(height: 20),

          // Amount Range
          Text(
            'AMOUNT RANGE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    CurrencyHelper.decimalInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Min',
                    prefixText: '${appState.currency} ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    // FIX: Use parseDecimal to support both comma and dot as decimal separator
                    _minAmount = CurrencyHelper.parseDecimal(value);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _maxController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    CurrencyHelper.decimalInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Max',
                    prefixText: '${appState.currency} ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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

          const SizedBox(height: 20),

          // Payment Status
          Text(
            'PAYMENT STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
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

          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearFilters,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.onSurface,
                    foregroundColor: theme.colorScheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
    final appState = context.read<AppState>();
    appState.setFilterCategory(_filterCategory);
    appState.setDateRange(_dateRange?.start, _dateRange?.end);
    appState.setAmountRange(_minAmount, _maxAmount);
    appState.setPaidStatusFilter(_paidStatus);
    Navigator.pop(context);
  }
}