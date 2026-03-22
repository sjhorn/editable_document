/// Tests for [TextAlignmentEditor].
library;

import 'package:editable_document/src/widgets/properties/text_alignment_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('TextAlignmentEditor', () {
    testWidgets('renders four alignment buttons', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TextAlignmentEditor(
            value: TextAlign.start,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(IconButton), findsNWidgets(4));
    });

    testWidgets('fires onChanged with correct value on tap', (tester) async {
      TextAlign? result;
      await tester.pumpWidget(
        _wrap(
          TextAlignmentEditor(
            value: TextAlign.start,
            onChanged: (v) => result = v,
          ),
        ),
      );

      // Tap the center alignment button (second button)
      final buttons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
      await tester.tap(find.byWidget(buttons[1]));
      await tester.pump();

      expect(result, TextAlign.center);
    });

    testWidgets('highlights the active alignment', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TextAlignmentEditor(
            value: TextAlign.center,
            onChanged: (_) {},
          ),
        ),
      );
      // The center button (index 1) should be selected (isSelected == true).
      final buttons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
      expect(buttons[1].isSelected, isTrue);
      expect(buttons[0].isSelected, isFalse);
    });

    testWidgets('disables buttons when enabled is false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TextAlignmentEditor(
            value: TextAlign.start,
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
