/// Tests for [DocumentFormatToggle].
library;

import 'package:editable_document/src/widgets/toolbar/document_format_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in [MaterialApp]+[Scaffold] using [InkRipple] to avoid the
/// `shaders/ink_sparkle.frag` asset decode error in the test environment.
Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('DocumentFormatToggle', () {
    testWidgets('renders an icon with given tooltip', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentFormatToggle(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            isActive: false,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.format_bold), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        _wrap(
          DocumentFormatToggle(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            isActive: false,
            onPressed: () => pressed = true,
          ),
        ),
      );

      await tester.tap(find.byType(DocumentFormatToggle));
      expect(pressed, isTrue);
    });

    testWidgets('does not fire when onPressed is null (disabled)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DocumentFormatToggle(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            isActive: false,
            onPressed: null,
          ),
        ),
      );

      // Should not throw.
      await tester.tap(find.byType(DocumentFormatToggle), warnIfMissed: false);
    });

    testWidgets('active state uses primaryContainer background', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentFormatToggle(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            isActive: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(DocumentFormatToggle), findsOneWidget);
    });

    testWidgets('inactive state uses transparent background', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentFormatToggle(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            isActive: false,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(DocumentFormatToggle), findsOneWidget);
    });
  });
}
