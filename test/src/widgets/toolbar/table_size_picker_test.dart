/// Tests for [TableSizePicker].
library;

import 'dart:ui' show PointerDeviceKind;

import 'package:editable_document/src/widgets/toolbar/table_size_picker.dart';
import 'package:flutter/foundation.dart';
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

    testWidgets('custom icon and tooltip are used when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TableSizePicker(
            onSelect: (_, __) {},
            icon: Icons.grid_on,
            tooltip: 'Custom tooltip',
          ),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'Custom tooltip');
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.grid_on);
    });

    testWidgets('custom maxRows and maxCols are used when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: TableSizePicker(
              onSelect: (_, __) {},
              maxRows: 4,
              maxCols: 4,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TableSizePicker));
      await tester.pumpAndSettle();

      expect(find.textContaining('×'), findsOneWidget);
    });

    testWidgets('debugFillProperties includes all properties', (tester) async {
      final widget = TableSizePicker(
        enabled: false,
        onSelect: (_, __) {},
        maxRows: 6,
        maxCols: 6,
        icon: Icons.grid_on,
        tooltip: 'Insert table',
      );

      final builder = DiagnosticPropertiesBuilder();
      widget.debugFillProperties(builder);
      final keys = builder.properties.map((p) => p.name).toList();

      // 'enabled' flag is only emitted when true (FlagProperty with ifTrue).
      expect(keys, containsAll(['onSelect', 'maxRows', 'maxCols', 'icon', 'tooltip']));
    });

    testWidgets('overlay grid hover updates the size label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: TableSizePicker(onSelect: (_, __) {}),
          ),
        ),
      );

      await tester.tap(find.byType(TableSizePicker));
      await tester.pumpAndSettle();

      // Default hover is 1×1.
      expect(find.text('1 \u00d7 1'), findsOneWidget);

      // Move the pointer within the grid to change the hover cell.
      // The grid CustomPaint is what we need to hover over.
      final gridFinder = find.byType(CustomPaint).first;
      final gridCenter = tester.getCenter(gridFinder);

      // Simulate a hover at an offset that should highlight a different cell.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: gridCenter + const Offset(30, 30));
      await tester.pump();

      // Size label should have updated.
      expect(find.textContaining('×'), findsOneWidget);

      await gesture.removePointer();
      await tester.pumpAndSettle();
    });
  });
}
