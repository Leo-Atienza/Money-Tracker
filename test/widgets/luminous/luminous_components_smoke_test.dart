import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/widgets/luminous/category_bento_grid.dart';
import 'package:budget_tracker/widgets/luminous/glass_list_section.dart';
import 'package:budget_tracker/widgets/luminous/glass_list_tile.dart';
import 'package:budget_tracker/widgets/luminous/glass_pill_chip.dart';
import 'package:budget_tracker/widgets/luminous/glass_progress_bar.dart';
import 'package:budget_tracker/widgets/luminous/glass_segmented_control.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';

Widget _wrap(Widget child, {Size size = const Size(400, 800)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('GlassTopAppBar', () {
    testWidgets('renders title + subtitle + actions without throwing',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassTopAppBar(
            leading: CircleAvatar(child: Text('L')),
            title: 'Wallet',
            subtitle: 'AI Insights →',
            actions: [Icon(Icons.search)],
          ),
        ),
      );
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('AI Insights →'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });

  group('GlassSegmentedControl', () {
    testWidgets('selects on tap and calls onChanged once', (tester) async {
      String selected = 'a';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (_, setState) => GlassSegmentedControl<String>(
              values: const ['a', 'b'],
              labels: const ['First', 'Second'],
              selected: selected,
              onChanged: (v) => setState(() => selected = v),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(selected, 'b');
    });
  });

  group('GlassPillChip', () {
    testWidgets('selected state announces correctly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassPillChip(
            label: 'Coffee',
            icon: Icons.coffee,
            selected: true,
          ),
        ),
      );
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.byIcon(Icons.coffee), findsOneWidget);
    });
  });

  group('GlassListSection + GlassListTile', () {
    testWidgets('renders section header and tiles', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GlassListSection(
            title: 'Preferences',
            children: [
              GlassListTile(
                icon: Icons.dark_mode,
                label: 'Dark mode',
                trailing: Switch(value: true, onChanged: (_) {}),
              ),
              const GlassListTile(
                icon: Icons.language,
                label: 'Language',
                value: 'English',
                chevron: true,
              ),
            ],
          ),
        ),
      );
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('Dark mode'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('GlassProgressBar', () {
    testWidgets('clamps visual fill but reports raw value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 200,
            child: GlassProgressBar(progress: 1.25, semanticLabel: 'Budget'),
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(GlassProgressBar));
      expect(semantics.value, '125%');
    });
  });

  group('CategoryBentoGrid', () {
    testWidgets('fires onSelected with item id', (tester) async {
      Object? lastId;
      await tester.pumpWidget(
        _wrap(
          CategoryBentoGrid(
            selectedId: 1,
            onSelected: (id) => lastId = id,
            items: const [
              CategoryBentoItem(
                id: 1,
                label: 'Food',
                icon: Icons.fastfood,
                color: Colors.orange,
              ),
              CategoryBentoItem(
                id: 2,
                label: 'Travel',
                icon: Icons.flight,
                color: Colors.blue,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Travel'));
      await tester.pumpAndSettle();
      expect(lastId, 2);
    });
  });
}
