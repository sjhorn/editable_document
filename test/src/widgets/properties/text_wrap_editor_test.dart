/// Tests for [TextWrapEditor].
library;

import 'package:editable_document/src/model/text_wrap_mode.dart';
import 'package:editable_document/src/widgets/properties/text_wrap_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('TextWrapEditor', () {
    testWidgets('renders four wrap mode buttons', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TextWrapEditor(
            value: TextWrapMode.none,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(IconButton), findsNWidgets(4));
    });

    testWidgets('highlights the active mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TextWrapEditor(
            value: TextWrapMode.wrap,
            onChanged: (_) {},
          ),
        ),
      );
      // wrap is index 1
      final buttons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
      expect(buttons[1].isSelected, isTrue);
      expect(buttons[0].isSelected, isFalse);
    });

    testWidgets('fires onChanged with correct value on tap', (tester) async {
      TextWrapMode? result;
      await tester.pumpWidget(
        _wrap(
          TextWrapEditor(
            value: TextWrapMode.none,
            onChanged: (v) => result = v,
          ),
        ),
      );

      final buttons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
      await tester.tap(find.byWidget(buttons[1]));
      await tester.pump();

      expect(result, TextWrapMode.wrap);
    });

    testWidgets('disables buttons when enabled is false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TextWrapEditor(
            value: TextWrapMode.none,
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
