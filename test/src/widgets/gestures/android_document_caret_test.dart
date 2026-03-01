/// Tests for [AndroidDocumentCaret].
///
/// Covers: renders without error, drag callbacks fire, and
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
  // 1. Renders
  // =========================================================================

  group('AndroidDocumentCaret — rendering', () {
    testWidgets('renders without error', (tester) async {
      final link = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: link,
              child: AndroidDocumentCaret(
                layerLink: link,
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AndroidDocumentCaret), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with custom color', (tester) async {
      final link = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: link,
              child: AndroidDocumentCaret(
                layerLink: link,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AndroidDocumentCaret), findsOneWidget);
    });
  });

  // =========================================================================
  // 2. Drag callbacks
  // =========================================================================

  group('AndroidDocumentCaret — drag callbacks', () {
    testWidgets('onDragStart fires when drag begins', (tester) async {
      bool started = false;
      final link = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: link,
              child: AndroidDocumentCaret(
                layerLink: link,
                color: Colors.black,
                onDragStart: () => started = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AndroidDocumentCaret)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(started, isTrue);
    });

    testWidgets('onDragUpdate fires during drag', (tester) async {
      bool updated = false;
      final link = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: link,
              child: AndroidDocumentCaret(
                layerLink: link,
                color: Colors.black,
                onDragUpdate: (_) => updated = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AndroidDocumentCaret)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(15, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(updated, isTrue);
    });

    testWidgets('onDragEnd fires when drag ends', (tester) async {
      bool ended = false;
      final link = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: link,
              child: AndroidDocumentCaret(
                layerLink: link,
                color: Colors.black,
                onDragEnd: () => ended = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AndroidDocumentCaret)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(5, 0));
      await gesture.up();
      await tester.pump();

      expect(ended, isTrue);
    });
  });

  // =========================================================================
  // 3. debugFillProperties
  // =========================================================================

  group('AndroidDocumentCaret — diagnostics', () {
    test('debugFillProperties includes color', () {
      final link = LayerLink();
      final widget = AndroidDocumentCaret(
        layerLink: link,
        color: Colors.green,
      );

      final props = DiagnosticPropertiesBuilder();
      widget.debugFillProperties(props);

      expect(props.properties.any((p) => p.name == 'color'), isTrue);
    });
  });
}
