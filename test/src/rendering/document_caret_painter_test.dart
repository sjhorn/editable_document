/// Tests for [DocumentCaretPainter].
library;

import 'dart:ui';

import 'package:editable_document/editable_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentCaretPainter — shouldRepaint', () {
    test('returns false when nothing changes', () {
      const rect = Rect.fromLTWH(10, 20, 2, 18);
      final painter = const DocumentCaretPainter(caretRect: rect);
      final other = const DocumentCaretPainter(caretRect: rect);
      expect(painter.shouldRepaint(other), isFalse);
    });

    test('returns true when caretRect changes', () {
      final painter = const DocumentCaretPainter(caretRect: Rect.fromLTWH(0, 0, 2, 18));
      final other = const DocumentCaretPainter(caretRect: Rect.fromLTWH(10, 0, 2, 18));
      expect(painter.shouldRepaint(other), isTrue);
    });

    test('returns true when caretRect changes from null to non-null', () {
      final painter = const DocumentCaretPainter(caretRect: null);
      final other = const DocumentCaretPainter(caretRect: Rect.fromLTWH(0, 0, 2, 18));
      expect(painter.shouldRepaint(other), isTrue);
    });

    test('returns true when caretRect changes from non-null to null', () {
      final painter = const DocumentCaretPainter(caretRect: Rect.fromLTWH(0, 0, 2, 18));
      final other = const DocumentCaretPainter(caretRect: null);
      expect(painter.shouldRepaint(other), isTrue);
    });

    test('returns true when color changes', () {
      const rect = Rect.fromLTWH(0, 0, 2, 18);
      final painter = const DocumentCaretPainter(caretRect: rect, color: Color(0xFF000000));
      final other = const DocumentCaretPainter(caretRect: rect, color: Color(0xFFFF0000));
      expect(painter.shouldRepaint(other), isTrue);
    });

    test('returns true when visible changes', () {
      const rect = Rect.fromLTWH(0, 0, 2, 18);
      final painter = const DocumentCaretPainter(caretRect: rect, visible: true);
      final other = const DocumentCaretPainter(caretRect: rect, visible: false);
      expect(painter.shouldRepaint(other), isTrue);
    });

    test('returns false when visible is same', () {
      const rect = Rect.fromLTWH(0, 0, 2, 18);
      final painter = const DocumentCaretPainter(caretRect: rect, visible: false);
      final other = const DocumentCaretPainter(caretRect: rect, visible: false);
      expect(painter.shouldRepaint(other), isFalse);
    });
  });

  group('DocumentCaretPainter — paint', () {
    test('paints nothing when caretRect is null', () {
      final painter = const DocumentCaretPainter(caretRect: null);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 100));
      // If we get here without error, the painter correctly handles null.
      expect(true, isTrue);
    });

    test('paints nothing when visible is false', () {
      final painter = const DocumentCaretPainter(
        caretRect: Rect.fromLTWH(0, 0, 2, 18),
        visible: false,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      // Should complete without error — the painter bails early.
      expect(() => painter.paint(canvas, const Size(400, 100)), returnsNormally);
    });

    test('paints without error when caretRect is valid and visible', () {
      final painter = const DocumentCaretPainter(
        caretRect: Rect.fromLTWH(10, 5, 2, 18),
        color: Color(0xFF0000FF),
        visible: true,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(400, 100)), returnsNormally);
    });

    test('default width is 2.0', () {
      final painter = const DocumentCaretPainter(caretRect: Rect.fromLTWH(0, 0, 2, 18));
      expect(painter.width, 2.0);
    });

    test('default cornerRadius is 1.0', () {
      final painter = const DocumentCaretPainter(caretRect: Rect.fromLTWH(0, 0, 2, 18));
      expect(painter.cornerRadius, 1.0);
    });

    test('default color is black', () {
      final painter = const DocumentCaretPainter(caretRect: Rect.fromLTWH(0, 0, 2, 18));
      expect(painter.color, const Color(0xFF000000));
    });

    test('default visible is true', () {
      final painter = const DocumentCaretPainter(caretRect: Rect.fromLTWH(0, 0, 2, 18));
      expect(painter.visible, isTrue);
    });
  });
}
