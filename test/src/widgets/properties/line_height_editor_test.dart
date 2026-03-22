/// Tests for [LineHeightEditor].
library;

import 'package:editable_document/src/widgets/properties/line_height_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('LineHeightEditor', () {
    testWidgets('renders a DropdownButton', (tester) async {
      await tester.pumpWidget(
        _wrap(LineHeightEditor(value: null, onChanged: (_) {})),
      );
      expect(find.byType(DropdownButton<double?>), findsOneWidget);
    });

    testWidgets('shows Default when value is null', (tester) async {
      await tester.pumpWidget(
        _wrap(LineHeightEditor(value: null, onChanged: (_) {})),
      );
      expect(find.text('Default'), findsOneWidget);
    });

    testWidgets('fires onChanged with selected value', (tester) async {
      double? result = 1.0;
      await tester.pumpWidget(
        _wrap(LineHeightEditor(value: 1.0, onChanged: (v) => result = v)),
      );

      // Open the dropdown.
      await tester.tap(find.byType(DropdownButton<double?>));
      await tester.pumpAndSettle();

      // Select "Default" (null).
      await tester.tap(find.text('Default').last);
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('is disabled when enabled is false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LineHeightEditor(value: null, onChanged: (_) {}, enabled: false),
        ),
      );
      final dropdown = tester.widget<DropdownButton<double?>>(
        find.byType(DropdownButton<double?>),
      );
      expect(dropdown.onChanged, isNull);
    });
  });
}
