/// Tests for [DocumentSelectionPainter].
library;

import 'dart:ui';

import 'package:editable_document/editable_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentSelectionPainter — shouldRepaint', () {
    test('returns false when nothing changes', () {
      final rects = [const Rect.fromLTWH(0, 0, 100, 20)];
      final painter = DocumentSelectionPainter(selectionRects: rects);
      final other = DocumentSelectionPainter(selectionRects: rects);
      expect(painter.shouldRepaint(other), isFalse);
    });

    test('returns true when selectionRects changes', () {
      final painter = const DocumentSelectionPainter(
        selectionRects: [Rect.fromLTWH(0, 0, 100, 20)],
      );
      final other = const DocumentSelectionPainter(
        selectionRects: [Rect.fromLTWH(0, 0, 200, 20)],
      );
      expect(painter.shouldRepaint(other), isTrue);
    });

    test('returns true when rects list length differs', () {
      final painter = const DocumentSelectionPainter(
        selectionRects: [Rect.fromLTWH(0, 0, 100, 20)],
      );
      final other = const DocumentSelectionPainter(
        selectionRects: [
          Rect.fromLTWH(0, 0, 100, 20),
          Rect.fromLTWH(0, 20, 80, 20),
        ],
      );
      expect(painter.shouldRepaint(other), isTrue);
    });

    test('returns true when selectionColor changes', () {
      const rects = <Rect>[];
      final painter = const DocumentSelectionPainter(
        selectionRects: rects,
        selectionColor: Color(0x663399FF),
      );
      final other = const DocumentSelectionPainter(
        selectionRects: rects,
        selectionColor: Color(0x66FF3399),
      );
      expect(painter.shouldRepaint(other), isTrue);
    });

    test('returns false when color is same and rects are identical list', () {
      const rects = <Rect>[];
      final painter = const DocumentSelectionPainter(
        selectionRects: rects,
        selectionColor: Color(0x663399FF),
      );
      final other = const DocumentSelectionPainter(
        selectionRects: rects,
        selectionColor: Color(0x663399FF),
      );
      expect(painter.shouldRepaint(other), isFalse);
    });
  });

  group('DocumentSelectionPainter — paint', () {
    test('paints nothing when selectionRects is empty', () {
      final painter = const DocumentSelectionPainter(selectionRects: []);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(400, 200)), returnsNormally);
    });

    test('paints without error for a single rect', () {
      final painter = const DocumentSelectionPainter(
        selectionRects: [Rect.fromLTWH(10, 5, 100, 20)],
        selectionColor: Color(0x663399FF),
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(400, 200)), returnsNormally);
    });

    test('paints without error for multiple rects (cross-block selection)', () {
      final painter = const DocumentSelectionPainter(
        selectionRects: [
          Rect.fromLTWH(50, 0, 200, 20),
          Rect.fromLTWH(0, 24, 400, 20),
          Rect.fromLTWH(0, 48, 80, 20),
        ],
        selectionColor: Color(0x663399FF),
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(400, 200)), returnsNormally);
    });

    test('default selectionColor is semi-transparent blue', () {
      final painter = const DocumentSelectionPainter(selectionRects: []);
      expect(painter.selectionColor, const Color(0x663399FF));
    });
  });
}
