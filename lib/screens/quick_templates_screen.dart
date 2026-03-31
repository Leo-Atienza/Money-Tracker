import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/quick_template_model.dart';
import '../models/category_model.dart';
import '../utils/currency_helper.dart';
import '../utils/decimal_helper.dart';
import '../utils/premium_animations.dart';
import '../utils/haptic_helper.dart';
import '../constants/spacing.dart';
import '../main.dart';

class QuickTemplatesScreen extends StatelessWidget {
  const QuickTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Only watch quick templates
    final templates = context.select<AppState, List<QuickTemplate>>(
      (s) => s.quickTemplates,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Quick Templates',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: templates.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flash_on_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'No templates yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Create templates for quick adding',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(
                        (255 * 0.6).round(),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(Spacing.screenPadding),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return StaggeredListItem(
                  index: index,
                  child: _TemplateCard(template: template),
                );
              },
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

class _TemplateCard extends StatelessWidget {
  final QuickTemplate template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = Theme.of(context).extension<AppColors>()!;
    final appState = context.read<AppState>();
    final isIncome = template.type == 'income';

    return AnimatedPressCard(
      borderRadius: BorderRadius.circular(Spacing.radiusLarge),
      border: Border.all(color: theme.colorScheme.outline),
      child: Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Spacing.radiusLarge),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.cardPadding,
          vertical: Spacing.sm,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isIncome
                ? appColors.incomeGreen.withAlpha((255 * 0.1).round())
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(Spacing.radiusMedium),
          ),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncome ? appColors.incomeGreen : theme.colorScheme.onSurface,
          ),
        ),
        title: Text(
          template.name,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          '${template.category} • ${template.paymentMethod}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${appState.currency}${template.amount.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isIncome ? appColors.incomeGreen : theme.colorScheme.onSurface,
              ),
            ),
            PopupMenuButton(
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
                      SizedBox(width: Spacing.sm),
                      Text('Use Template'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: Spacing.sm),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: appColors.expenseRed),
                      const SizedBox(width: Spacing.sm),
                      Text('Delete', style: TextStyle(color: appColors.expenseRed)),
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
                  // Add confirmation dialog before deleting template
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
                            final dialogAppColors = Theme.of(context).extension<AppColors>()!;
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
    // Optimize: Watch specific data, read for methods
    final categories = context.select<AppState, List<Category>>(
      (s) => _type == 'expense' ? s.expenseCategories : s.incomeCategories,
    );
    final appState = context.read<AppState>(); // For method calls

    // Ensure selected category is valid for current type
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
              // Type
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
              const SizedBox(height: Spacing.md),

              // Name
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

              // Amount
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
                  // FIX: Use parseDecimal to support both comma and dot as decimal separator
                  final amount = CurrencyHelper.parseDecimal(value!);
                  if (amount == null) return 'Invalid number';
                  // FIX #33: Validate amount must be greater than 0
                  if (amount <= 0) return 'Amount must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category - Using InputDecorator with DropdownButton to avoid deprecated value warning
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xs,
                  ),
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

              // Payment Method - Using InputDecorator with DropdownButton to avoid deprecated value warning
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xs,
                  ),
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
                // FIX: Use parseDecimal to support both comma and dot as decimal separator
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
