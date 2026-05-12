import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/quick_template_model.dart';
import '../models/category_model.dart';
import '../utils/currency_helper.dart';
import '../utils/decimal_helper.dart';
import '../utils/premium_animations.dart';
import '../utils/haptic_helper.dart';
import '../theme/app_colors.dart';
import '../theme/luminous_tokens.dart';
import '../widgets/luminous/glass_panel.dart';
import '../widgets/luminous/glass_top_app_bar.dart';

/// Phase 5.9i — Quick Templates Luminous redesign.
///
/// Composition:
///   * [GlassTopAppBar] header ("Quick Templates") with BackButton leading.
///   * Each template card wrapped in [GlassPanel] (replaces the old
///     `Card` + surface-container styling).
///   * Empty state wrapped in a [GlassPanel].
///
/// The Add/Edit dialog (`_AddTemplateDialog`) keeps its original
/// `AlertDialog` shell which inherits Luminous styling from the global
/// theme; its body fields and validation are unchanged.
class QuickTemplatesScreen extends StatelessWidget {
  const QuickTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templates = context.select<AppState, List<QuickTemplate>>(
      (s) => s.quickTemplates,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTopAppBar(
            leading: BackButton(color: theme.colorScheme.onSurface),
            title: 'Quick Templates',
          ),
          Expanded(
            child: templates.isEmpty
                ? _EmptyTemplates(theme: theme)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      LuminousTokens.containerPadding,
                      LuminousTokens.stackGap,
                      LuminousTokens.containerPadding,
                      96,
                    ),
                    child: ListView.separated(
                      itemCount: templates.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        return StaggeredListItem(
                          index: index,
                          child: _TemplateCard(template: template),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTemplateDialog(context),
        backgroundColor: theme.colorScheme.onSurface,
        foregroundColor: theme.colorScheme.surface,
        icon: const Icon(Icons.add),
        label: const Text('Add Template'),
      ),
    );
  }

  void _showAddTemplateDialog(BuildContext context, {QuickTemplate? template}) {
    showDialog(
      context: context,
      builder: (context) => _AddTemplateDialog(template: template),
    );
  }
}

class _EmptyTemplates extends StatelessWidget {
  final ThemeData theme;
  const _EmptyTemplates({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LuminousTokens.sectionMargin),
        child: GlassPanel(
          padding: const EdgeInsets.all(LuminousTokens.glassPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flash_on_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No templates yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Create templates for quick adding',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final QuickTemplate template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final appState = context.read<AppState>();
    final isIncome = template.type == 'income';
    final accent =
        isIncome ? appColors.incomeGreen : theme.colorScheme.onSurface;

    return AnimatedPressCard(
      borderRadius: BorderRadius.circular(LuminousTokens.radiusLg),
      border: Border.all(
        color: theme.colorScheme.outline.withValues(alpha: 0.4),
      ),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isIncome ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(LuminousTokens.radiusMd),
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: accent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    template.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${template.category} • ${template.paymentMethod}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${appState.currency}${template.amount.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'use',
                  child: Row(
                    children: [
                      Icon(Icons.flash_on),
                      SizedBox(width: 12),
                      Text('Use Template'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 12),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: appColors.expenseRed),
                      const SizedBox(width: 12),
                      Text('Delete',
                          style: TextStyle(color: appColors.expenseRed)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'use') {
                  HapticHelper.lightImpact();
                  await appState.useTemplate(template);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${template.name} added!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else if (value == 'edit') {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          _AddTemplateDialog(template: template),
                    );
                  }
                } else if (value == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Template'),
                      content: Text(
                        'Are you sure you want to delete "${template.name}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        Builder(
                          builder: (context) {
                            final dialogAppColors =
                                Theme.of(context).extension<AppColors>()!;
                            return FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: dialogAppColors.expenseRed,
                              ),
                              child: const Text('Delete'),
                            );
                          },
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    await appState.deleteTemplate(template.id!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${template.name} deleted'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTemplateDialog extends StatefulWidget {
  final QuickTemplate? template;

  const _AddTemplateDialog({this.template});

  @override
  State<_AddTemplateDialog> createState() => _AddTemplateDialogState();
}

class _AddTemplateDialogState extends State<_AddTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  String _type = 'expense';
  String _selectedCategory = 'Food';
  String _paymentMethod = 'Cash';

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _nameController.text = widget.template!.name;
      _amountController.text = widget.template!.amount.toString();
      _type = widget.template!.type;
      _selectedCategory = widget.template!.category;
      _paymentMethod = widget.template!.paymentMethod;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = context.select<AppState, List<Category>>(
      (s) => _type == 'expense' ? s.expenseCategories : s.incomeCategories,
    );
    final appState = context.read<AppState>();

    final validCategory = categories.isNotEmpty &&
            categories.any((c) => c.name == _selectedCategory)
        ? _selectedCategory
        : (categories.isNotEmpty ? categories.first.name : _selectedCategory);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text(widget.template == null ? 'Add Template' : 'Edit Template'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'expense',
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: 'income',
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _type = newSelection.first;
                    _selectedCategory = _type == 'expense' ? 'Food' : 'Salary';
                  });
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g., Morning Coffee',
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: appState.currency,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [CurrencyHelper.decimalInputFormatter()],
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  final amount = CurrencyHelper.parseDecimal(value!);
                  if (amount == null) return 'Invalid number';
                  if (amount <= 0) return 'Amount must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: validCategory,
                    isExpanded: true,
                    isDense: true,
                    items: categories
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat.name,
                            child: Text(cat.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _paymentMethod,
                    isExpanded: true,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(
                        value: 'Credit Card',
                        child: Text('Credit Card'),
                      ),
                      DropdownMenuItem(
                        value: 'Debit Card',
                        child: Text('Debit Card'),
                      ),
                      DropdownMenuItem(
                        value: 'Bank Transfer',
                        child: Text('Bank Transfer'),
                      ),
                      DropdownMenuItem(
                        value: 'Mobile Payment',
                        child: Text('Mobile Payment'),
                      ),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) =>
                        setState(() => _paymentMethod = value!),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final template = QuickTemplate(
                id: widget.template?.id,
                name: _nameController.text,
                amount: DecimalHelper.parse(_amountController.text),
                category: _selectedCategory,
                paymentMethod: _paymentMethod,
                type: _type,
                accountId: appState.currentAccountId,
              );

              if (widget.template == null) {
                await appState.addTemplate(template);
              } else {
                await appState.updateTemplate(template);
              }

              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          },
          child: Text(widget.template == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}
