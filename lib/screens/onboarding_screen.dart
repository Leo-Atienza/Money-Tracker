import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/onboarding_service.dart';
import '../utils/date_helper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final OnboardingService _onboardingService = OnboardingService();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await _onboardingService.completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _loadSampleData() async {
    final appState = context.read<AppState>();

    // Add sample categories
    await appState.addCategory('Groceries', type: 'expense');
    await appState.addCategory('Transport', type: 'expense');
    await appState.addCategory('Entertainment', type: 'expense');
    await appState.addCategory('Salary', type: 'income');
    await appState.addCategory('Freelance', type: 'income');

    // Add sample expenses (past month)
    final today = DateHelper.today();
    final dates = [
      today.subtract(const Duration(days: 1)),
      today.subtract(const Duration(days: 2)),
      today.subtract(const Duration(days: 5)),
      today.subtract(const Duration(days: 10)),
    ];

    for (final date in dates) {
      // Add some sample transactions
      if (date.day % 2 == 0) {
        await appState.addExpenseRaw(
          amount: 45.50 + (date.day % 3) * 10,
          category: 'Groceries',
          description: 'Weekly groceries',
          date: date,
          paymentMethod: 'Debit',
          amountPaid: 45.50 + (date.day % 3) * 10,
        );
      } else {
        await appState.addExpenseRaw(
          amount: 12.00 + (date.day % 5) * 5,
          category: 'Transport',
          description: 'Gas',
          date: date,
          paymentMethod: 'Cash',
          amountPaid: 12.00 + (date.day % 5) * 5,
        );
      }
    }

    // Add sample income
    await appState.addIncomeRaw(
      amount: 3000.00,
      category: 'Salary',
      description: 'Monthly salary',
      date: DateHelper.startOfMonth(today),
    );

    // Add a budget
    await appState.setBudget('Groceries', 200.00);

    await _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const Text('Skip'),
              ),
            ),

            // Page view
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildPage(
                    theme,
                    Icons.receipt_long_rounded,
                    'Track Your Spending',
                    'Easily add and categorize your expenses and income',
                  ),
                  _buildPage(
                    theme,
                    Icons.pie_chart_rounded,
                    'Set Budgets',
                    'Create monthly budgets and get warnings when you\'re close to the limit',
                  ),
                  _buildPage(
                    theme,
                    Icons.trending_up_rounded,
                    'View Analytics',
                    'See insights and trends about your spending habits',
                  ),
                ],
              ),
            ),

            // Page indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _currentPage == 2
                          ? _completeOnboarding
                          : () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage == 2 ? 'Get Started' : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _loadSampleData,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Load Sample Data',
                        style: TextStyle(fontSize: 16),
                      ),
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

  Widget _buildPage(ThemeData theme, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              size: 60,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
