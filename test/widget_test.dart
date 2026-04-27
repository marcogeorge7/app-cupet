import 'package:cupet_app/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Theme builds without errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCupetTheme(),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
