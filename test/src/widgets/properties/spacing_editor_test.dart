/// Tests for [SpacingEditor].
library;

import 'package:editable_document/src/widgets/properties/spacing_editor.dart';
import 'package:editable_document/src/widgets/toolbar/dimension_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('SpacingEditor', () {
    testWidgets('renders two DimensionFields', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SpacingEditor(
            spaceBefore: null,
            spaceAfter: null,
            onSpaceBeforeChanged: (_) {},
            onSpaceAfterChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(DimensionField), findsNWidgets(2));
    });

    testWidgets('shows Before and After labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SpacingEditor(
            spaceBefore: null,
            spaceAfter: null,
            onSpaceBeforeChanged: (_) {},
            onSpaceAfterChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
    });

    testWidgets('fires onSpaceBeforeChanged when first field changes', (tester) async {
      double? result;
      await tester.pumpWidget(
        _wrap(
          SpacingEditor(
            spaceBefore: null,
            spaceAfter: null,
            onSpaceBeforeChanged: (v) => result = v,
            onSpaceAfterChanged: (_) {},
          ),
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, '12');
      expect(result, 12.0);
    });

    testWidgets('fires onSpaceAfterChanged when second field changes', (tester) async {
      double? result;
      await tester.pumpWidget(
        _wrap(
          SpacingEditor(
            spaceBefore: null,
            spaceAfter: null,
            onSpaceBeforeChanged: (_) {},
            onSpaceAfterChanged: (v) => result = v,
          ),
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.last, '8');
      expect(result, 8.0);
    });
  });
}
