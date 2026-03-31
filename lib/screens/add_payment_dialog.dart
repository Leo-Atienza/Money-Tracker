import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/expense_model.dart';
import '../utils/currency_helper.dart';
import '../constants/spacing.dart';
import '../main.dart';

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
  void initState() {
    super.initState();
    _paymentController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  Future<void> _addPayment() async {
    if (_formKey.currentState!.validate()) {
      // FIX: Use parseDecimal to support both comma and dot as decimal separator
      final paymentAmount =
          CurrencyHelper.parseDecimal(_paymentController.text) ?? 0.0;
      final appState = context.read<AppState>();

      // Check if user wants to use income and has sufficient balance
      if (_useIncomeBalance) {
        final availableIncome = appState.getAvailableIncomeForMonth(
          widget.expense.date,
        );
        if (paymentAmount > availableIncome) {
          if (mounted) {
            final appColors = Theme.of(context).extension<AppColors>()!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Insufficient income balance. Available: ${appState.currency}${availableIncome.toStringAsFixed(2)}',
                ),
                backgroundColor: appColors.expenseRed,
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
            final appColors = Theme.of(context).extension<AppColors>()!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Payment of ${appState.currency}${paymentAmount.toStringAsFixed(2)} recorded from income',
                ),
                backgroundColor: appColors.incomeGreen,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          final appColors = Theme.of(context).extension<AppColors>()!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error recording payment: $e'),
              backgroundColor: appColors.expenseRed,
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
    final appColors = Theme.of(context).extension<AppColors>()!;
    final availableIncome = appState.getAvailableIncomeForMonth(
      widget.expense.date,
    );
    final hasIncome = availableIncome > 0;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: _useIncomeBalance
            ? appColors.incomeGreen.withAlpha(20)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Spacing.radiusMedium),
        border: Border.all(
          color: _useIncomeBalance ? appColors.incomeGreen : theme.colorScheme.outline,
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
                color: hasIncome
                    ? appColors.incomeGreen
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay from Income',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasIncome
                          ? 'Available: ${appState.currency}${availableIncome.toStringAsFixed(2)}'
                          : 'No income available this month',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: hasIncome
                            ? appColors.incomeGreen
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
                activeTrackColor: appColors.incomeGreen.withAlpha(150),
                activeThumbColor: appColors.incomeGreen,
              ),
            ],
          ),
          if (_useIncomeBalance && hasIncome) ...[
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: appColors.incomeGreen.withAlpha(10),
                borderRadius: BorderRadius.circular(Spacing.radiusSmall),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: appColors.incomeGreen),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      'This payment will be deducted from your available income balance.',
                      style: theme.textTheme.labelSmall?.copyWith(
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
    // Select only the fields rendered in this build method
    final (currency, availableIncome) =
        context.select<AppState, (String, double)>(
      (s) => (s.currency, s.getAvailableIncomeForMonth(widget.expense.date)),
    );
    final appState = context.read<AppState>();

    // FIX: Check if payment amount exceeds available balance
    final paymentAmount =
        CurrencyHelper.parseDecimal(_paymentController.text) ?? 0.0;
    final hasInsufficientBalance =
        _useIncomeBalance && paymentAmount > availableIncome;
    final isPaymentValid = paymentAmount > 0 &&
        paymentAmount <= remaining &&
        !hasInsufficientBalance;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Spacing.radiusLarge)),
      insetPadding: const EdgeInsets.symmetric(horizontal: Spacing.screenPadding, vertical: Spacing.screenPadding),
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(Spacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                widget.expense.description,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: Spacing.xxs),
              Text(
                widget.expense.category,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.screenPadding),

              // Progress Section
              Container(
                padding: const EdgeInsets.all(Spacing.cardPadding),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Spacing.radiusMedium),
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
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 1,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: Spacing.xxs),
                            Text(
                              '$currency${widget.expense.amountPaid.toStringAsFixed(2)}',
                              style: theme.textTheme.titleLarge?.copyWith(
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
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 1,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: Spacing.xxs),
                            Text(
                              '$currency${widget.expense.amount.toStringAsFixed(2)}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (remaining > 0) ...[
                      const SizedBox(height: Spacing.sm),
                      Text(
                        'Remaining: $currency${remaining.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: theme.colorScheme.outlineVariant,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% paid',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.screenPadding),

              if (remaining > 0) ...[
                // Payment Input
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PAYMENT AMOUNT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _paymentController,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                prefixText: '$currency ',
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withAlpha(128),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                CurrencyHelper.decimalInputFormatter(),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter amount';
                                }
                                // FIX: Use parseDecimal to support both comma and dot as decimal separator
                                final amount = CurrencyHelper.parseDecimal(
                                  value,
                                );
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
                          const SizedBox(width: Spacing.xs),
                          TextButton(
                            onPressed: () {
                              _paymentController.text =
                                  remaining.toStringAsFixed(2);
                            },
                            child: const Text('Pay All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: Spacing.md),
                      // Pay from Income Option
                      _buildIncomePaymentOption(appState, theme),
                    ],
                  ),
                ),
              ] else ...[
                // Fully Paid
                Container(
                  padding: const EdgeInsets.all(Spacing.cardPadding),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(Spacing.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.onSurface,
                        size: 24,
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          'Fully Paid',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Spacing.screenPadding),

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
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        // FIX: Disable button when payment is invalid instead of showing error after tap
                        onPressed:
                            (isPaymentValid && !_isSaving) ? _addPayment : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.onSurface,
                          foregroundColor: theme.colorScheme.surface,
                          // FIX: Show visual feedback when disabled
                          disabledBackgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          disabledForegroundColor:
                              theme.colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
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
