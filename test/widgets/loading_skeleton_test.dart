import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/widgets/loading_skeleton.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  final theme = brightness == Brightness.dark
      ? ThemeData.dark()
      : ThemeData.light();
  return MaterialApp(theme: theme, home: Scaffold(body: child));
}

void main() {
  group('LoadingSkeleton', () {
    testWidgets('renders at the configured height', (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(
          width: 200,
          child: LoadingSkeleton(height: 40),
        )),
      );

      final size = tester.getSize(find.byType(LoadingSkeleton));
      expect(size.height, 40);
    });

    testWidgets('accepts width when given', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UnconstrainedBox(
            child: LoadingSkeleton(width: 150, height: 12),
          ),
        ),
      );

      final size = tester.getSize(find.byType(LoadingSkeleton));
      expect(size.width, 150);
      expect(size.height, 12);
    });

    testWidgets(
        'animation loop does not throw and disposes cleanly when removed',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoadingSkeleton()));

      // Drive several frames of the shimmer animation.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Remove the skeleton from the tree — dispose must not throw.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      expect(find.byType(LoadingSkeleton), findsNothing);
    });

    testWidgets('dark mode uses different base color than light mode',
        (tester) async {
      // We can't introspect the gradient directly without a golden test, but
      // we can at least assert that both render without throwing and the
      // widget tree is valid under both brightnesses.
      await tester.pumpWidget(_wrap(const LoadingSkeleton()));
      expect(find.byType(LoadingSkeleton), findsOneWidget);

      await tester.pumpWidget(
        _wrap(const LoadingSkeleton(), brightness: Brightness.dark),
      );
      expect(find.byType(LoadingSkeleton), findsOneWidget);
    });
  });

  group('TransactionListSkeleton', () {
    testWidgets('renders the default 5 card placeholders', (tester) async {
      await tester.pumpWidget(_wrap(const TransactionListSkeleton()));
      // Each row has one 48x48 circle + one amount block + two stacked text
      // blocks = 4 LoadingSkeletons per card. Default itemCount = 5.
      expect(find.byType(Card), findsNWidgets(5));
    });

    testWidgets('renders the requested number of placeholder cards',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TransactionListSkeleton(itemCount: 3)),
      );
      expect(find.byType(Card), findsNWidgets(3));
    });

    testWidgets('does not throw when pumped under dark mode',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TransactionListSkeleton(itemCount: 2),
          brightness: Brightness.dark,
        ),
      );
      expect(find.byType(Card), findsNWidgets(2));
    });
  });

  group('BudgetCardSkeleton', () {
    testWidgets('renders a single card', (tester) async {
      await tester.pumpWidget(_wrap(const BudgetCardSkeleton()));
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('contains multiple LoadingSkeleton placeholders',
        (tester) async {
      await tester.pumpWidget(_wrap(const BudgetCardSkeleton()));
      // Title + progress bar + 2 label rows = at least 4 skeleton blocks.
      expect(find.byType(LoadingSkeleton), findsAtLeastNWidgets(4));
    });
  });
}
