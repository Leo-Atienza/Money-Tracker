import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_state.dart';
import '../utils/accessibility_helper.dart';
import '../utils/premium_animations.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

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
              'Analytics',
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
                FadeInOnLoad(
                  delay: const Duration(milliseconds: 0),
                  child: const _MonthOverMonthInsights(),
                ),
                const SizedBox(height: 24),
                FadeInOnLoad(
                  delay: const Duration(milliseconds: 100),
                  child: const _SpendingTrendsChart(),
                ),
                const SizedBox(height: 24),
                FadeInOnLoad(
                  delay: const Duration(milliseconds: 200),
                  child: const _SpendingChart(),
                ),
                const SizedBox(height: 24),
                FadeInOnLoad(
                  delay: const Duration(milliseconds: 300),
                  child: const _BudgetProgress(),
                ),
                const SizedBox(height: 24),
                FadeInOnLoad(
                  delay: const Duration(milliseconds: 400),
                  child: const _CategoryBreakdown(),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpendingTrendsChart extends StatefulWidget {
  const _SpendingTrendsChart();

  @override
  State<_SpendingTrendsChart> createState() => _SpendingTrendsChartState();
}

class _SpendingTrendsChartState extends State<_SpendingTrendsChart> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _trends = [];
  bool _isLoading = true;
  DateTime? _lastLoadedMonth;
  late AnimationController _chartAnimationController;
  late Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    _chartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartAnimationController,
      curve: Curves.easeOutCubic,
    );
    _loadTrends();
  }

  @override
  void dispose() {
    _chartAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only reload if month has actually changed (not on every rebuild)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final appState = context.read<AppState>();
      final currentMonth = appState.selectedMonth;

      // Reload trends if the selected month has changed
      if (_lastLoadedMonth == null ||
          _lastLoadedMonth!.year != currentMonth.year ||
          _lastLoadedMonth!.month != currentMonth.month) {
        _loadTrends();
      }
    });
  }

  Future<void> _loadTrends() async {
    setState(() {
      _isLoading = true;
    });

    final appState = context.read<AppState>();
    final currentMonth = appState.selectedMonth;
    _lastLoadedMonth = currentMonth;

    final trends = await appState.getSpendingTrends(months: 6);
    if (mounted) {
      setState(() {
        _trends = trends;
        _isLoading = false;
      });
      _chartAnimationController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Only watch currency for formatting in chart
    final currency = context.select<AppState, String>((s) => s.currency);

    if (_isLoading) {
      return Container(
        height: 250,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // FIX: Show empty state if there are no trends OR if all values are zero
    if (_trends.isEmpty) {
      return _buildEmptyState(theme);
    }

    final hasAnyData = _trends.any((t) => (t['expenses'] as double) > 0 || (t['income'] as double) > 0);
    if (!hasAnyData) {
      return _buildEmptyState(theme);
    }

    final maxValue = _trends.fold<double>(0, (max, t) {
      final expense = t['expenses'] as double;
      final income = t['income'] as double;
      return [max, expense, income].reduce((a, b) => a > b ? a : b);
    });

    final chartDescription = _buildChartDescription(_trends, currency);

    return AnimatedBuilder(
      animation: _chartAnimation,
      builder: (context, child) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Semantics(
        label: 'Six month trends chart, $chartDescription',
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '6-MONTH TRENDS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Row(
                  children: [
                    _buildLegendItem(theme, Colors.red, 'Expenses'),
                    const SizedBox(width: 16),
                    _buildLegendItem(theme, Colors.green, 'Income'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) =>
                          theme.colorScheme.surfaceContainerHighest,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final month = _trends[groupIndex]['month'] as DateTime;
                        final monthName = _getMonthName(month);
                        final value = rod.toY;
                        final label = rodIndex == 0 ? 'Expenses' : 'Income';
                        return BarTooltipItem(
                          '$monthName\n$label: $currency${value.toStringAsFixed(0)}',
                          TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _trends.length) {
                            return const Text('');
                          }
                          final month =
                              _trends[value.toInt()]['month'] as DateTime;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _getMonthShort(month),
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 55,
                        getTitlesWidget: (value, meta) {
                          // FIX: Skip rendering labels at boundaries to prevent ghosting
                          if (value == 0 || value == meta.max || value == meta.min) {
                            return const SizedBox.shrink();
                          }
                          // FIX: Use SizedBox with alignment to prevent text overlap
                          return SizedBox(
                            width: 50,
                            child: Text(
                              '$currency${_formatAmount(value)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.0,
                              ),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    // FIX: Use smarter interval calculation to prevent label overlap
                    horizontalInterval: _calculateGridInterval(maxValue),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outline.withAlpha(50),
                      strokeWidth: 1,
                    ),
                  ),
                  barGroups: _trends.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: (data['expenses'] as double) * _chartAnimation.value,
                          color: Colors.red.shade400,
                          width: 12,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: (data['income'] as double) * _chartAnimation.value,
                          color: Colors.green.shade400,
                          width: 12,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _buildChartDescription(
      List<Map<String, dynamic>> trends, String currency) {
    if (trends.isEmpty) return 'No data available';
    final totalExpenses =
        trends.fold<double>(0, (sum, t) => sum + (t['expenses'] as double));
    final totalIncome =
        trends.fold<double>(0, (sum, t) => sum + (t['income'] as double));
    return 'Total expenses: $currency${totalExpenses.toStringAsFixed(0)}, Total income: $currency${totalIncome.toStringAsFixed(0)}';
  }

  Widget _buildLegendItem(ThemeData theme, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withAlpha(200),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _getMonthName(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getMonthShort(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[date.month - 1];
  }

  String _formatAmount(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      // FIX: Use cleaner K notation without decimal for cleaner display
      final kValue = value / 1000;
      return kValue >= 10 ? '${kValue.toStringAsFixed(0)}K' : '${kValue.toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  /// FIX: Calculate smart grid interval to prevent label overlap
  /// Returns a "nice" interval that produces clean round numbers
  double _calculateGridInterval(double maxValue) {
    if (maxValue <= 0) return 1;

    // Target 3-4 grid lines for readability
    final rawInterval = maxValue / 4;

    // Round to nice intervals (1, 2, 5, 10, 20, 50, 100, etc.)
    if (rawInterval >= 1000000) {
      return (rawInterval / 1000000).ceil() * 1000000;
    } else if (rawInterval >= 100000) {
      return (rawInterval / 100000).ceil() * 100000;
    } else if (rawInterval >= 10000) {
      return (rawInterval / 10000).ceil() * 10000;
    } else if (rawInterval >= 1000) {
      return (rawInterval / 1000).ceil() * 1000;
    } else if (rawInterval >= 100) {
      return (rawInterval / 100).ceil() * 100;
    } else if (rawInterval >= 10) {
      return (rawInterval / 10).ceil() * 10;
    }
    return rawInterval.ceil().toDouble().clamp(1, double.infinity);
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.trending_up,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              'Not enough data for trends',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add transactions to see your 6-month spending trends',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendingChart extends StatelessWidget {
  const _SpendingChart();

  // Maximum categories to show before grouping rest into "Others"
  static const int _maxCategories = 5;
  // Minimum percentage threshold - below this, categories are grouped into "Others"
  static const double _minPercentage = 3.0;

  /// Groups small categories into "Others" to avoid pie chart clutter
  Map<String, double> _groupSmallCategories(
      Map<String, double> spending, double total) {
    if (spending.length <= _maxCategories) {
      return spending;
    }

    // Sort by value descending
    final sortedEntries = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, double> grouped = {};
    double othersTotal = 0.0;
    int displayedCount = 0;

    for (final entry in sortedEntries) {
      final percentage = (entry.value / total) * 100;

      // Keep top categories or those above threshold (up to max)
      if (displayedCount < _maxCategories && percentage >= _minPercentage) {
        grouped[entry.key] = entry.value;
        displayedCount++;
      } else {
        othersTotal += entry.value;
      }
    }

    // Add "Others" if there's any grouped amount
    if (othersTotal > 0) {
      grouped['Others'] = othersTotal;
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // FIX #30: Dynamic font scaling for small screens
    final screenWidth = MediaQuery.of(context).size.width;
    final chartLabelFontSize = screenWidth < 360 ? 10.0 : 12.0;
    final legendFontSize = screenWidth < 360 ? 12.0 : 14.0;

    // Optimize: Select only spending data and currency
    final spendingAndCurrency =
        context.select<AppState, (Map<String, double>, String)>(
      (s) => (s.getCategorySpending(), s.currency),
    );
    final rawSpending = spendingAndCurrency.$1;
    final currency = spendingAndCurrency.$2;

    if (rawSpending.isEmpty) {
      return _buildEmptyState(theme, 'No spending data this month');
    }

    final total = rawSpending.values.fold(0.0, (sum, val) => sum + val);

    if (total <= 0) {
      return _buildEmptyState(theme, 'No spending data this month');
    }

    // Group small categories into "Others"
    final spending = _groupSmallCategories(rawSpending, total);
    final colors = _getColors(theme);

    final categoryDescriptions = spending.entries
        .map((e) =>
            '${e.key}: $currency${e.value.toStringAsFixed(2)}, ${((e.value / total) * 100).toStringAsFixed(0)}%')
        .join('; ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Semantics(
        label: 'Spending by category, $categoryDescriptions',
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SPENDING BY CATEGORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 1,
                  centerSpaceRadius: 55,
                  sections:
                      spending.entries.toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    final percentage = (data.value / total * 100);

                    // Use a subtle gray for "Others" category that fits the design
                    final bgColor = data.key == 'Others'
                        ? (theme.brightness == Brightness.dark
                            ? Colors.grey.shade600
                            : Colors.grey.shade400)
                        : colors[index % colors.length];
                    final textColor = _getContrastingTextColor(bgColor);

                    // For tiny slices (<3%), don't show label at all
                    final bool isTinySlice = percentage < 3;

                    return PieChartSectionData(
                      color: bgColor,
                      value: data.value,
                      title: isTinySlice ? '' : '${percentage.toStringAsFixed(0)}%',
                      radius: 50, // Consistent radius for all slices
                      titleStyle: TextStyle(
                        fontSize: chartLabelFontSize,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      titlePositionPercentageOffset: 0.55,
                      badgeWidget: null,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...spending.entries.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              final isOthers = data.key == 'Others';
              final percentage = (data.value / total) * 100;
              final percentageStr = percentage.toStringAsFixed(percentage < 1 ? 1 : 0);
              // Use matching color for the legend
              final legendColor = isOthers
                  ? (theme.brightness == Brightness.dark
                      ? Colors.grey.shade600
                      : Colors.grey.shade400)
                  : colors[index % colors.length];
              return Semantics(
                label:
                    '${data.key}, $currency${data.value.toStringAsFixed(2)}, $percentageStr percent',
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: legendColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          data.key,
                          style: TextStyle(
                            fontSize: legendFontSize,
                            color: theme.colorScheme.onSurface,
                            fontStyle:
                                isOthers ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                      // Show percentage in legend for all categories
                      Text(
                        '$percentageStr%',
                        style: TextStyle(
                          fontSize: legendFontSize - 2,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$currency${data.value.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: legendFontSize,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<Color> _getColors(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return [
        Colors.blue.shade400,
        Colors.green.shade400,
        Colors.orange.shade400,
        Colors.purple.shade400,
        Colors.red.shade400,
        Colors.teal.shade400,
        Colors.pink.shade400,
        Colors.amber.shade400,
      ];
    } else {
      return [
        Colors.blue.shade600,
        Colors.green.shade600,
        Colors.orange.shade600,
        Colors.purple.shade600,
        Colors.red.shade600,
        Colors.teal.shade600,
        Colors.pink.shade600,
        Colors.amber.shade600,
      ];
    }
  }

  /// Returns black or white text color based on background luminance.
  /// This ensures readable text on any pie chart slice color.
  Color _getContrastingTextColor(Color bgColor) {
    // Calculate relative luminance using the new Color API (Flutter 3.27+)
    final luminance = (0.299 * (bgColor.r * 255) +
            0.587 * (bgColor.g * 255) +
            0.114 * (bgColor.b * 255)) /
        255;
    // Use black text on light backgrounds, white on dark
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetProgress extends StatelessWidget {
  const _BudgetProgress();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Select only budgets and currency needed for display
    final budgetsAndCurrency =
        context.select<AppState, (List<dynamic>, String)>(
      (s) => (s.currentMonthBudgets, s.currency),
    );
    final budgets = budgetsAndCurrency.$1;
    final currency = budgetsAndCurrency.$2;
    final appState = context.read<AppState>(); // For getCategorySpending

    if (budgets.isEmpty) {
      return _buildEmptyState(context, theme);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Semantics(
        label: 'Budget progress overview',
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BUDGET PROGRESS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ...budgets.map((budget) {
              final spent = appState.getSpentForCategory(budget.category);
              // FIX #3: Handle division by zero for budget percentage
              final percentage = budget.amount > 0
                  ? (spent / budget.amount * 100).clamp(0.0, 100.0)
                  : 0.0;
              final Color color = percentage >= 100
                  ? Colors.red
                  : percentage >= 90
                      ? Colors.orange
                      : percentage >= 80
                          ? Colors.amber
                          : Colors.green;
              final statusLabel = AccessibilityHelper.getBudgetStatusLabel(
                  percentage, budget.category);

              return Semantics(
                label: statusLabel,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            budget.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '$currency${spent.toStringAsFixed(0)} / $currency${budget.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AccessibilityHelper.accessibleProgressIndicator(
                        value: percentage / 100,
                        label: '${budget.category} budget',
                        color: color,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${percentage.toStringAsFixed(0)}% used',
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              'No budgets set',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set budgets to track your spending',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/budgets');
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Budget'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Select only spending data and currency
    final spendingAndCurrency =
        context.select<AppState, (Map<String, double>, String)>(
      (s) => (s.getCategorySpending(), s.currency),
    );
    final spending = spendingAndCurrency.$1;
    final currency = spendingAndCurrency.$2;

    if (spending.isEmpty) return const SizedBox.shrink();

    final sortedEntries = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = spending.values.fold(0.0, (sum, val) => sum + val);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOP CATEGORIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedEntries.take(5).map((entry) {
            // FIX #3: Safe percentage calculation
            final percentage = total > 0 ? (entry.value / total * 100) : 0.0;

            return Semantics(
              label: '${entry.key}, $currency${entry.value.toStringAsFixed(2)}, ${percentage.toStringAsFixed(1)}% of total spending',
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 15,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Progress bar showing relative spending
                          ExcludeSemantics(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                minHeight: 4,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(
                                  theme.colorScheme.onSurface.withAlpha(150),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$currency${entry.value.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MonthOverMonthInsights extends StatelessWidget {
  const _MonthOverMonthInsights();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Select only the comparison data and currency needed
    final comparisonData = context.select<AppState, (dynamic, dynamic, String)>(
      (s) => (
        s.getMonthOverMonthComparison(),
        s.getIncomeMonthOverMonthComparison(),
        s.currency
      ),
    );
    final comparison = comparisonData.$1;
    final incomeComparison = comparisonData.$2;
    final currency = comparisonData.$3;

    final currentExpenses = comparison['currentTotal'] as double;
    final prevExpenses = comparison['previousTotal'] as double;
    final expenseChange = comparison['percentChange'] as double;
    final categoryComparison =
        comparison['categoryComparison'] as Map<String, Map<String, double>>;

    final currentIncome = incomeComparison['currentTotal'] as double;
    final prevIncome = incomeComparison['previousTotal'] as double;
    final incomeChange = incomeComparison['percentChange'] as double;

    // Find categories with biggest changes
    final categoryChanges = categoryComparison.entries.toList()
      ..sort((a, b) => (b.value['change']?.abs() ?? 0)
          .compareTo(a.value['change']?.abs() ?? 0));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTH-OVER-MONTH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Expense comparison
          Row(
            children: [
              Expanded(
                child: _buildComparisonCard(
                  context,
                  theme,
                  currency,
                  title: 'Expenses',
                  current: currentExpenses,
                  previous: prevExpenses,
                  change: expenseChange,
                  isExpense: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildComparisonCard(
                  context,
                  theme,
                  currency,
                  title: 'Income',
                  current: currentIncome,
                  previous: prevIncome,
                  change: incomeChange,
                  isExpense: false,
                ),
              ),
            ],
          ),

          // Category insights
          if (categoryChanges.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'CATEGORY INSIGHTS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...categoryChanges.take(3).map((entry) {
              final cat = entry.key;
              final data = entry.value;
              final current = data['current'] ?? 0.0;
              final previous = data['previous'] ?? 0.0;
              final change = data['change'] ?? 0.0;

              return _buildCategoryInsightRow(
                context,
                theme,
                currency,
                category: cat,
                current: current,
                previous: previous,
                change: change,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonCard(
    BuildContext context,
    ThemeData theme,
    String currency, {
    required String title,
    required double current,
    required double previous,
    required double change,
    required bool isExpense,
  }) {
    // Build semantic description for accessibility
    final isPositiveChange = change > 0;
    final changeDescription = previous <= 0
        ? 'new this month'
        : '${isPositiveChange ? 'increased' : 'decreased'} by ${change.abs().toStringAsFixed(1)}% compared to last';

    // FIX: Format amount to prevent text overflow
    String formattedAmount;
    if (current >= 1000000) {
      formattedAmount = '$currency${(current / 1000000).toStringAsFixed(1)}M';
    } else if (current >= 10000) {
      formattedAmount = '$currency${(current / 1000).toStringAsFixed(1)}K';
    } else {
      formattedAmount = '$currency${current.toStringAsFixed(0)}';
    }

    return Semantics(
      label: '$title: $currency${current.toStringAsFixed(0)}, $changeDescription',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formattedAmount,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryInsightRow(
    BuildContext context,
    ThemeData theme,
    String currency, {
    required String category,
    required double current,
    required double previous,
    required double change,
  }) {
    final isPositiveChange = change > 0;
    final changeColor = isPositiveChange ? Colors.red : Colors.green;
    final isNew = previous == 0 && current > 0;
    final isRemoved = previous > 0 && current == 0;

    final semanticLabel = isNew
        ? '$category, new this month, $currency${current.toStringAsFixed(0)}'
        : isRemoved
            ? '$category, no spending this month'
            : '$category, ${isPositiveChange ? 'increased' : 'decreased'} by ${change.abs().toStringAsFixed(0)}%, from $currency${previous.toStringAsFixed(0)} to $currency${current.toStringAsFixed(0)}';

    return Semantics(
      label: semanticLabel,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isNew
                      ? Colors.blue.withAlpha(20)
                      : isRemoved
                          ? Colors.grey.withAlpha(20)
                          : changeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isNew
                      ? Icons.add
                      : isRemoved
                          ? Icons.remove
                          : (isPositiveChange
                              ? Icons.trending_up
                              : Icons.trending_down),
                  size: 16,
                  color: isNew
                      ? Colors.blue
                      : isRemoved
                          ? Colors.grey
                          : changeColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    isNew
                        ? 'New this month'
                        : isRemoved
                            ? 'No spending this month'
                            : '$currency${previous.toStringAsFixed(0)} → $currency${current.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!isNew && !isRemoved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: changeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isPositiveChange ? '+' : ''}${change.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: changeColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
