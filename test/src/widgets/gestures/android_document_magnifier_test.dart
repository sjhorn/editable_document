/// Tests for [AndroidDocumentMagnifier].
///
/// Covers: renders at focal point, custom magnification, custom size, and
/// [debugFillProperties] does not throw.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // 1. Renders at focal point
  // =========================================================================

  group('AndroidDocumentMagnifier — rendering', () {
    testWidgets('renders without error at given focal point', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AndroidDocumentMagnifier(
              focalPoint: Offset(100, 200),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AndroidDocumentMagnifier), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with custom magnification', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AndroidDocumentMagnifier(
              focalPoint: Offset(50, 50),
              magnification: 1.5,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AndroidDocumentMagnifier), findsOneWidget);
    });

    testWidgets('renders with custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AndroidDocumentMagnifier(
              focalPoint: Offset(50, 50),
              size: Size(120, 48),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AndroidDocumentMagnifier), findsOneWidget);
    });
  });

  // =========================================================================
  // 2. Default parameter values
  // =========================================================================

  group('AndroidDocumentMagnifier — defaults', () {
    test('default magnification is 1.25', () {
      const widget = AndroidDocumentMagnifier(focalPoint: Offset.zero);
      expect(widget.magnification, 1.25);
    });

    test('default size has positive width and height', () {
      const widget = AndroidDocumentMagnifier(focalPoint: Offset.zero);
      expect(widget.size.width, greaterThan(0));
      expect(widget.size.height, greaterThan(0));
    });
  });

  // =========================================================================
  // 3. debugFillProperties
  // =========================================================================

  group('AndroidDocumentMagnifier — diagnostics', () {
    test('debugFillProperties includes focalPoint and magnification', () {
      const widget = AndroidDocumentMagnifier(
        focalPoint: Offset(10, 20),
        magnification: 1.5,
      );

      final props = DiagnosticPropertiesBuilder();
      widget.debugFillProperties(props);

      expect(props.properties.any((p) => p.name == 'focalPoint'), isTrue);
      expect(props.properties.any((p) => p.name == 'magnification'), isTrue);
    });
  });
}
