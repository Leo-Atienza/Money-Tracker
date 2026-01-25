import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/income_model.dart';
import '../utils/currency_helper.dart';
import '../utils/decimal_helper.dart';
import '../utils/validators.dart';
import '../utils/dialog_helpers.dart';
import '../utils/date_helper.dart';

class AddIncomeScreen extends StatefulWidget {
  final Income? income; // For editing

  const AddIncomeScreen({super.key, this.income});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryNameController =
      TextEditingController(); // FIX #1: For inline category creation

  String? _selectedCategory;
  // FIX: Will be set in initState to use selectedMonth from AppState (not today)
  late DateTime _selectedDate;
  bool _isSaving = false;
  Set<int> _selectedTagIds = {}; // FIX #1: Track selected tags

  // FIX: Track initial date to detect month changes
  DateTime? _initialDate;

  // FIX: Track initial values to detect form changes
  String? _initialAmount;
  String? _initialDescription;
  String? _initialCategory;

  // FIX #1: Track success animation state
  bool _showSuccessAnimation = false;

  @override
  void initState() {
    super.initState();
    if (widget.income != null) {
      _amountController.text = widget.income!.amount.toString();
      _descriptionController.text = widget.income!.description;
      _selectedCategory = widget.income!.category;
      _selectedDate = widget.income!.date;
      _initialDate = widget.income!.date; // FIX: Remember initial date
      // FIX: Remember initial values
      _initialAmount = widget.income!.amount.toString();
      _initialDescription = widget.income!.description;
      _initialCategory = widget.income!.category;
      // FIX #1: Load existing tags
      _loadExistingTags();
    } else {
      // FIX: For new income, use selectedMonth from AppState (not today)
      // This ensures income defaults to the month being viewed, not current date
      // Date will be set in didChangeDependencies when we have access to AppState
      // FIX: For new income, empty is the initial state
      _initialAmount = '';
      _initialDescription = '';
      _initialCategory = null; // Will be set to first available category
    }
  }

  bool _dateInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // FIX: Initialize date from AppState selectedMonth for new income
    if (!_dateInitialized && widget.income == null) {
      final appState = context.read<AppState>();
      final selectedMonth = appState.selectedMonth;
      // Default to first day of selected month at noon for consistent sorting
      _selectedDate = DateTime(selectedMonth.year, selectedMonth.month, 1, 12, 0, 0);
      _initialDate = _selectedDate;
      _dateInitialized = true;
    }
  }

  // FIX #1: Load tags for existing income
  Future<void> _loadExistingTags() async {
    if (widget.income?.id != null) {
      final appState = context.read<AppState>();
      final tags =
          await appState.getTagsForTransaction(widget.income!.id!, 'income');
      setState(() {
        _selectedTagIds = tags.map((tag) => tag.id!).toSet();
      });
    }
  }

  // FIX: Check if form has been modified
  bool _isFormDirty() {
    return _amountController.text != _initialAmount ||
        _descriptionController.text != _initialDescription ||
        _selectedCategory != _initialCategory ||
        _selectedDate != _initialDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _categoryNameController
        .dispose(); // FIX #1: Dispose category name controller
    super.dispose();
  }

  Future<void> _saveIncome() async {
    if (!_formKey.currentState!.validate()) return;

    // FIX #16: Check for future date and show confirmation
    if (Validators.isFutureDate(_selectedDate)) {
      final confirmed = await DialogHelpers.showFutureDateConfirmation(
        context,
        _selectedDate,
      );
      if (!confirmed) return;
    }

    // FIX #17: Add haptic feedback
    HapticFeedback.mediumImpact();

    if (!mounted) return;

    setState(() => _isSaving = true);

    try {
      final appState = context.read<AppState>();
      final amount = CurrencyHelper.parseDecimal(_amountController.text)!;
      // FIX #1: Ensure category is not null before using
      final category = _selectedCategory ?? 'Uncategorized';
      final description = _descriptionController.text.trim().isEmpty
          ? '$category income'
          : _descriptionController.text.trim();

      final income = Income(
        id: widget.income?.id,
        amount: DecimalHelper.fromDouble(amount),
        category: category,
        description: description,
        date: _selectedDate,
        accountId: appState.currentAccountId,
      );

      int? incomeId = widget.income?.id;
      if (widget.income == null) {
        await appState.addIncome(income);
        // Reload to get the ID
        incomeId = income.id;
      } else {
        await appState.updateIncome(income);
      }

      // FIX #1: Save tags for this income
      if (incomeId != null) {
        // Get existing tags to compare
        final existingTags =
            await appState.getTagsForTransaction(incomeId, 'income');
        final existingTagIds = existingTags.map((t) => t.id!).toSet();

        // Add new tags
        for (final tagId in _selectedTagIds) {
          if (!existingTagIds.contains(tagId)) {
            await appState.addTagToTransaction(incomeId, 'income', tagId);
          }
        }

        // Remove unselected tags
        for (final tagId in existingTagIds) {
          if (!_selectedTagIds.contains(tagId)) {
            await appState.removeTagFromTransaction(incomeId, 'income', tagId);
          }
        }
      }

      // FIX #1: Show success animation
      if (mounted) {
        setState(() => _showSuccessAnimation = true);
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // FIX: Show feedback if saved to different month than currently viewed
      final currentViewedMonth = appState.selectedMonth;
      final isDifferentMonth =
          _selectedDate.month != currentViewedMonth.month ||
              _selectedDate.year != currentViewedMonth.year;

      if (mounted && isDifferentMonth) {
        final monthName = DateFormat.MMMM().format(_selectedDate);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Income saved to $monthName (not visible in current month)'),
            action: SnackBarAction(
              label: 'Switch to $monthName',
              onPressed: () {
                appState.goToMonth(_selectedDate);
              },
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving income: $e'),
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

  Future<void> _deleteIncome() async {
    if (widget.income?.id == null) return;

    // FIX #17: Add haptic feedback
    HapticFeedback.lightImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Income'),
        content: const Text('Are you sure you want to delete this income?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      await appState.deleteIncome(widget.income!.id!);
      if (mounted) {
        Navigator.pop(context);
        // FIX #3: Add undo functionality like expense delete
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Income moved to trash'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await appState.undoDelete();
              },
            ),
          ),
        );
      }
    }
  }

  // FIX #1: Show dialog to create a new tag
  Future<void> _showCreateTagDialog(
      BuildContext context, AppState appState) async {
    final tagNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Tag'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: tagNameController,
            autofocus: true,
            maxLength: 50,
            decoration: const InputDecoration(
              hintText: 'Tag name',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a tag name';
              }
              if (value.trim().length > 50) {
                return 'Tag name cannot exceed 50 characters';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && tagNameController.text.trim().isNotEmpty) {
      final tagName = tagNameController.text.trim();
      if (!mounted) return;
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      await appState.addTag(tagName);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Tag "$tagName" created'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    tagNameController.dispose();
  }

  // FIX #1: Show dialog to create a new category with name length validation
  Future<void> _showCreateCategoryDialog(
      BuildContext context, AppState appState) async {
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: _categoryNameController,
            autofocus: true,
            maxLength: 50,
            decoration: InputDecoration(
              hintText: 'Category name',
              border: const OutlineInputBorder(),
              helperText: 'Max 50 characters',
              helperStyle: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a category name';
              }
              if (value.trim().length > 50) {
                return 'Category name cannot exceed 50 characters';
              }
              // Check for duplicate category
              if (appState.incomeCategories.any((cat) =>
                  cat.name.toLowerCase() == value.trim().toLowerCase())) {
                return 'This category already exists';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && _categoryNameController.text.trim().isNotEmpty) {
      final categoryName = _categoryNameController.text.trim();
      if (!mounted) return;
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      await appState.addCategory(categoryName, type: 'income');
      if (!mounted) return;
      setState(() {
        _selectedCategory = categoryName;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Category "$categoryName" created'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _categoryNameController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();

    // FIX #1: Set default category to first available if not set (prevents ghost categories)
    final availableCategories =
        appState.categories.where((c) => c.type == 'income').toList();
    if (_selectedCategory == null && availableCategories.isNotEmpty) {
      _selectedCategory = availableCategories[0].name;
      _initialCategory = _selectedCategory;
    }

    // FIX: Wrap with PopScope to warn about unsaved changes
    return PopScope(
      canPop: !_isFormDirty(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Form is dirty, show confirmation dialog
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text(
                'You have unsaved changes. Are you sure you want to discard them?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Discard'),
              ),
            ],
          ),
        );

        if (shouldDiscard == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      // FIX #1: Wrap in Stack to add success animation overlay
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: theme.colorScheme.surface,
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
              ),
              actions: widget.income != null
                  ? [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _deleteIncome,
                        tooltip: 'Delete income',
                      ),
                    ]
                  : null,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.income == null ? 'Add Income' : 'Edit Income',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount
                        Text(
                          'AMOUNT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _amountController,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            CurrencyHelper.decimalInputFormatter()
                          ],
                          style: const TextStyle(
                              fontSize: 32, fontWeight: FontWeight.w300),
                          decoration: InputDecoration(
                            prefixText: appState.currency,
                            prefixStyle: const TextStyle(
                                fontSize: 32, fontWeight: FontWeight.w300),
                            hintText: '0.00',
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }
                            final parsed = CurrencyHelper.parseDecimal(value);
                            if (parsed == null) {
                              return 'Please enter a valid number';
                            }
                            if (parsed <= 0) {
                              return 'Amount must be greater than 0';
                            }
                            // FIX #2: Add max amount validation
                            if (parsed > 999999999.99) {
                              return 'Amount cannot exceed 999,999,999.99';
                            }
                            return null;
                          },
                        ),

                        Divider(color: theme.colorScheme.outline),
                        const SizedBox(height: 32),

                        // Category
                        Text(
                          'CATEGORY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // FIX: Improved scrollable category selection for better UX with many categories
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // FIX #12: Show deleted/archived category if editing income with deleted category (with tooltip)
                                if (widget.income != null &&
                                    _selectedCategory != null &&
                                    !appState.incomeCategories.any(
                                        (cat) => cat.name == _selectedCategory))
                                  Tooltip(
                                    message:
                                        'This category was deleted but is preserved for historical data. You can reassign this income to an active category.',
                                    child: Chip(
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.archive_outlined,
                                              size: 16,
                                              color: theme.colorScheme.error),
                                          const SizedBox(width: 4),
                                          Text('$_selectedCategory (Archived)'),
                                          const SizedBox(width: 4),
                                          Icon(Icons.info_outline,
                                              size: 14,
                                              color: theme.colorScheme.error),
                                        ],
                                      ),
                                      backgroundColor: theme
                                          .colorScheme.errorContainer
                                          .withValues(alpha: 0.3),
                                      labelStyle: TextStyle(
                                        color: theme.colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      side: BorderSide(
                                          color: theme.colorScheme.error),
                                    ),
                                  ),
                                // Regular category chips
                                ...appState.incomeCategories.map((cat) {
                                  final isSelected =
                                      _selectedCategory == cat.name;
                                  return ChoiceChip(
                                    label: Text(cat.name),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(
                                          () => _selectedCategory = cat.name);
                                    },
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest,
                                    selectedColor: Colors.green
                                        .withAlpha((255 * 0.2).round()),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Colors.green
                                          : theme.colorScheme.onSurface,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    side: BorderSide(
                                      color: isSelected
                                          ? Colors.green
                                          : theme.colorScheme.outline,
                                    ),
                                  );
                                }),
                                // FIX #1: Add button to create new category
                                ActionChip(
                                  label: const Text('+ New Category'),
                                  onPressed: () => _showCreateCategoryDialog(
                                      context, appState),
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  side: BorderSide(
                                      color: theme.colorScheme.outline,
                                      style: BorderStyle.solid),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Description
                        Text(
                          'DESCRIPTION (OPTIONAL)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // FIX #1 & #9: Add character counter, show truncation warning
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _descriptionController,
                              textCapitalization: TextCapitalization.sentences,
                              maxLength: 200,
                              onChanged: (value) {
                                // Trigger rebuild to update counter
                                setState(() {});
                              },
                              decoration: InputDecoration(
                                hintText: 'Add notes (optional)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: theme.colorScheme.outline),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: theme.colorScheme.outline),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Colors.green, width: 2),
                                ),
                                // FIX #9: Character counter
                                counterText:
                                    '${_descriptionController.text.length}/200',
                                counterStyle: TextStyle(
                                  color:
                                      _descriptionController.text.length > 180
                                          ? Colors.orange
                                          : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              maxLines: 3,
                            ),
                            // FIX #9: Show warning when approaching limit
                            if (_descriptionController.text.length > 180)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 8, left: 12),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Approaching character limit (${200 - _descriptionController.text.length} remaining)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Date
                        Text(
                          'DATE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            // FIX #3: Limit date range to 5 years past, 1 year future
                            // CRITICAL FIX: Use centralized date range helpers for consistency
                            final now = DateTime.now();
                            final minDate = Validators.getTransactionMinDate();
                            final maxDate = Validators.getTransactionMaxDate();

                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate.isAfter(maxDate)
                                  ? now
                                  : (_selectedDate.isBefore(minDate)
                                      ? now
                                      : _selectedDate),
                              firstDate: minDate,
                              lastDate: maxDate,
                              helpText: 'Select Transaction Date',
                            );
                            if (date != null) {
                              // FIX #1: Make future date picker PREVENTIVE with confirmation dialog
                              if (DateHelper.isFuture(date)) {
                                if (!mounted) return;
                                // Show confirmation dialog for future dates
                                if (!context.mounted) return;
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: theme.colorScheme.surface,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    title: Row(
                                      children: [
                                        Icon(
                                          Icons.event_available,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Future Date Selected'),
                                      ],
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'You selected ${DateFormat.yMMMMd().format(date)}, which is in the future.',
                                          style: TextStyle(
                                              color: theme.colorScheme
                                                  .onSurfaceVariant),
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withAlpha(30),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.orange
                                                    .withAlpha(100)),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.info_outline,
                                                  color: Colors.orange,
                                                  size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'This income will appear in ${DateFormat.MMMM().format(date)}\'s transactions, not in the current month.',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color: theme.colorScheme
                                                          .onSurface),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Do you want to continue?',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.orange,
                                        ),
                                        child: const Text('Continue'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed != true) {
                                  return; // Don't update the date if user cancelled
                                }
                              }

                              // Normalize the selected date to UTC midnight
                              setState(() => _selectedDate = DateHelper.normalize(date));
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: theme.colorScheme.outline),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat.yMMMMEEEEd().format(
                                      _selectedDate), // FIX: Locale-aware long date
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // FIX #1: Tags Section
                        Text(
                          'TAGS (OPTIONAL)',
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
                          children: [
                            ...appState.allTags.map((tag) {
                              final isSelected =
                                  _selectedTagIds.contains(tag.id);
                              return FilterChip(
                                label: Text(tag.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedTagIds.add(tag.id!);
                                    } else {
                                      _selectedTagIds.remove(tag.id);
                                    }
                                  });
                                },
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                selectedColor:
                                    Colors.green.withAlpha((255 * 0.2).round()),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.green
                                      : theme.colorScheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.green
                                      : theme.colorScheme.outline,
                                ),
                              );
                            }),
                            // Add tag button
                            ActionChip(
                              label: const Text('+ New Tag'),
                              onPressed: () =>
                                  _showCreateTagDialog(context, appState),
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              side: BorderSide(
                                  color: theme.colorScheme.outline,
                                  style: BorderStyle.solid),
                            ),
                          ],
                        ),

                        // Extra padding at bottom
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // FIX #4: Use bottomNavigationBar instead of Positioned widget
            bottomNavigationBar: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outline),
                ),
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveIncome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.income == null
                              ? 'Add Income'
                              : 'Update Income',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ), // Close Scaffold
          // FIX #1: Show success animation overlay when saving completes
          if (_showSuccessAnimation) _buildSuccessOverlay(theme),
        ], // Close Stack children
      ), // Close Stack
    ); // Close PopScope
  }

  // FIX #1: Build success animation overlay
  Widget _buildSuccessOverlay(ThemeData theme) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
