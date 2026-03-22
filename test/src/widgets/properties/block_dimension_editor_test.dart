/// Tests for [BlockDimensionEditor].
library;

import 'package:editable_document/src/model/block_dimension.dart';
import 'package:editable_document/src/widgets/properties/block_dimension_editor.dart';
import 'package:editable_document/src/widgets/toolbar/dimension_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('BlockDimensionEditor', () {
    testWidgets('renders two DimensionFields', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BlockDimensionEditor(
            width: null,
            height: null,
            onWidthChanged: (_) {},
            onHeightChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(DimensionField), findsNWidgets(2));
    });

    testWidgets('renders two ToggleButtons (px/%) pairs', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BlockDimensionEditor(
            width: null,
            height: null,
            onWidthChanged: (_) {},
            onHeightChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(ToggleButtons), findsNWidgets(2));
    });

    testWidgets('fires onWidthChanged when width field changes', (tester) async {
      BlockDimension? result;
      await tester.pumpWidget(
        _wrap(
          BlockDimensionEditor(
            width: null,
            height: null,
            onWidthChanged: (v) => result = v,
            onHeightChanged: (_) {},
          ),
        ),
      );

      // Enter text in the first (width) DimensionField.
      await tester.enterText(find.byType(TextField).first, '200');
      expect(result, const BlockDimension.pixels(200));
    });

    testWidgets('fires onHeightChanged when height field changes', (tester) async {
      BlockDimension? result;
      await tester.pumpWidget(
        _wrap(
          BlockDimensionEditor(
            width: null,
            height: null,
            onWidthChanged: (_) {},
            onHeightChanged: (v) => result = v,
          ),
        ),
      );

      // Enter text in the second (height) DimensionField.
      await tester.enterText(find.byType(TextField).last, '100');
      expect(result, const BlockDimension.pixels(100));
    });

    testWidgets('switches to percent when % toggle pressed', (tester) async {
      BlockDimension? result;
      await tester.pumpWidget(
        _wrap(
          BlockDimensionEditor(
            width: const BlockDimension.pixels(200),
            height: null,
            onWidthChanged: (v) => result = v,
            onHeightChanged: (_) {},
          ),
        ),
      );

      // Tap the '%' toggle for width (first ToggleButtons, second child).
      final toggles = find.byType(ToggleButtons);
      await tester.tap(find.descendant(of: toggles.first, matching: find.text('%')));
      await tester.pump();

      // Should switch 200px → 2.0 (200/100) as percent.
      expect(result, const BlockDimension.percent(2.0));
    });
  });
}
