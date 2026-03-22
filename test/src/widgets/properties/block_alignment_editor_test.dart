/// Tests for [BlockAlignmentEditor].
library;

import 'package:editable_document/src/model/block_alignment.dart';
import 'package:editable_document/src/widgets/properties/block_alignment_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('BlockAlignmentEditor', () {
    testWidgets('renders four alignment buttons', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BlockAlignmentEditor(
            value: BlockAlignment.start,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(IconButton), findsNWidgets(4));
    });

    testWidgets('highlights the active alignment', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BlockAlignmentEditor(
            value: BlockAlignment.center,
            onChanged: (_) {},
          ),
        ),
      );
      // center is index 1
      final buttons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
      expect(buttons[1].isSelected, isTrue);
      expect(buttons[0].isSelected, isFalse);
    });

    testWidgets('fires onChanged with correct value on tap', (tester) async {
      BlockAlignment? result;
      await tester.pumpWidget(
        _wrap(
          BlockAlignmentEditor(
            value: BlockAlignment.start,
            onChanged: (v) => result = v,
          ),
        ),
      );

      // Tap center (index 1)
      final buttons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
      await tester.tap(find.byWidget(buttons[1]));
      await tester.pump();

      expect(result, BlockAlignment.center);
    });

    testWidgets('disables buttons when enabled is false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BlockAlignmentEditor(
            value: BlockAlignment.start,
            onChanged: (_) {},
            enabled: false,
          ),
        ),
      );

      final buttons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
      for (final btn in buttons) {
        expect(btn.onPressed, isNull);
      }
    });
  });
}
