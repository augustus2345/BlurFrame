// Flutter widget smoke test.
//
// Actual feature tests live in test/features/ and test/shared/.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Smoke test: ProviderScope can be built', (tester) async {
    // Smoke test to verify the test infrastructure works.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: Text('hello')),
          ),
        ),
      ),
    );
    expect(find.text('hello'), findsOneWidget);
  });
}