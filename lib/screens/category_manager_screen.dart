import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/category_model.dart';
import '../widgets/color_picker.dart';
import '../widgets/category_tile.dart';
import '../utils/category_icons.dart';

class CategoryManagerScreen extends StatelessWidget {
  const CategoryManagerScreen({super.key});

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
              'Categories',
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
                const _CategoryList(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategory(context),
        backgroundColor: theme.colorScheme.onSurface,
        child: Icon(Icons.add, color: theme.colorScheme.surface),
      ),
    );
  }

  static void _showAddCategory(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _AddCategoryDialog(),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Only watch categories
    final categories = context.select<AppState, List<Category>>((s) => s.categories);

    if (categories.isEmpty) {
      return _buildEmptyState(theme, context);
    }

    // Separate by type first, then by default/custom
    final expenseCategories = categories.where((c) => c.type == 'expense').toList();
    final incomeCategories = categories.where((c) => c.type == 'income').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Expense Categories
        if (expenseCategories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'EXPENSE CATEGORIES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              children: expenseCategories.asMap().entries.map((entry) {
                final category = entry.value;
                final isLast = entry.key == expenseCategories.length - 1;
                return _CategoryTileRow(
                  category: category.name,
                  categoryId: category.id,
                  categoryType: category.type,
                  categoryColor: category.color,
                  categoryIcon: category.icon,
                  isDefault: category.isDefault,
                  isLast: isLast,
                  theme: theme,
                  onEdit: () => _showEditCategory(
                    context,
                    category.id!,
                    category.name,
                    category.type,
                  ),
                  onDelete: category.isDefault ? null : () => _confirmDelete(
                    context,
                    category.id!,
                    category.name,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Income Categories
        if (incomeCategories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'INCOME CATEGORIES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              children: incomeCategories.asMap().entries.map((entry) {
                final category = entry.value;
                final isLast = entry.key == incomeCategories.length - 1;
                return _CategoryTileRow(
                  category: category.name,
                  categoryId: category.id,
                  categoryType: category.type,
                  categoryColor: category.color,
                  categoryIcon: category.icon,
                  isDefault: category.isDefault,
                  isLast: isLast,
                  theme: theme,
                  onEdit: () => _showEditCategory(
                    context,
                    category.id!,
                    category.name,
                    category.type,
                  ),
                  onDelete: category.isDefault ? null : () => _confirmDelete(
                    context,
                    category.id!,
                    category.name,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, BuildContext context) {
    return GestureDetector(
      onTap: () => CategoryManagerScreen._showAddCategory(context),
      child: Container(
        padding: const EdgeInsets.all(60),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          children: [
            Icon(
              Icons.category_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No categories',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap here or + to add a category',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIX #2: Pass type to edit dialog
  void _showEditCategory(BuildContext context, int id, String name, String type) {
    showDialog(
      context: context,
      builder: (context) => _AddCategoryDialog(
        categoryId: id,
        initialName: name,
        categoryType: type,
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id, String name) async {
    final appState = context.read<AppState>();

    // Get the category type to show appropriate options
    final categoryIndex = appState.categories.indexWhere((c) => c.id == id);
    if (categoryIndex == -1) return; // Category not found
    final category = appState.categories[categoryIndex];

    // CRITICAL FIX: Prevent deleting the last category of its type
    final categoriesOfSameType = appState.categories.where((c) => c.type == category.type).toList();
    if (categoriesOfSameType.length <= 1) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Category'),
          content: Text(
            'Cannot delete the last ${category.type} category. '
            'You must have at least one ${category.type} category to add ${category.type == "expense" ? "expenses" : "income"}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final usage = appState.getCategoryUsageInRecurring(name);
    final recurringExpenseCount = usage['recurringExpenses'] ?? 0;
    final recurringIncomeCount = usage['recurringIncome'] ?? 0;
    final hasRecurringUsage = recurringExpenseCount > 0 || recurringIncomeCount > 0;

    // FIX: Use efficient database count instead of loading all transactions into memory
    final existingTransactionCount = await appState.countTransactionsByCategory(name, category.type);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => _DeleteCategoryDialog(
        categoryId: id,
        categoryName: name,
        categoryType: category.type,
        hasRecurringUsage: hasRecurringUsage,
        recurringExpenseCount: recurringExpenseCount,
        recurringIncomeCount: recurringIncomeCount,
        existingTransactionCount: existingTransactionCount,
      ),
    );
  }
}

class _CategoryTileRow extends StatelessWidget {
  final String category;
  final int? categoryId;
  final String categoryType;
  final String? categoryColor;
  final String? categoryIcon;
  final bool isDefault;
  final bool isLast;
  final ThemeData theme;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CategoryTileRow({
    required this.category,
    this.categoryId,
    required this.categoryType,
    this.categoryColor,
    this.categoryIcon,
    required this.isDefault,
    required this.isLast,
    required this.theme,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withAlpha(100),
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: CategoryTileSmall(
          categoryName: category,
          categoryType: categoryType,
          color: categoryColor,
          icon: categoryIcon,
        ),
        title: Text(
          category,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: isDefault
            ? Text(
          'Default',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: onEdit,
            ),
            if (!isDefault)
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddCategoryDialog extends StatefulWidget {
  final int? categoryId;
  final String? initialName;
  final String? categoryType;

  const _AddCategoryDialog({
    this.categoryId,
    this.initialName,
    this.categoryType,
  });

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  late TextEditingController _nameController;
  String _selectedType = 'expense';
  String? _selectedColor;
  String? _selectedIcon;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedType = widget.categoryType ?? 'expense';

    // Load existing color and icon if editing
    if (widget.categoryId != null) {
      final appState = context.read<AppState>();
      final category = appState.categories.firstWhere(
        (c) => c.id == widget.categoryId,
        orElse: () => Category(name: widget.initialName ?? '', type: widget.categoryType ?? 'expense', accountId: 0),
      );
      _selectedColor = category.color;
      _selectedIcon = category.icon;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.categoryId != null;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isEditing ? 'Edit Category' : 'Add Category',
        style: TextStyle(color: theme.colorScheme.onSurface),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Category Name',
              hintText: 'e.g., Coffee, Pets, Gaming',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (!isEditing) ...[
            const SizedBox(height: 20),
            Text(
              'Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TypeChip(
                    label: 'Expense',
                    isSelected: _selectedType == 'expense',
                    color: Colors.red,
                    onTap: () => setState(() => _selectedType = 'expense'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeChip(
                    label: 'Income',
                    isSelected: _selectedType == 'income',
                    color: Colors.green,
                    onTap: () => setState(() => _selectedType = 'income'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Color (Optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showColorPicker(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _selectedColor != null
                          ? ColorPicker.parseColor(_selectedColor)
                          : theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.outline.withAlpha(100),
                      ),
                    ),
                    child: _selectedColor == null
                        ? Icon(
                            Icons.block,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 16,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedColor == null ? 'No color' : 'Color selected',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.palette_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Icon',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showIconPicker(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _selectedColor != null
                          ? ColorPicker.parseColor(_selectedColor).withAlpha(30)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      CategoryIcons.getIcon(_selectedIcon, widget.initialName ?? '', _selectedType),
                      color: _selectedColor != null
                          ? ColorPicker.parseColor(_selectedColor)
                          : theme.colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedIcon != null ? 'Custom icon' : 'Default icon',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.apps_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (isEditing) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All existing transactions will be updated to the new name.',
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Save'),
        ),
      ],
    );
  }

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ColorPicker(
        selectedColor: _selectedColor,
        onColorSelected: (color) {
          setState(() => _selectedColor = color);
        },
      ),
    );
  }

  void _showIconPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _IconPicker(
        selectedIcon: _selectedIcon,
        selectedColor: _selectedColor,
        onIconSelected: (icon) {
          setState(() => _selectedIcon = icon);
        },
      ),
    );
  }

  Future<void> _save() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      _showError('Please enter a category name');
      return;
    }

    // Validate category name length
    if (newName.length > 50) {
      _showError('Category name must be 50 characters or less');
      return;
    }

    // Validate category name doesn't contain problematic characters
    if (newName.contains(RegExp(r'[<>"\\/]'))) {
      _showError('Category name cannot contain special characters like < > " \\ /');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final appState = context.read<AppState>();

      if (widget.categoryId != null) {
        // FIX #2: Pass old name to cascade rename
        final categoryIndex = appState.categories.indexWhere((c) => c.id == widget.categoryId);
        if (categoryIndex == -1) {
          if (mounted) _showError('Category no longer exists');
          return;
        }
        final category = appState.categories[categoryIndex];
        final oldName = category.name;
        final updated = category.copyWith(name: newName, color: _selectedColor, icon: _selectedIcon);
        await appState.updateCategory(updated, oldName: oldName);
      } else {
        await appState.addCategory(newName, type: _selectedType, color: _selectedColor, icon: _selectedIcon);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('Failed to save category');
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
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(20) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? color : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon picker bottom sheet for selecting category icons
class _IconPicker extends StatelessWidget {
  final String? selectedIcon;
  final String? selectedColor;
  final Function(String?) onIconSelected;

  const _IconPicker({
    this.selectedIcon,
    this.selectedColor,
    required this.onIconSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = selectedColor != null
        ? ColorPicker.parseColor(selectedColor)
        : theme.colorScheme.primary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Choose Icon',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select an icon for this category',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  // Default option (null = use default based on category name)
                  GestureDetector(
                    onTap: () {
                      onIconSelected(null);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedIcon == null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withAlpha(100),
                          width: selectedIcon == null ? 3 : 1,
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                  ),
                  // All available icons
                  ...CategoryIcons.availableIcons.map((icon) {
                    final iconStr = CategoryIcons.iconToString(icon);
                    final isSelected = selectedIcon == iconStr;

                    return GestureDetector(
                      onTap: () {
                        onIconSelected(iconStr);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? iconColor.withAlpha(30)
                              : theme.colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? iconColor
                                : theme.colorScheme.outline.withAlpha(100),
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected
                              ? iconColor
                              : theme.colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DeleteCategoryDialog extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  final String categoryType;
  final bool hasRecurringUsage;
  final int recurringExpenseCount;
  final int recurringIncomeCount;
  final int existingTransactionCount;

  const _DeleteCategoryDialog({
    required this.categoryId,
    required this.categoryName,
    required this.categoryType,
    required this.hasRecurringUsage,
    required this.recurringExpenseCount,
    required this.recurringIncomeCount,
    required this.existingTransactionCount,
  });

  @override
  State<_DeleteCategoryDialog> createState() => _DeleteCategoryDialogState();
}

class _DeleteCategoryDialogState extends State<_DeleteCategoryDialog> {
  // FIX: Default to 'move' to prevent orphaned categories
  String _selectedAction = 'move'; // 'delete' or 'move'
  String? _selectedMoveToCategory;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Only watch specific category lists
    final availableCategories = context.select<AppState, List<String>>((s) {
      final categories = widget.categoryType == 'expense'
          ? s.expenseCategories
          : s.incomeCategories;
      return categories.where((c) => c.name != widget.categoryName).map((c) => c.name).toList();
    });

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Delete Category?',
        style: TextStyle(color: theme.colorScheme.onSurface),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete "${widget.categoryName}"?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),

            if (widget.existingTransactionCount > 0) ...[
              const SizedBox(height: 16),
              // CRITICAL FIX: Make transaction impact more prominent with warning color
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Impact Warning',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.existingTransactionCount} existing transaction${widget.existingTransactionCount > 1 ? 's' : ''} will be affected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This includes all historical transactions using "${widget.categoryName}"',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'What should happen to these transactions?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 12),

              // FIX: Removed "keep" option to prevent orphaned categories
              // Option 1: Delete transactions
              _buildOption(
                theme,
                value: 'delete',
                title: 'Delete transactions',
                subtitle: 'All ${widget.existingTransactionCount} transaction${widget.existingTransactionCount > 1 ? 's' : ''} will be moved to trash',
                icon: Icons.delete_outline,
                color: Colors.red,
              ),

              const SizedBox(height: 8),

              // Option 2: Move to another category (FIX: Always enabled, creates "Uncategorized" if needed)
              _buildOption(
                theme,
                value: 'move',
                title: 'Move to another category',
                subtitle: availableCategories.isEmpty
                    ? 'Will create "Uncategorized" category automatically'
                    : 'Reassign transactions to a different category',
                icon: Icons.drive_file_move_outlined,
                color: Colors.green,
                isDisabled: false,
              ),

              // Category picker for move option
              if (_selectedAction == 'move') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMoveToCategory,
                      hint: const Text('Select category'),
                      isExpanded: true,
                      items: availableCategories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedMoveToCategory = value);
                      },
                    ),
                  ),
                ),
              ],
            ],

            // Warning for recurring usage
            if (widget.hasRecurringUsage) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Used by Recurring Transactions',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (widget.recurringExpenseCount > 0)
                      Text(
                        '• ${widget.recurringExpenseCount} recurring expense${widget.recurringExpenseCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (widget.recurringIncomeCount > 0)
                      Text(
                        '• ${widget.recurringIncomeCount} recurring income${widget.recurringIncomeCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'These will continue using "${widget.categoryName}" but it won\'t appear in category lists.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          // FIX: Allow deletion even without category selection if no categories exist
          // (will create "Uncategorized" automatically)
          onPressed: _isDeleting
              ? null
              : _handleDelete,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: _isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.hasRecurringUsage ? 'Delete Anyway' : 'Delete'),
        ),
      ],
    );
  }

  Widget _buildOption(
    ThemeData theme, {
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isDisabled = false, // FIX: Support disabled state
  }) {
    final isSelected = _selectedAction == value;

    return InkWell(
      onTap: isDisabled ? null : () => setState(() => _selectedAction = value), // FIX: Disable if no categories
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(20) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? color : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDelete() async {
    setState(() => _isDeleting = true);

    try {
      final appState = context.read<AppState>();

      switch (_selectedAction) {
        case 'delete':
          // FIX #3: Use atomic delete operation to prevent data inconsistency
          // Both transactions AND category are deleted in single database transaction
          await appState.deleteTransactionsAndCategory(
            widget.categoryId,
            widget.categoryName,
            widget.categoryType,
          );
          break;

        case 'move':
          // FIX: If no category selected and no categories available, create "Uncategorized"
          String targetCategory = _selectedMoveToCategory ?? '';

          if (targetCategory.isEmpty) {
            // No category selected - check if we need to create "Uncategorized"
            final availableCategories = widget.categoryType == 'expense'
                ? appState.expenseCategories
                    .where((c) => c.id != widget.categoryId)
                    .map((c) => c.name)
                    .toList()
                : appState.incomeCategories
                    .where((c) => c.id != widget.categoryId)
                    .map((c) => c.name)
                    .toList();

            if (availableCategories.isEmpty) {
              // Create "Uncategorized" category
              await appState.addCategory('Uncategorized', type: widget.categoryType);
              targetCategory = 'Uncategorized';
            } else {
              // This shouldn't happen, but safety fallback
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a category'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
          }

          // FIX #3: Use atomic reassign operation to prevent data inconsistency
          // Both reassignment AND category deletion happen in single database transaction
          await appState.reassignCategoryAndDelete(
            widget.categoryId,
            widget.categoryName,
            targetCategory,
            widget.categoryType,
          );
          break;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedAction == 'delete'
                  ? 'Category and ${widget.existingTransactionCount} transaction${widget.existingTransactionCount > 1 ? 's' : ''} deleted'
                  : _selectedAction == 'move'
                      ? 'Category deleted and transactions moved to $_selectedMoveToCategory'
                      : 'Category deleted',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting category: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}