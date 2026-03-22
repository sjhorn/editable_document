/// Tests for [TableSizePicker].
library;

import 'package:editable_document/src/widgets/toolbar/table_size_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] using [InkRipple] to avoid the ink_sparkle shader error.
Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('TableSizePicker', () {
    testWidgets('renders the table icon button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TableSizePicker(onSelect: (_, __) {}),
        ),
      );

      expect(find.byType(TableSizePicker), findsOneWidget);
    });

    testWidgets('disabled when enabled is false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TableSizePicker(
            enabled: false,
            onSelect: (_, __) {},
          ),
        ),
      );

      // Tapping should not open the picker.
      await tester.tap(find.byType(TableSizePicker), warnIfMissed: false);
      await tester.pumpAndSettle();

      // No size label should appear.
      expect(find.textContaining('×'), findsNothing);
    });

    testWidgets('opens grid overlay when tapped while enabled', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Center(child: TableSizePicker(onSelect: (_, __) {})),
        ),
      );

      await tester.tap(find.byType(TableSizePicker));
      await tester.pumpAndSettle();

      // The overlay should show a size label (default hover is 1×1).
      expect(find.textContaining('×'), findsOneWidget);
    });

    testWidgets('tapping outside the overlay dismisses it', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Align(
            alignment: Alignment.topLeft,
            child: TableSizePicker(onSelect: (_, __) {}),
          ),
        ),
      );

      await tester.tap(find.byType(TableSizePicker));
      await tester.pumpAndSettle();
      expect(find.textContaining('×'), findsOneWidget);

      // Tap somewhere outside.
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();
      expect(find.textContaining('×'), findsNothing);
    });
  });
}
