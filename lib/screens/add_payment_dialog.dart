import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/expense_model.dart';
import '../utils/currency_helper.dart';

class AddPaymentDialog extends StatefulWidget {
  final Expense expense;

  const AddPaymentDialog({super.key, required this.expense});

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _paymentController = TextEditingController();
  bool _useIncomeBalance = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  Future<void> _addPayment() async {
    if (_formKey.currentState!.validate()) {
      // FIX: Use parseDecimal to support both comma and dot as decimal separator
      final paymentAmount = CurrencyHelper.parseDecimal(_paymentController.text) ?? 0.0;
      final appState = context.read<AppState>();

      // Check if user wants to use income and has sufficient balance
      if (_useIncomeBalance) {
        final availableIncome = appState.getAvailableIncomeForMonth(widget.expense.date);
        if (paymentAmount > availableIncome) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Insufficient income balance. Available: ${appState.currency}${availableIncome.toStringAsFixed(2)}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      setState(() => _isSaving = true);
      try {
        await appState.addPayment(widget.expense, paymentAmount);

        if (mounted) {
          Navigator.pop(context);
          if (_useIncomeBalance) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Payment of ${appState.currency}${paymentAmount.toStringAsFixed(2)} recorded from income',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error recording payment: $e'),
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
  }

  Widget _buildIncomePaymentOption(AppState appState, ThemeData theme) {
    final availableIncome = appState.getAvailableIncomeForMonth(widget.expense.date);
    final hasIncome = availableIncome > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _useIncomeBalance
            ? Colors.green.withAlpha(20)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _useIncomeBalance ? Colors.green : theme.colorScheme.outline,
          width: _useIncomeBalance ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 20,
                color: hasIncome ? Colors.green : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay from Income',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasIncome
                          ? 'Available: ${appState.currency}${availableIncome.toStringAsFixed(2)}'
                          : 'No income available this month',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasIncome
                            ? Colors.green
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _useIncomeBalance,
                onChanged: hasIncome
                    ? (value) => setState(() => _useIncomeBalance = value)
                    : null,
                activeTrackColor: Colors.green.withAlpha(150),
                activeThumbColor: Colors.green,
              ),
            ],
          ),
          if (_useIncomeBalance && hasIncome) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This payment will be deducted from your available income balance.',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expense.remainingAmount;
    final progress = widget.expense.paymentProgress;
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();

    // FIX: Check if payment amount exceeds available balance
    final paymentAmount = CurrencyHelper.parseDecimal(_paymentController.text) ?? 0.0;
    final availableIncome = appState.getAvailableIncomeForMonth(widget.expense.date);
    final hasInsufficientBalance = _useIncomeBalance && paymentAmount > availableIncome;
    final isPaymentValid = paymentAmount > 0 && paymentAmount <= remaining && !hasInsufficientBalance;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                widget.expense.description,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.expense.category,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Progress Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PAID',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${appState.currency}${widget.expense.amountPaid.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'TOTAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${appState.currency}${widget.expense.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (remaining > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Remaining: ${appState.currency}${remaining.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: theme.colorScheme.outlineVariant,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% paid',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (remaining > 0) ...[
                // Payment Input
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PAYMENT AMOUNT',
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
                            child: TextFormField(
                              controller: _paymentController,
                              style: TextStyle(
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                prefixText: '${appState.currency} ',
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                CurrencyHelper.decimalInputFormatter(),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter amount';
                                }
                                // FIX: Use parseDecimal to support both comma and dot as decimal separator
                                final amount = CurrencyHelper.parseDecimal(value);
                                if (amount == null || amount <= 0) {
                                  return 'Enter valid amount';
                                }
                                if (amount > remaining + 0.001) {
                                  return 'Cannot exceed remaining';
                                }
                                return null;
                              },
                              autofocus: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              _paymentController.text = remaining.toStringAsFixed(2);
                            },
                            child: const Text('Pay All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Pay from Income Option
                      _buildIncomePaymentOption(appState, theme),
                    ],
                  ),
                ),
              ] else ...[
                // Fully Paid
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.onSurface,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fully Paid',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  if (remaining > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        // FIX: Disable button when payment is invalid instead of showing error after tap
                        onPressed: (isPaymentValid && !_isSaving) ? _addPayment : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.onSurface,
                          foregroundColor: theme.colorScheme.surface,
                          // FIX: Show visual feedback when disabled
                          disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                          disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
                          // FIX: Show reason why button is disabled
                          hasInsufficientBalance
                              ? 'Insufficient Balance'
                              : paymentAmount > remaining
                                  ? 'Amount Too High'
                                  : 'Add Payment',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}