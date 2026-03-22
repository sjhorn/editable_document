/// Tests for [DimensionField].
library;

import 'package:editable_document/src/widgets/toolbar/dimension_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] using [InkRipple] to avoid the ink_sparkle shader error.
Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('DimensionField', () {
    testWidgets('shows hintText when value is null', (tester) async {
      await tester.pumpWidget(
        _wrap(DimensionField(value: null, onChanged: (_) {})),
      );

      expect(find.text('auto'), findsOneWidget);
    });

    testWidgets('shows the numeric value when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(DimensionField(value: 42.0, onChanged: (_) {})),
      );

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('calls onChanged with parsed value on text entry', (tester) async {
      double? result = 0;

      await tester.pumpWidget(
        _wrap(DimensionField(value: null, onChanged: (v) => result = v)),
      );

      await tester.enterText(find.byType(TextField), '120');
      expect(result, 120.0);
    });

    testWidgets('calls onChanged with null when field is cleared', (tester) async {
      double? result = 100.0;

      await tester.pumpWidget(
        _wrap(DimensionField(value: 100.0, onChanged: (v) => result = v)),
      );

      await tester.enterText(find.byType(TextField), '');
      expect(result, isNull);
    });

    testWidgets('ignores invalid (non-numeric) input', (tester) async {
      double? result = 50.0;

      await tester.pumpWidget(
        _wrap(DimensionField(value: 50.0, onChanged: (v) => result = v)),
      );

      await tester.enterText(find.byType(TextField), 'abc');
      // Should not have changed the value.
      expect(result, 50.0);
    });

    testWidgets('uses custom hintText', (tester) async {
      await tester.pumpWidget(
        _wrap(DimensionField(value: null, hintText: 'px', onChanged: (_) {})),
      );

      expect(find.text('px'), findsOneWidget);
    });
  });
}
