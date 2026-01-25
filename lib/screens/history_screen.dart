import 'dart:async';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/expense_model.dart';
import '../models/income_model.dart';
import '../utils/validators.dart';
import '../utils/date_helper.dart';
import '../utils/progress_indicator_helper.dart';
import '../utils/premium_animations.dart';
import '../widgets/category_tile.dart';
import 'add_expense_screen.dart';
import 'add_income_screen.dart';
import 'add_payment_dialog.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchTerm = '';
  String _filterCategory = 'All';
  bool _searchAllTime = false;
  List<Expense> _allTimeExpenses = [];
  List<Income> _allTimeIncome = [];
  bool _isLoadingAllTime = false;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  // FIX P3-15: Documented pagination constants
  /// Number of items to load per page for infinite scroll.
  /// 50 provides a good balance between UI responsiveness and network efficiency.
  static const int _pageSize = 50;
  /// Maximum total items to load in "All Time" view to prevent unbounded memory growth.
  /// 1000 items is sufficient for most use cases while keeping memory usage reasonable.
  /// Users with more transactions should use date filters for better performance.
  static const int _maxTotalResults = 1000;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // FIX: Debounce timer for search performance (reduced to 300ms for better responsiveness)
  Timer? _debounce;

  // FIX: Remember previous All Time state before search
  bool _previousAllTimeState = false;

  // FIX: Date range filtering
  DateTimeRange? _dateRange;

  // CRITICAL FIX #1: Request ID for deduplication - prevents race conditions
  int _lastRequestId = 0;

  // CRITICAL FIX #2: Cancellation tokens for in-flight requests
  final Set<int> _cancelledRequestIds = {};

  // FIX: Payment status filter for expenses
  String _paymentStatusFilter = 'all'; // 'all', 'unpaid', 'partial', 'paid'

  // Sort order for transactions
  String _sortOrder = 'newest'; // 'newest', 'oldest', 'highest', 'lowest', 'category'

  // CRITICAL FIX #3: Track active operations for proper cleanup
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
  }

  // CRITICAL FIX #2: Clean up old cancelled request IDs to prevent memory leak
  void _cleanupCancelledRequests() {
    // Keep only the last 10 cancelled IDs to prevent unbounded growth
    if (_cancelledRequestIds.length > 10) {
      final sortedIds = _cancelledRequestIds.toList()..sort();
      final toRemove = sortedIds.take(_cancelledRequestIds.length - 10);
      _cancelledRequestIds.removeAll(toRemove);
    }
  }

  // CRITICAL FIX #3: Handle memory pressure by clearing cached data
  void _handleMemoryPressure() {
    if (_isDisposed) return;

    // Clear cached all-time data if we have too many items loaded
    final totalLoaded = _allTimeExpenses.length + _allTimeIncome.length;
    if (totalLoaded > _maxTotalResults * 0.8) {
      if (kDebugMode) debugPrint('Memory pressure: clearing cached data (total items: $totalLoaded)');

      if (mounted && !_isDisposed) {
        setState(() {
          // Keep only the first page of results
          if (_allTimeExpenses.length > _pageSize) {
            _allTimeExpenses = _allTimeExpenses.take(_pageSize).toList();
          }
          if (_allTimeIncome.length > _pageSize) {
            _allTimeIncome = _allTimeIncome.take(_pageSize).toList();
          }
          _hasMoreData = true;
        });
      }
    }
  }

  void _onScroll() {
    // CRITICAL FIX #3: Don't process if disposed
    if (_isDisposed) return;

    // FIX #4: Check max results limit to prevent unbounded memory growth
    if (!_searchAllTime || !_hasMoreData || _isLoadingMore) return;
    final totalLoaded = _allTimeExpenses.length + _allTimeIncome.length;
    if (totalLoaded >= _maxTotalResults) {
      if (mounted) {
        setState(() => _hasMoreData = false);
      }
      return;
    }
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      // CRITICAL FIX #2: Cancel debounce timer and in-flight requests when switching tabs
      _debounce?.cancel();

      // CRITICAL FIX #1: Cancel all in-flight requests on tab change
      if (_lastRequestId > 0) {
        _cancelledRequestIds.add(_lastRequestId);
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _filterCategory = 'All';
          // FIX: Reset payment filter when switching tabs
          _paymentStatusFilter = 'all';
          // CRITICAL FIX: Clear search state when switching tabs
          // Prevents "Food" search in Expenses from filtering Income tab
          _searchTerm = '';
          _searchController.clear();
        });
      }
    }
  }

  @override
  void dispose() {
    // CRITICAL FIX #3: Mark as disposed and cancel all operations
    _isDisposed = true;
    _debounce?.cancel(); // Cancel debounce timer

    // CRITICAL FIX #2: Cancel all in-flight requests by incrementing and clearing
    _lastRequestId++;
    _cancelledRequestIds.clear();

    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _showEditExpenseDialog(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseScreen(expense: expense),
    );
  }

  void _showEditIncomeDialog(BuildContext context, Income income) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddIncomeScreen(income: income),
      ),
    );
  }

  // FIX: Date range picker
  Future<void> _showDateRangePicker(BuildContext context) async {
    final now = DateTime.now();
    // CRITICAL FIX: Use centralized date range helpers for consistency
    final picked = await showDateRangePicker(
      context: context,
      firstDate: Validators.getFilterMinDate(),
      lastDate: Validators.getFilterMaxDate(),
      initialDateRange: _dateRange ?? DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // FIX #10: Validate date range (max 2 years)
      final rangeDuration = picked.end.difference(picked.start).inDays;
      if (rangeDuration > 730) { // 2 years ≈ 730 days
        if (!mounted) return;
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Date Range Too Large'),
            content: const Text(
              'Please select a date range of 2 years or less for better performance. '
              'Large date ranges may cause the app to slow down.',
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

      setState(() {
        _dateRange = picked;
        // Enable all-time search when using date range
        if (!_searchAllTime) {
          _searchAllTime = true;
          _loadAllTimeData();
        }
      });
    }
  }

  String _formatDateRange(DateTimeRange range) {
    final start = DateFormat('MMM d').format(range.start);
    final end = DateFormat('MMM d').format(range.end);
    if (range.start.year != range.end.year) {
      return '${DateFormat('MMM d, yy').format(range.start)} - ${DateFormat('MMM d, yy').format(range.end)}';
    }
    return '$start - $end';
  }

  // FIX: Filter items by date range
  bool _isInDateRange(DateTime date) {
    if (_dateRange == null) return true;
    final dateOnly = DateHelper.normalize(date);
    final startOnly = DateHelper.normalize(_dateRange!.start);
    final endOnly = DateHelper.normalize(_dateRange!.end);
    return !dateOnly.isBefore(startOnly) && !dateOnly.isAfter(endOnly);
  }

  void _showAddPaymentDialog(BuildContext context, Expense expense) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AddPaymentDialog(expense: expense),
    );
  }

  Future<void> _loadAllTimeData() async {
    // CRITICAL FIX #3: Don't start new operations if disposed
    if (_isDisposed || _isLoadingAllTime) return;

    // CRITICAL FIX #1: Cancel previous request before starting new one
    if (_lastRequestId > 0) {
      _cancelledRequestIds.add(_lastRequestId);
    }

    // CRITICAL FIX #1: Increment request ID for deduplication
    _lastRequestId++;
    final requestId = _lastRequestId;

    setState(() {
      _isLoadingAllTime = true;
      _hasMoreData = true;
      _allTimeExpenses = [];
      _allTimeIncome = [];
    });

    try {
      final appState = context.read<AppState>();

      // CRITICAL FIX #3: Add timeout to prevent hanging operations
      final result = await appState.searchTransactionsUnified(
        _searchTerm,
        limit: _pageSize,
        category: _filterCategory,
        startDate: _dateRange?.start.toIso8601String(),
        endDate: _dateRange?.end.toIso8601String(),
        sortOrder: _sortOrder,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Search operation timed out');
        },
      );

      // CRITICAL FIX #2: Check if request was cancelled during execution
      if (_cancelledRequestIds.contains(requestId)) {
        _cancelledRequestIds.remove(requestId);
        _cleanupCancelledRequests();
        return;
      }

      // CRITICAL FIX #1: Only update if this is still the latest request and not disposed
      if (!_isDisposed && mounted && requestId == _lastRequestId) {
        setState(() {
          _allTimeExpenses = result['expenses'] as List<Expense>;
          _allTimeIncome = result['income'] as List<Income>;
          _isLoadingAllTime = false;
          _hasMoreData = result['hasMore'] as bool;
        });
        // CRITICAL FIX #2: Clean up old cancelled requests
        _cleanupCancelledRequests();
      }
    } catch (e) {
      // CRITICAL FIX #2: Clean up cancelled request
      _cancelledRequestIds.remove(requestId);
      _cleanupCancelledRequests();

      // CRITICAL FIX #1: Only update state if still valid
      if (!_isDisposed && mounted && requestId == _lastRequestId) {
        setState(() => _isLoadingAllTime = false);
        // ENHANCED ERROR HANDLING: Log error for debugging
        if (kDebugMode) debugPrint('Error loading all-time data: $e');
      }
    }
  }

  Future<void> _loadMoreData() async {
    // CRITICAL FIX #3: Don't start new operations if disposed
    if (_isDisposed || _isLoadingMore || !_hasMoreData) return;

    // CRITICAL FIX #1: Cancel previous pagination request before starting new one
    // Note: We use a separate request ID chain for pagination to avoid conflicts
    if (_lastRequestId > 0) {
      _cancelledRequestIds.add(_lastRequestId);
    }

    // CRITICAL FIX #1: Increment request ID for deduplication
    _lastRequestId++;
    final requestId = _lastRequestId;

    setState(() => _isLoadingMore = true);

    try {
      final appState = context.read<AppState>();
      // FIX: Calculate offset based on total loaded transactions
      final offset = _allTimeExpenses.length + _allTimeIncome.length;

      // CRITICAL FIX #3: Add timeout to prevent hanging operations
      final result = await appState.searchTransactionsUnified(
        _searchTerm,
        limit: _pageSize,
        offset: offset,
        category: _filterCategory,
        startDate: _dateRange?.start.toIso8601String(),
        endDate: _dateRange?.end.toIso8601String(),
        sortOrder: _sortOrder,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Load more operation timed out');
        },
      );

      // CRITICAL FIX #2: Check if request was cancelled during execution
      if (_cancelledRequestIds.contains(requestId)) {
        _cancelledRequestIds.remove(requestId);
        _cleanupCancelledRequests();
        return;
      }

      // CRITICAL FIX #1: Only update if this is still the latest request and not disposed
      if (!_isDisposed && mounted && requestId == _lastRequestId) {
        setState(() {
          _allTimeExpenses.addAll(result['expenses'] as List<Expense>);
          _allTimeIncome.addAll(result['income'] as List<Income>);
          _isLoadingMore = false;
          _hasMoreData = result['hasMore'] as bool;
        });
        // CRITICAL FIX #2: Clean up old cancelled requests
        _cleanupCancelledRequests();
        // CRITICAL FIX #3: Check memory pressure after loading more data
        _handleMemoryPressure();
      }
    } catch (e) {
      // CRITICAL FIX #2: Clean up cancelled request
      _cancelledRequestIds.remove(requestId);
      _cleanupCancelledRequests();

      // CRITICAL FIX #1: Only update state if still valid
      if (!_isDisposed && mounted && requestId == _lastRequestId) {
        setState(() => _isLoadingMore = false);
        // ENHANCED ERROR HANDLING: Log error for debugging
        if (kDebugMode) debugPrint('Error loading more data: $e');
      }
    }
  }

  // FIX: Enhanced search that checks description, category, and amount
  // Search amounts as-is without rounding to avoid confusion (e.g., $50.90 shouldn't match "51")
  bool _matchesSearch(dynamic item, String searchTerm) {
    if (searchTerm.isEmpty) return true;

    // FIX: Multi-token search - split by space and require all tokens to match
    final tokens = searchTerm.toLowerCase().trim().split(RegExp(r'\s+'));

    if (item is Expense) {
      // FIX: Search exact amount with decimals, and integer part without rounding
      final amountStr = item.amount.toStringAsFixed(2); // e.g., "50.90"
      final integerPart = item.amount.truncate().toString(); // e.g., "50" (no rounding!)
      final descriptionLower = item.description.toLowerCase();
      final categoryLower = item.category.toLowerCase();

      // All tokens must match at least one field
      return tokens.every((token) =>
          descriptionLower.contains(token) ||
          categoryLower.contains(token) ||
          amountStr.contains(token) ||
          integerPart.contains(token));
    } else if (item is Income) {
      final amountStr = item.amount.toStringAsFixed(2);
      final integerPart = item.amount.truncate().toString();
      final descriptionLower = item.description.toLowerCase();
      final categoryLower = item.category.toLowerCase();

      // All tokens must match at least one field
      return tokens.every((token) =>
          descriptionLower.contains(token) ||
          categoryLower.contains(token) ||
          amountStr.contains(token) ||
          integerPart.contains(token));
    }
    return false;
  }

  // FIX: Check if expense matches payment status filter
  // Uses Decimal comparison via isPaid getter for accuracy (avoids floating-point issues)
  bool _matchesPaymentStatus(Expense expense) {
    switch (_paymentStatusFilter) {
      case 'unpaid':
        // FIX: Use Decimal comparison to avoid floating-point precision issues
        return expense.amountPaidDecimal == Decimal.zero;
      case 'partial':
        // FIX: Use Decimal comparison - has some payment but not fully paid
        return expense.amountPaidDecimal > Decimal.zero && !expense.isPaid;
      case 'paid':
        return expense.isPaid;
      case 'all':
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();

    return Scaffold(
      // FIX: Use Material standard dark background to prevent OLED smearing
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'History',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.onSurface,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicator: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                padding: const EdgeInsets.all(4),
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Expenses'),
                  Tab(text: 'Income'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Semantics(
                label: 'Search transactions by name, category, or amount',
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outline.withAlpha(50),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      // CRITICAL FIX #3: Reduced debounce from 500ms to 300ms for better responsiveness
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        // CRITICAL FIX #3: Don't process if disposed
                        if (_isDisposed) return;

                        setState(() {
                          _searchTerm = value;
                          // FIX: Auto-enable all-time search when user starts typing
                          if (value.isNotEmpty && !_searchAllTime) {
                            _previousAllTimeState = _searchAllTime; // Remember state
                            _searchAllTime = true;
                            _loadAllTimeData();
                          } else if (value.isNotEmpty) {
                            // CRITICAL FIX #1: Reload with new search term (will cancel previous)
                            _loadAllTimeData();
                          } else if (value.isEmpty) {
                            // FIX: Restore previous All Time state when search is cleared
                            _searchAllTime = _previousAllTimeState;
                          }
                        });
                      });
                    },
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search transactions...', // FIX #18: Shorter placeholder
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                      suffixIcon: _searchTerm.isNotEmpty
                          ? Semantics(
                        label: 'Clear search',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchTerm = '');
                          },
                        ),
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // FIX: Compact filter bar - all filters in one horizontal scrollable row
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // All time toggle chip
                  Semantics(
                    label: _searchAllTime ? 'All time search enabled' : 'All time search disabled',
                    hint: 'Search across all months',
                    button: true,
                    child: FilterChip(
                      selected: _searchAllTime,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 16),
                          const SizedBox(width: 4),
                          Text('All time'),
                          if (_isLoadingAllTime) ...[
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                      onSelected: (value) {
                        setState(() => _searchAllTime = value);
                        if (value && _allTimeExpenses.isEmpty) {
                          _loadAllTimeData();
                        }
                      },
                      labelStyle: TextStyle(fontSize: 13),
                      backgroundColor: theme.colorScheme.surface,
                      selectedColor: theme.colorScheme.primary.withAlpha(30),
                      checkmarkColor: theme.colorScheme.primary,
                      side: BorderSide(
                        color: _searchAllTime
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withAlpha(80),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Date range chip
                  Semantics(
                    label: _dateRange != null
                        ? 'Date range: ${_formatDateRange(_dateRange!)}'
                        : 'Select date range',
                    button: true,
                    child: FilterChip(
                      selected: _dateRange != null,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.date_range, size: 16),
                          const SizedBox(width: 4),
                          Text(_dateRange != null ? _formatDateRange(_dateRange!) : 'Date range'),
                        ],
                      ),
                      onSelected: (_) => _showDateRangePicker(context),
                      onDeleted: _dateRange != null ? () => setState(() => _dateRange = null) : null,
                      deleteIcon: _dateRange != null ? Icon(Icons.close, size: 16) : null,
                      labelStyle: TextStyle(fontSize: 13),
                      backgroundColor: theme.colorScheme.surface,
                      selectedColor: theme.colorScheme.primary.withAlpha(30),
                      checkmarkColor: theme.colorScheme.primary,
                      side: BorderSide(
                        color: _dateRange != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withAlpha(80),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Sort order chip
                  Semantics(
                    label: 'Sort by: ${_getSortLabel(_sortOrder)}',
                    hint: 'Change sort order',
                    button: true,
                    child: FilterChip(
                      selected: _sortOrder != 'newest',
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getSortIcon(_sortOrder), size: 16),
                          const SizedBox(width: 4),
                          Text(_getSortLabel(_sortOrder)),
                        ],
                      ),
                      onSelected: (_) => _showSortOptions(context, theme),
                      labelStyle: TextStyle(fontSize: 13),
                      backgroundColor: theme.colorScheme.surface,
                      selectedColor: theme.colorScheme.primary.withAlpha(30),
                      checkmarkColor: theme.colorScheme.primary,
                      side: BorderSide(
                        color: _sortOrder != 'newest'
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withAlpha(80),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Category filters
                  ..._buildCompactCategoryFilters(theme, appState),

                  // Payment status filters (only for expenses tab)
                  if (_tabController.index == 1) ...[
                    const SizedBox(width: 8),
                    ..._buildCompactPaymentFilters(theme),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllList(context, appState, theme),
                  _buildExpensesList(context, appState, theme),
                  _buildIncomeList(context, appState, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIX: Build compact category filter chips for horizontal scroll
  List<Widget> _buildCompactCategoryFilters(ThemeData theme, AppState appState) {
    final Set<String> categorySet = {};

    if (_tabController.index == 0 || _tabController.index == 1) {
      categorySet.addAll(appState.allExpenseCategoryNames);
      if (_searchAllTime) {
        categorySet.addAll(_allTimeExpenses.map((e) => e.category));
      }
    } else {
      categorySet.addAll(appState.allIncomeCategoryNames);
      if (_searchAllTime) {
        categorySet.addAll(_allTimeIncome.map((i) => i.category));
      }
    }

    final categories = categorySet.toList()..sort();

    return categories.map((category) {
      final isSelected = _filterCategory == category;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          selected: isSelected,
          label: Text(category),
          onSelected: (selected) {
            setState(() => _filterCategory = selected ? category : 'All');
            if (_searchAllTime && _searchTerm.isNotEmpty) {
              _loadAllTimeData();
            }
          },
          labelStyle: TextStyle(fontSize: 13),
          backgroundColor: theme.colorScheme.surface,
          selectedColor: theme.colorScheme.onSurface,
          checkmarkColor: theme.colorScheme.surface,
          side: BorderSide(
            color: isSelected
                ? Colors.transparent
                : theme.colorScheme.outline.withAlpha(80),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }).toList();
  }

  // FIX: Build compact payment status filter chips
  List<Widget> _buildCompactPaymentFilters(ThemeData theme) {
    final statuses = [
      {'value': 'unpaid', 'label': 'Unpaid', 'icon': Icons.pending_outlined},
      {'value': 'partial', 'label': 'Partial', 'icon': Icons.payments_outlined},
      {'value': 'paid', 'label': 'Paid', 'icon': Icons.check_circle_outline},
    ];

    return statuses.map((status) {
      final isSelected = _paymentStatusFilter == status['value'];
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          selected: isSelected,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status['icon'] as IconData, size: 16),
              const SizedBox(width: 4),
              Text(status['label'] as String),
            ],
          ),
          onSelected: (selected) {
            setState(() => _paymentStatusFilter = selected ? status['value'] as String : 'all');
            if (_searchAllTime && _searchTerm.isNotEmpty) {
              _loadAllTimeData();
            }
          },
          labelStyle: TextStyle(fontSize: 13),
          backgroundColor: theme.colorScheme.surface,
          selectedColor: theme.colorScheme.onSurface,
          checkmarkColor: theme.colorScheme.surface,
          side: BorderSide(
            color: isSelected
                ? Colors.transparent
                : theme.colorScheme.outline.withAlpha(80),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }).toList();
  }

  // Sort option helpers
  String _getSortLabel(String sortOrder) {
    switch (sortOrder) {
      case 'newest':
        return 'Newest';
      case 'oldest':
        return 'Oldest';
      case 'highest':
        return 'Highest';
      case 'lowest':
        return 'Lowest';
      case 'category':
        return 'Category';
      default:
        return 'Newest';
    }
  }

  IconData _getSortIcon(String sortOrder) {
    switch (sortOrder) {
      case 'newest':
        return Icons.arrow_downward_rounded;
      case 'oldest':
        return Icons.arrow_upward_rounded;
      case 'highest':
        return Icons.trending_up_rounded;
      case 'lowest':
        return Icons.trending_down_rounded;
      case 'category':
        return Icons.category_rounded;
      default:
        return Icons.sort_rounded;
    }
  }

  void _showSortOptions(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allow the sheet to expand fully
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, // Start at 60% of screen
        minChildSize: 0.4, // Minimum 40%
        maxChildSize: 0.85, // Maximum 85%
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
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
                'Sort Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how to order your transactions',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              // Scrollable list of sort options
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    _buildSortOption(context, theme, 'newest', 'Newest First', 'Most recent transactions at the top', Icons.arrow_downward_rounded),
                    _buildSortOption(context, theme, 'oldest', 'Oldest First', 'Earliest transactions at the top', Icons.arrow_upward_rounded),
                    const Divider(height: 1),
                    _buildSortOption(context, theme, 'highest', 'Highest Amount', 'Largest amounts at the top', Icons.trending_up_rounded),
                    _buildSortOption(context, theme, 'lowest', 'Lowest Amount', 'Smallest amounts at the top', Icons.trending_down_rounded),
                    const Divider(height: 1),
                    _buildSortOption(context, theme, 'category', 'By Category', 'Group by category name (A-Z)', Icons.category_rounded),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(BuildContext context, ThemeData theme, String value, String title, String subtitle, IconData icon) {
    final isSelected = _sortOrder == value;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(30)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : null,
      onTap: () {
        setState(() => _sortOrder = value);
        Navigator.pop(context);
        // Reload data if in all-time mode to apply sort at database level
        if (_searchAllTime) {
          _loadAllTimeData();
        }
      },
    );
  }

  /// Sort items based on the selected sort order
  void _sortItems(List<dynamic> items) {
    // Helper to get ID from item (for tie-breaking when dates are equal)
    int getId(dynamic item) => item is Expense ? (item.id ?? 0) : ((item as Income).id ?? 0);

    switch (_sortOrder) {
      case 'newest':
        items.sort((a, b) {
          final dateA = a is Expense ? a.date : (a as Income).date;
          final dateB = b is Expense ? b.date : (b as Income).date;
          final dateCompare = dateB.compareTo(dateA); // Descending by date
          if (dateCompare != 0) return dateCompare;
          // Same date: sort by ID descending (newest/higher ID first)
          return getId(b).compareTo(getId(a));
        });
        break;
      case 'oldest':
        items.sort((a, b) {
          final dateA = a is Expense ? a.date : (a as Income).date;
          final dateB = b is Expense ? b.date : (b as Income).date;
          final dateCompare = dateA.compareTo(dateB); // Ascending by date
          if (dateCompare != 0) return dateCompare;
          // Same date: sort by ID ascending (oldest/lower ID first)
          return getId(a).compareTo(getId(b));
        });
        break;
      case 'highest':
        items.sort((a, b) {
          final amountA = a is Expense ? a.amount : (a as Income).amount;
          final amountB = b is Expense ? b.amount : (b as Income).amount;
          final amountCompare = amountB.compareTo(amountA); // Descending by amount
          if (amountCompare != 0) return amountCompare;
          // Same amount: sort by date descending, then ID descending
          final dateA = a is Expense ? a.date : (a as Income).date;
          final dateB = b is Expense ? b.date : (b as Income).date;
          final dateCompare = dateB.compareTo(dateA);
          if (dateCompare != 0) return dateCompare;
          return getId(b).compareTo(getId(a));
        });
        break;
      case 'lowest':
        items.sort((a, b) {
          final amountA = a is Expense ? a.amount : (a as Income).amount;
          final amountB = b is Expense ? b.amount : (b as Income).amount;
          final amountCompare = amountA.compareTo(amountB); // Ascending by amount
          if (amountCompare != 0) return amountCompare;
          // Same amount: sort by date descending, then ID descending
          final dateA = a is Expense ? a.date : (a as Income).date;
          final dateB = b is Expense ? b.date : (b as Income).date;
          final dateCompare = dateB.compareTo(dateA);
          if (dateCompare != 0) return dateCompare;
          return getId(b).compareTo(getId(a));
        });
        break;
      case 'category':
        items.sort((a, b) {
          final catA = a is Expense ? a.category : (a as Income).category;
          final catB = b is Expense ? b.category : (b as Income).category;
          final catCompare = catA.compareTo(catB);
          if (catCompare != 0) return catCompare;
          // Within same category, sort by date descending, then ID descending
          final dateA = a is Expense ? a.date : (a as Income).date;
          final dateB = b is Expense ? b.date : (b as Income).date;
          final dateCompare = dateB.compareTo(dateA);
          if (dateCompare != 0) return dateCompare;
          return getId(b).compareTo(getId(a));
        });
        break;
    }
  }

  // ============== ALL LIST ==============

  Widget _buildAllList(BuildContext context, AppState appState, ThemeData theme) {
    // Use all-time data if toggle is on (for search or date range)
    List<Expense> expenses;
    List<Income> incomes;

    if (_searchAllTime) {
      expenses = _allTimeExpenses;
      incomes = _allTimeIncome;
    } else {
      expenses = appState.getExpensesForSelectedMonth();
      incomes = _getIncomesForSelectedMonth(appState);
    }

    final List<dynamic> allItems = [...expenses, ...incomes];
    _sortItems(allItems);

    // FIX: Database-level filtering for all-time search mode
    final filteredItems = allItems.where((item) {
      // For all-time mode with search, database already filtered everything
      // No need for client-side filtering
      if (_searchAllTime && _searchTerm.isNotEmpty) {
        // FIX: Still apply payment status filter even for all-time search
        if (item is Expense && _paymentStatusFilter != 'all') {
          return _matchesPaymentStatus(item);
        }
        return true; // Already filtered by database
      }

      // For monthly view (non-all-time), apply filters locally
      final date = item is Expense ? item.date : (item as Income).date;
      final categoryMatch = _filterCategory == 'All' ||
          (item is Expense ? item.category : (item as Income).category) == _filterCategory;
      final dateMatch = _isInDateRange(date);

      // FIX: Apply payment status filter for expenses
      final paymentMatch = item is! Expense || _paymentStatusFilter == 'all' || _matchesPaymentStatus(item);

      return _matchesSearch(item, _searchTerm) && categoryMatch && dateMatch && paymentMatch;
    }).toList();

    if (filteredItems.isEmpty) {
      return _buildEmptyState(theme);
    }

    return _buildTransactionList(context, filteredItems, appState, theme, showMonth: _searchAllTime);
  }

  // ============== EXPENSES LIST ==============

  Widget _buildExpensesList(BuildContext context, AppState appState, ThemeData theme) {
    // Use all-time data if toggle is on
    List<Expense> expenses;
    if (_searchAllTime) {
      expenses = _allTimeExpenses;
    } else {
      expenses = appState.getExpensesForSelectedMonth();
    }

    final filteredExpenses = expenses.where((expense) {
      // FIX: Database already filtered for all-time search mode
      if (_searchAllTime && _searchTerm.isNotEmpty) {
        // FIX: Still apply payment status filter even for all-time search
        return _paymentStatusFilter == 'all' || _matchesPaymentStatus(expense);
      }

      // For monthly view, apply filters locally
      final categoryMatch = _filterCategory == 'All' || expense.category == _filterCategory;
      final paymentMatch = _paymentStatusFilter == 'all' || _matchesPaymentStatus(expense);
      final dateMatch = _isInDateRange(expense.date);
      return _matchesSearch(expense, _searchTerm) && categoryMatch && dateMatch && paymentMatch;
    }).toList();

    // Apply sorting
    _sortItems(filteredExpenses);

    if (filteredExpenses.isEmpty) {
      return _buildEmptyState(theme);
    }

    return _buildTransactionList(context, filteredExpenses, appState, theme, showMonth: _searchAllTime);
  }

  // ============== INCOME LIST ==============

  List<Income> _getIncomesForSelectedMonth(AppState appState) {
    return appState.incomes.where((i) {
      return i.date.year == appState.selectedMonth.year &&
          i.date.month == appState.selectedMonth.month;
    }).toList();
  }

  Widget _buildIncomeList(BuildContext context, AppState appState, ThemeData theme) {
    // Use all-time data if toggle is on
    List<Income> incomes;
    if (_searchAllTime) {
      incomes = _allTimeIncome;
    } else {
      incomes = _getIncomesForSelectedMonth(appState);
    }

    final filteredIncomes = incomes.where((income) {
      // FIX: Database already filtered for all-time search mode
      if (_searchAllTime && _searchTerm.isNotEmpty) {
        return true; // Already filtered by database
      }

      // For monthly view, apply filters locally
      final categoryMatch = _filterCategory == 'All' || income.category == _filterCategory;
      final dateMatch = _isInDateRange(income.date);
      return _matchesSearch(income, _searchTerm) && categoryMatch && dateMatch;
    }).toList();

    // Apply sorting
    _sortItems(filteredIncomes);

    if (filteredIncomes.isEmpty) {
      return _buildEmptyState(theme);
    }

    return _buildTransactionList(context, filteredIncomes, appState, theme, showMonth: _searchAllTime);
  }

  // ============== SHARED LIST BUILDER ==============

  Widget _buildTransactionList(
      BuildContext context,
      List<dynamic> items,
      AppState appState,
      ThemeData theme, {
      bool showMonth = false,
      }) {
    // For amount-based sorting, don't group - show flat list with dates inline
    final bool isAmountSort = _sortOrder == 'highest' || _sortOrder == 'lowest';

    if (isAmountSort) {
      return _buildFlatTransactionList(context, items, appState, theme, showMonth: showMonth);
    }

    // Determine grouping based on sort order
    final Map<String, List<dynamic>> grouped = {};
    final bool groupByCategory = _sortOrder == 'category';

    for (final item in items) {
      String key;
      if (groupByCategory) {
        // Group by category when sorting by category
        key = item is Expense ? item.category : (item as Income).category;
      } else {
        // Group by date for all other sort modes
        final date = item is Expense ? item.date : (item as Income).date;
        key = DateFormat('yyyy-MM-dd').format(date);
      }
      grouped.putIfAbsent(key, () => []).add(item);
    }

    // Sort keys based on sort order
    final List<String> sortedKeys;
    if (groupByCategory) {
      // Sort category keys alphabetically
      sortedKeys = grouped.keys.toList()..sort();
    } else if (_sortOrder == 'oldest') {
      // Sort date keys ascending (oldest first)
      sortedKeys = grouped.keys.toList()..sort();
    } else {
      // Sort date keys descending (newest first)
      sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    }

    // Add loading indicator item count if loading more, or limit message
    final totalLoaded = _allTimeExpenses.length + _allTimeIncome.length;
    final showLimitMessage = showMonth && !_hasMoreData && totalLoaded >= _maxTotalResults;
    final itemCount = sortedKeys.length +
        (_isLoadingMore && showMonth ? 1 : 0) +
        (showLimitMessage ? 1 : 0);

    // FIX: Add pull-to-refresh
    return RefreshIndicator(
      onRefresh: () async {
        if (_searchAllTime) {
          await _loadAllTimeData();
        } else {
          await context.read<AppState>().refreshCurrentMonthData();
        }
      },
      child: ListView.builder(
        controller: showMonth ? _scrollController : null,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
        itemCount: itemCount,
      itemBuilder: (context, index) {
        // Show loading indicator at the end
        if (_isLoadingMore && index == sortedKeys.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // FIX: Show limit reached message
        if (showLimitMessage && index == sortedKeys.length) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Result limit reached',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Showing first $_maxTotalResults results. Refine your search to see more specific items.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final groupKey = sortedKeys[index];
        final groupItems = grouped[groupKey]!;
        final groupByCategory = _sortOrder == 'category';

        // Determine header text based on grouping type
        String headerText;
        if (groupByCategory) {
          // Category header
          headerText = groupKey.toUpperCase();
        } else {
          // Date header
          final date = DateTime.parse(groupKey);
          headerText = showMonth ? _formatDateHeaderWithMonth(date) : _formatDateHeader(date);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Header (date or category) - Premium styling
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 14),
              child: Text(
                headerText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                  letterSpacing: 1.0,
                ),
              ),
            ),
            // Transactions for this group
            ...groupItems.asMap().entries.map((entry) {
              final itemIndex = entry.key;
              final item = entry.value;
              if (item is Expense) {
                return StaggeredListItem(
                  index: itemIndex,
                  delay: const Duration(milliseconds: 25),
                  child: _buildExpenseItem(context, item, appState, theme),
                );
              } else {
                return StaggeredListItem(
                  index: itemIndex,
                  delay: const Duration(milliseconds: 25),
                  child: _buildIncomeItem(context, item as Income, appState, theme),
                );
              }
            }),
          ],
        );
      },
      ),
    );
  }

  /// Build a flat (non-grouped) transaction list for amount-based sorting.
  /// Shows each transaction with its date inline rather than grouping by date.
  Widget _buildFlatTransactionList(
      BuildContext context,
      List<dynamic> items,
      AppState appState,
      ThemeData theme, {
      bool showMonth = false,
      }) {
    // Add loading indicator item count if loading more, or limit message
    final totalLoaded = _allTimeExpenses.length + _allTimeIncome.length;
    final showLimitMessage = showMonth && !_hasMoreData && totalLoaded >= _maxTotalResults;
    final itemCount = items.length +
        (_isLoadingMore && showMonth ? 1 : 0) +
        (showLimitMessage ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () async {
        if (_searchAllTime) {
          await _loadAllTimeData();
        } else {
          await context.read<AppState>().refreshCurrentMonthData();
        }
      },
      child: ListView.builder(
        controller: showMonth ? _scrollController : null,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Show loading indicator at the end
          if (_isLoadingMore && index == items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          // Show limit reached message
          if (showLimitMessage && index == items.length) {
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Result limit reached',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Showing first $_maxTotalResults results. Refine your search to see more specific items.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final item = items[index];
          if (item is Expense) {
            return StaggeredListItem(
              index: index,
              delay: const Duration(milliseconds: 20),
              child: _buildExpenseItemWithDate(context, item, appState, theme, showMonth: showMonth),
            );
          } else {
            return StaggeredListItem(
              index: index,
              delay: const Duration(milliseconds: 20),
              child: _buildIncomeItemWithDate(context, item as Income, appState, theme, showMonth: showMonth),
            );
          }
        },
      ),
    );
  }

  /// Build expense item with date shown inline (for amount-based sorting)
  Widget _buildExpenseItemWithDate(
      BuildContext context,
      Expense expense,
      AppState appState,
      ThemeData theme, {
      bool showMonth = false,
      }) {
    final date = expense.date;
    final dateStr = showMonth
        ? DateFormat('MMM d, yyyy').format(date)
        : DateFormat('EEE, MMM d').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact date label
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
          child: Text(
            dateStr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _buildExpenseItem(context, expense, appState, theme),
      ],
    );
  }

  /// Build income item with date shown inline (for amount-based sorting)
  Widget _buildIncomeItemWithDate(
      BuildContext context,
      Income income,
      AppState appState,
      ThemeData theme, {
      bool showMonth = false,
      }) {
    final date = income.date;
    final dateStr = showMonth
        ? DateFormat('MMM d, yyyy').format(date)
        : DateFormat('EEE, MMM d').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact date label
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
          child: Text(
            dateStr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _buildIncomeItem(context, income, appState, theme),
      ],
    );
  }

  String _formatDateHeader(DateTime date) {
    final today = DateHelper.today();
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateHelper.normalize(date);

    if (DateHelper.isSameDay(dateOnly, today)) {
      return 'TODAY';
    } else if (DateHelper.isSameDay(dateOnly, yesterday)) {
      return 'YESTERDAY';
    } else {
      return DateFormat('EEEE, MMM d').format(date).toUpperCase();
    }
  }

  String _formatDateHeaderWithMonth(DateTime date) {
    final now = DateTime.now();
    final today = DateHelper.today();
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateHelper.normalize(date);

    if (DateHelper.isSameDay(dateOnly, today)) {
      return 'TODAY';
    } else if (DateHelper.isSameDay(dateOnly, yesterday)) {
      return 'YESTERDAY';
    } else if (date.year == now.year) {
      return DateFormat('EEEE, MMM d').format(date).toUpperCase();
    } else {
      return DateFormat('MMM d, yyyy').format(date).toUpperCase();
    }
  }

  // ============== ITEM BUILDERS ==============

  Widget _buildExpenseItem(
      BuildContext context,
      Expense expense,
      AppState appState,
      ThemeData theme,
      ) {
    final paymentStatus = expense.isPaid
        ? 'paid'
        : expense.amountPaid > 0
            ? 'partially paid, ${appState.currency}${expense.remainingAmount.toStringAsFixed(2)} remaining'
            : 'unpaid';

    return Semantics(
      label: 'Expense: ${expense.description}, ${expense.category}, ${appState.currency}${expense.amount.toStringAsFixed(2)}, $paymentStatus. Tap to add payment, long press to edit, swipe left to delete.',
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Dismissible(
          key: Key('expense_${expense.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
          ),
          confirmDismiss: (direction) => _confirmDelete(context, theme, 'expense', expense.description),
          onDismissed: (direction) async {
            // Show loading indicator during delete operation
            ProgressIndicatorHelper.show(context, message: 'Deleting expense...');
            try {
              // Remove from local all-time list to prevent reappearing
              if (_searchAllTime) {
                setState(() {
                  _allTimeExpenses.removeWhere((e) => e.id == expense.id);
                });
              }
              await appState.deleteExpense(expense.id!);
              if (!mounted) return;
              if (!context.mounted) return;
              ProgressIndicatorHelper.hide(context);
              _showDeleteSnackbar(context, 'Expense');
            } catch (e) {
              if (!mounted) return;
              if (!context.mounted) return;
              ProgressIndicatorHelper.hide(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error deleting expense: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: ExcludeSemantics(
            child: Builder(
              builder: (context) {
                // Get category for both icon and optional background color
                final category = appState.categories
                    .where((c) => c.name == expense.category && c.type == 'expense')
                    .firstOrNull;

                // Parse category color for background (if enabled)
                Color? bgColor;
                if (appState.showTransactionColors) {
                  // Calculate alpha based on intensity (10% to 40% depending on setting)
                  final baseAlpha = theme.brightness == Brightness.dark ? 25 : 15;
                  final maxAlpha = theme.brightness == Brightness.dark ? 100 : 80;
                  final alpha = (baseAlpha + (maxAlpha - baseAlpha) * appState.transactionColorIntensity).round();

                  if (category?.color != null && category!.color!.isNotEmpty) {
                    try {
                      final colorValue = int.parse(category.color!.replaceFirst('#', ''), radix: 16);
                      bgColor = Color(colorValue | 0xFF000000).withAlpha(alpha);
                    } catch (_) {}
                  }
                  // Fallback: use red tint for expenses without custom color
                  bgColor ??= Colors.red.withAlpha((alpha * 0.6).round());
                }

                return Container(
          decoration: BoxDecoration(
            color: bgColor ?? theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.outline.withAlpha(30)
                  : theme.colorScheme.outline.withAlpha(50),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.brightness == Brightness.dark
                    ? Colors.black.withAlpha(40)
                    : Colors.black.withAlpha(8),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _showAddPaymentDialog(context, expense),
            onLongPress: () => _showAddPaymentDialog(context, expense),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                   Row(
                    children: [
                      // Category tile with icon
                      CategoryTile(
                        categoryName: expense.category,
                        categoryType: 'expense',
                        color: category?.color,
                        icon: category?.icon,
                      ),
                      const SizedBox(width: 14),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.description,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  expense.category,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                // Show relative time if available
                                Builder(
                                  builder: (context) {
                                    final relativeTime = DateHelper.getRelativeTime(expense.date);
                                    if (relativeTime.isNotEmpty) {
                                      return Row(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            child: Text(
                                              '•',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            relativeTime,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${appState.currency}${expense.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFFF87171) // Softer red for dark mode
                                  : const Color(0xFFDC2626), // Tailwind red-600
                            ),
                          ),
                          const SizedBox(height: 4),
                          // CRITICAL FIX: Show payment status for BOTH paid and unpaid
                          if (!expense.isPaid) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${appState.currency}${expense.remainingAmount.toStringAsFixed(2)} left',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ] else ...[
                            // CRITICAL FIX: Show "PAID" badge for fully paid expenses
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.withAlpha(60), width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 10, color: Colors.green.shade700),
                                  const SizedBox(width: 3),
                                  Text(
                                    'PAID',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                   if (expense.amountPaid > 0 && !expense.isPaid) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: expense.paymentProgress,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: Colors.orange,
                        minHeight: 4,
                      ),
                    ),
                  ],
                  // Payment and Edit actions
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Record Payment button (shown if not paid)
                      if (!expense.isPaid)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddPaymentDialog(context, expense),
                            icon: Icon(
                              Icons.payment,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                            label: Text(
                              expense.amountPaid > 0 ? 'Pay More' : 'Pay Bill',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.orange.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      if (!expense.isPaid) const SizedBox(width: 8),
                      // Edit button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showEditExpenseDialog(context, expense),
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          label: const Text(
                            'Edit Details',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.primary.withAlpha(100)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeItem(
      BuildContext context,
      Income income,
      AppState appState,
      ThemeData theme,
      ) {
    return Semantics(
      label: 'Income: ${income.description}, ${income.category}, ${appState.currency}${income.amount.toStringAsFixed(2)}. Long press to edit, swipe left to delete.',
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Dismissible(
          key: Key('income_${income.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
          ),
          confirmDismiss: (direction) => _confirmDelete(context, theme, 'income', income.description),
          onDismissed: (direction) async {
            // Show loading indicator during delete operation
            ProgressIndicatorHelper.show(context, message: 'Deleting income...');
            try {
              // Remove from local all-time list to prevent reappearing
              if (_searchAllTime) {
                setState(() {
                  _allTimeIncome.removeWhere((i) => i.id == income.id);
                });
              }
              await appState.deleteIncome(income.id!);
              if (!mounted) return;
              if (!context.mounted) return;
              ProgressIndicatorHelper.hide(context);
              _showDeleteSnackbar(context, 'Income');
            } catch (e) {
              if (!mounted) return;
              if (!context.mounted) return;
              ProgressIndicatorHelper.hide(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error deleting income: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: ExcludeSemantics(
            child: Builder(
              builder: (context) {
                // Get category for both icon and optional background color
                final category = appState.categories
                    .where((c) => c.name == income.category && c.type == 'income')
                    .firstOrNull;

                // Parse category color for background (if enabled)
                Color? bgColor;
                if (appState.showTransactionColors) {
                  // Calculate alpha based on intensity (10% to 40% depending on setting)
                  final baseAlpha = theme.brightness == Brightness.dark ? 25 : 15;
                  final maxAlpha = theme.brightness == Brightness.dark ? 100 : 80;
                  final alpha = (baseAlpha + (maxAlpha - baseAlpha) * appState.transactionColorIntensity).round();

                  if (category?.color != null && category!.color!.isNotEmpty) {
                    try {
                      final colorValue = int.parse(category.color!.replaceFirst('#', ''), radix: 16);
                      bgColor = Color(colorValue | 0xFF000000).withAlpha(alpha);
                    } catch (_) {}
                  }
                  // Fallback: use green tint for income without custom color
                  bgColor ??= Colors.green.withAlpha((alpha * 0.6).round());
                }

                return Container(
                  decoration: BoxDecoration(
                    color: bgColor ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.outline.withAlpha(30)
                          : theme.colorScheme.outline.withAlpha(50),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.brightness == Brightness.dark
                            ? Colors.black.withAlpha(40)
                            : Colors.black.withAlpha(8),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => _showEditIncomeDialog(context, income),
                    onLongPress: () => _showEditIncomeDialog(context, income),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          // Category tile with icon
                          CategoryTile(
                            categoryName: income.category,
                            categoryType: 'income',
                            color: category?.color,
                            icon: category?.icon,
                          ),
                          const SizedBox(width: 14),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  income.description,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      income.category,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    // Show relative time if available
                                    Builder(
                                      builder: (context) {
                                        final relativeTime = DateHelper.getRelativeTime(income.date);
                                        if (relativeTime.isNotEmpty) {
                                          return Row(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                                child: Text(
                                                  '•',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                relativeTime,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Amount
                          Text(
                            '+${appState.currency}${income.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(
      BuildContext context,
      ThemeData theme,
      String type,
      String name,
      ) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${type.capitalize()}?'),
        content: Text('Delete "$name"? It will be moved to trash.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteSnackbar(BuildContext context, String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type moved to trash'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    // CRITICAL FIX: Provide actionable guidance in empty state
    final bool hasFilters = _searchTerm.isNotEmpty ||
                           _paymentStatusFilter != 'all' ||
                           _dateRange != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No transactions found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters'
                  : 'Get started by adding your first transaction',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            // CRITICAL FIX: Add action buttons when no filters are active
            if (!hasFilters) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/add_expense');
                    },
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('Add Expense'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/add_income');
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Income'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Extension for capitalize
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
