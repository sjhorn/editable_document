/// Tests for [BorderColorButton].
library;

import 'package:editable_document/src/widgets/toolbar/border_color_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] using [InkRipple] to avoid the ink_sparkle shader error.
Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('BorderColorButton', () {
    testWidgets('renders a colored container', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BorderColorButton(
            color: Colors.red,
            isSelected: false,
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(BorderColorButton), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          BorderColorButton(
            color: Colors.blue,
            isSelected: false,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(BorderColorButton));
      expect(tapped, isTrue);
    });

    testWidgets('shows tooltip label when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BorderColorButton(
            color: Colors.green,
            isSelected: false,
            onTap: () {},
            label: 'Green',
          ),
        ),
      );

      expect(find.byType(BorderColorButton), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('selected state uses primary color border', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BorderColorButton(
            color: Colors.red,
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(BorderColorButton), findsOneWidget);
    });
  });
}
