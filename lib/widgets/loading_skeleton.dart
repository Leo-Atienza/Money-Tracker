// FIX #26: Loading skeleton for initial data load
import 'package:flutter/material.dart';

class LoadingSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// FIX #26: Pre-built skeleton for transaction list
class TransactionListSkeleton extends StatelessWidget {
  final int itemCount;

  const TransactionListSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const LoadingSkeleton(width: 48, height: 48, borderRadius: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      LoadingSkeleton(width: double.infinity, height: 16),
                      SizedBox(height: 8),
                      LoadingSkeleton(width: 120, height: 12),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const LoadingSkeleton(width: 80, height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// FIX #26: Pre-built skeleton for budget cards
class BudgetCardSkeleton extends StatelessWidget {
  const BudgetCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            LoadingSkeleton(width: 150, height: 20),
            SizedBox(height: 12),
            LoadingSkeleton(width: double.infinity, height: 8, borderRadius: 4),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                LoadingSkeleton(width: 100, height: 16),
                LoadingSkeleton(width: 100, height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
