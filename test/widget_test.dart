import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('App widget test', (WidgetTester tester) async {
    // Simple test to verify basic Flutter functionality
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Test'),
          ),
        ),
      ),
    );

    // Verify basic widget rendering works
    expect(find.text('Test'), findsOneWidget);
  });

  test('Basic Dart test', () {
    // Verify basic Dart functionality
    expect(1 + 1, 2);
    expect('expense'.contains('exp'), true);
  });
}