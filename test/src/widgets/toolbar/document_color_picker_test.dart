/// Tests for [DocumentColorPicker].
library;

import 'package:editable_document/src/widgets/toolbar/document_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] using [InkRipple] to avoid the ink_sparkle shader error.
Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: Center(child: child)),
    );

const presets = {
  0xFFFF0000: 'Red',
  0xFF0000FF: 'Blue',
};

void main() {
  group('DocumentColorPicker', () {
    testWidgets('renders the given icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentColorPicker(
            icon: Icons.format_color_text,
            tooltip: 'Text color',
            presets: presets,
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.format_color_text), findsOneWidget);
    });

    testWidgets('disabled when enabled is false — popup does not open', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentColorPicker(
            icon: Icons.format_color_text,
            tooltip: 'Text color',
            enabled: false,
            presets: presets,
            onSelected: (_) {},
          ),
        ),
      );

      await tester.tap(find.byType(DocumentColorPicker), warnIfMissed: false);
      await tester.pumpAndSettle();

      // PopupMenu should not appear.
      expect(find.text('Red'), findsNothing);
    });

    testWidgets('shows color presets in popup when enabled and tapped', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentColorPicker(
            icon: Icons.format_color_text,
            tooltip: 'Text color',
            presets: presets,
            onSelected: (_) {},
          ),
        ),
      );

      await tester.tap(find.byType(DocumentColorPicker));
      await tester.pumpAndSettle();

      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);
    });

    testWidgets('calls onSelected with null when Default is chosen', (tester) async {
      int? selected = 0;

      await tester.pumpWidget(
        _wrap(
          DocumentColorPicker(
            icon: Icons.format_color_text,
            tooltip: 'Text color',
            presets: presets,
            onSelected: (v) => selected = v,
          ),
        ),
      );

      await tester.tap(find.byType(DocumentColorPicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();

      expect(selected, isNull);
    });

    testWidgets('calls onSelected with color value when preset chosen', (tester) async {
      int? selected;

      await tester.pumpWidget(
        _wrap(
          DocumentColorPicker(
            icon: Icons.format_color_text,
            tooltip: 'Text color',
            presets: presets,
            onSelected: (v) => selected = v,
          ),
        ),
      );

      await tester.tap(find.byType(DocumentColorPicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Red'));
      await tester.pumpAndSettle();

      expect(selected, 0xFFFF0000);
    });
  });
}
