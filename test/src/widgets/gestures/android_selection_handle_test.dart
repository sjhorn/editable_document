/// Tests for [AndroidSelectionHandle].
///
/// Covers: all three handle types render, drag callbacks fire, and
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
  // 1. Renders all three handle types
  // =========================================================================

  group('AndroidSelectionHandle — rendering', () {
    for (final type in AndroidHandleType.values) {
      testWidgets('renders AndroidHandleType.$type without error', (tester) async {
        final link = LayerLink();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CompositedTransformTarget(
                link: link,
                child: AndroidSelectionHandle(
                  layerLink: link,
                  type: type,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AndroidSelectionHandle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // =========================================================================
  // 2. Drag callbacks fire
  // =========================================================================

  group('AndroidSelectionHandle — drag callbacks', () {
    testWidgets('onDragStart fires when drag starts', (tester) async {
      bool dragStarted = false;
      final link = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: link,
              child: AndroidSelectionHandle(
                layerLink: link,
                type: AndroidHandleType.collapsed,
                color: Colors.blue,
                onDragStart: () {
                  dragStarted = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AndroidSelectionHandle)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(dragStarted, isTrue);
    });

    testWidgets('onDragUpdate fires during drag', (tester) async {
      bool dragUpdated = false;
      final link = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: link,
              child: AndroidSelectionHandle(
                layerLink: link,
                type: AndroidHandleType.right,
                color: Colors.blue,
                onDragUpdate: (_) {
                  dragUpdated = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AndroidSelectionHandle)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(dragUpdated, isTrue);
    });

    testWidgets('onDragEnd fires when drag ends', (tester) async {
      bool dragEnded = false;
      final link = LayerLink();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompositedTransformTarget(
              link: link,
              child: AndroidSelectionHandle(
                layerLink: link,
                type: AndroidHandleType.left,
                color: Colors.blue,
                onDragEnd: () {
                  dragEnded = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AndroidSelectionHandle)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(5, 0));
      await gesture.up();
      await tester.pump();

      expect(dragEnded, isTrue);
    });
  });

  // =========================================================================
  // 3. debugFillProperties
  // =========================================================================

  group('AndroidSelectionHandle — diagnostics', () {
    test('debugFillProperties includes type and color', () {
      final link = LayerLink();
      final widget = AndroidSelectionHandle(
        layerLink: link,
        type: AndroidHandleType.right,
        color: Colors.red,
      );

      final props = DiagnosticPropertiesBuilder();
      widget.debugFillProperties(props);

      expect(props.properties.any((p) => p.name == 'type'), isTrue);
      expect(props.properties.any((p) => p.name == 'color'), isTrue);
    });
  });
}
