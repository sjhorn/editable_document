/// Tests for [IndentEditor].
library;

import 'package:editable_document/src/widgets/properties/indent_editor.dart';
import 'package:editable_document/src/widgets/toolbar/dimension_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('IndentEditor', () {
    testWidgets('renders Left and Right labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          IndentEditor(
            indentLeft: null,
            indentRight: null,
            onIndentLeftChanged: (_) {},
            onIndentRightChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
    });

    testWidgets('shows First Line field when showFirstLine is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          IndentEditor(
            indentLeft: null,
            indentRight: null,
            onIndentLeftChanged: (_) {},
            onIndentRightChanged: (_) {},
            showFirstLine: true,
          ),
        ),
      );
      expect(find.text('First Line'), findsOneWidget);
    });

    testWidgets('hides First Line field when showFirstLine is false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          IndentEditor(
            indentLeft: null,
            indentRight: null,
            onIndentLeftChanged: (_) {},
            onIndentRightChanged: (_) {},
            showFirstLine: false,
          ),
        ),
      );
      expect(find.text('First Line'), findsNothing);
    });

    testWidgets('renders two DimensionFields when showFirstLine is false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          IndentEditor(
            indentLeft: null,
            indentRight: null,
            onIndentLeftChanged: (_) {},
            onIndentRightChanged: (_) {},
            showFirstLine: false,
          ),
        ),
      );
      expect(find.byType(DimensionField), findsNWidgets(2));
    });

    testWidgets('renders three DimensionFields when showFirstLine is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          IndentEditor(
            indentLeft: null,
            indentRight: null,
            firstLineIndent: null,
            onIndentLeftChanged: (_) {},
            onIndentRightChanged: (_) {},
            onFirstLineIndentChanged: (_) {},
            showFirstLine: true,
          ),
        ),
      );
      expect(find.byType(DimensionField), findsNWidgets(3));
    });

    testWidgets('fires onIndentLeftChanged when left field changes', (tester) async {
      double? result;
      await tester.pumpWidget(
        _wrap(
          IndentEditor(
            indentLeft: null,
            indentRight: null,
            onIndentLeftChanged: (v) => result = v,
            onIndentRightChanged: (_) {},
            showFirstLine: false,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, '20');
      expect(result, 20.0);
    });
  });
}
