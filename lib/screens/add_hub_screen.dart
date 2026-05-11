import 'package:flutter/material.dart';
import '../theme/luminous_app_theme.dart';
import '../utils/premium_animations.dart';
import '../widgets/luminous/glass_surface.dart';
import 'add_expense_screen.dart';
import 'add_income_screen.dart';
import 'recurring_expenses_screen.dart';

/// Center tab from the stitch redesign: pick what to add (expense, income, budgets, recurring).
class AddHubScreen extends StatelessWidget {
  const AddHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LuminousTokens.containerPadding,
          LuminousTokens.sectionMargin,
          LuminousTokens.containerPadding,
          120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add transaction',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28, height: 1.15),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a type to continue.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: LuminousTokens.sectionMargin),
            GlassPanel(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _HubTile(
                    icon: Icons.remove_circle_outline_rounded,
                    title: 'Expense',
                    subtitle: 'Track money out',
                    tint: cs.primary,
                    onTap: () => Navigator.push(
                      context,
                      PremiumPageRoute(page: const AddExpenseScreen()),
                    ),
                  ),
                  Divider(height: 20, color: Colors.white.withValues(alpha: 0.35)),
                  _HubTile(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Income',
                    subtitle: 'Track money in',
                    tint: LuminousTokens.primaryContainer,
                    onTap: () => Navigator.push(
                      context,
                      PremiumPageRoute(page: const AddIncomeScreen()),
                    ),
                  ),
                  Divider(height: 20, color: Colors.white.withValues(alpha: 0.35)),
                  _HubTile(
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'Budgets',
                    subtitle: 'Plan monthly limits',
                    tint: cs.secondary,
                    onTap: () => Navigator.pushNamed(context, '/budgets'),
                  ),
                  Divider(height: 20, color: Colors.white.withValues(alpha: 0.35)),
                  _HubTile(
                    icon: Icons.repeat_rounded,
                    title: 'Recurring',
                    subtitle: 'Bills & scheduled income',
                    tint: cs.onSurfaceVariant,
                    onTap: () => Navigator.push(
                      context,
                      PremiumPageRoute(page: const RecurringExpensesScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.15),
                  border: Border.all(color: tint.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: tint, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
