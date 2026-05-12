import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/luminous_tokens.dart';
import '../widgets/luminous/glass_segmented_control.dart';
import '../widgets/luminous/glass_top_app_bar.dart';
import 'recurring/recurring_expenses_view.dart';
import 'recurring/recurring_income_view.dart';

/// Unified "Recurring Items" screen — replaces the old
/// `RecurringExpensesScreen` and `RecurringIncomeScreen` (which each owned
/// their own scaffold + FAB).
///
/// Phase 5.7 merge: one screen with a segmented Expenses / Income toggle
/// that swaps in either [RecurringExpensesView] or [RecurringIncomeView].
/// The FAB color and target dialog change with the selected tab — neither
/// underlying database table nor notification ID range is touched, so
/// existing scheduled reminders keep firing.
class RecurringItemsScreen extends StatefulWidget {
  /// Which tab to open on first paint. Accepts `'expense'` (default) or
  /// `'income'`. Settings deep-links pass `'income'` for the dedicated
  /// "Recurring Income" entry.
  final String initialType;

  const RecurringItemsScreen({super.key, this.initialType = 'expense'});

  @override
  State<RecurringItemsScreen> createState() => _RecurringItemsScreenState();
}

class _RecurringItemsScreenState extends State<RecurringItemsScreen> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialType == 'income' ? 'income' : 'expense';
  }

  bool get _isExpense => _selected == 'expense';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTopAppBar(
            title: 'Recurring Items',
            leading: const BackButton(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LuminousTokens.containerPadding,
              LuminousTokens.stackGap,
              LuminousTokens.containerPadding,
              LuminousTokens.basePx,
            ),
            child: GlassSegmentedControl<String>(
              values: const ['expense', 'income'],
              labels: const ['Expenses', 'Income'],
              selected: _selected,
              onChanged: (value) => setState(() => _selected = value),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                LuminousTokens.containerPadding,
                LuminousTokens.basePx,
                LuminousTokens.containerPadding,
                100,
              ),
              child: _isExpense
                  ? const RecurringExpensesView()
                  : const RecurringIncomeView(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_isExpense) {
            showAddRecurringExpenseDialog(context);
          } else {
            showAddRecurringIncomeDialog(context);
          }
        },
        backgroundColor:
            _isExpense ? theme.colorScheme.onSurface : appColors.incomeGreen,
        child: Icon(
          Icons.add,
          color: _isExpense ? theme.colorScheme.surface : Colors.white,
        ),
      ),
    );
  }
}
