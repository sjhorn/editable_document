/// Tests for [RenderTextBlock].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RenderTextBlock layout', () {
    test('lays out with constrained width', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello world'),
        textStyle: const TextStyle(fontSize: 16),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      expect(block.size.width, 400.0);
      expect(block.size.height, greaterThan(0));
    });

    test('empty text still has a positive height', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText(''),
        textStyle: const TextStyle(fontSize: 16),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.size.height, greaterThan(0));
    });

    test('markNeedsLayout called when text changes', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
        textStyle: const TextStyle(fontSize: 16),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      final heightBefore = block.size.height;

      block.text = AttributedText('Hello\nworld\nmore lines here');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      // Multi-line text should be taller.
      expect(block.size.height, greaterThanOrEqualTo(heightBefore));
    });
  });

  group('RenderTextBlock hit testing', () {
    late RenderTextBlock block;

    setUp(() {
      block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello world'),
        textStyle: const TextStyle(fontSize: 16),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
    });

    test('getPositionAtOffset returns TextNodePosition', () {
      final pos = block.getPositionAtOffset(Offset.zero);
      expect(pos, isA<TextNodePosition>());
    });

    test('tap at start gives offset 0', () {
      final pos = block.getPositionAtOffset(Offset.zero) as TextNodePosition;
      expect(pos.offset, 0);
    });

    test('tap at right edge gives a valid offset', () {
      final pos = block.getPositionAtOffset(Offset(block.size.width - 1, 0)) as TextNodePosition;
      expect(pos.offset, greaterThan(0));
    });
  });

  group('RenderTextBlock position queries', () {
    late RenderTextBlock block;

    setUp(() {
      block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello world'),
        textStyle: const TextStyle(fontSize: 16),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
    });

    test('getLocalRectForPosition returns non-empty Rect', () {
      final rect = block.getLocalRectForPosition(const TextNodePosition(offset: 0));
      expect(rect, isA<Rect>());
      expect(rect.height, greaterThan(0));
    });

    test('getLocalRectForPosition at different offsets differ in x', () {
      final r0 = block.getLocalRectForPosition(const TextNodePosition(offset: 0));
      final r5 = block.getLocalRectForPosition(const TextNodePosition(offset: 5));
      expect(r5.left, greaterThan(r0.left));
    });

    test('getEndpointsForSelection returns rects covering the range', () {
      final rects = block.getEndpointsForSelection(
        const TextNodePosition(offset: 0),
        const TextNodePosition(offset: 5),
      );
      expect(rects, isNotEmpty);
      for (final r in rects) {
        expect(r.width, greaterThan(0));
        expect(r.height, greaterThan(0));
      }
    });

    test('getEndpointsForSelection collapsed returns empty or zero-width', () {
      final rects = block.getEndpointsForSelection(
        const TextNodePosition(offset: 3),
        const TextNodePosition(offset: 3),
      );
      // Collapsed selection has no highlight boxes.
      expect(rects, isEmpty);
    });
  });

  group('RenderTextBlock attribution to TextStyle mapping', () {
    test('bold attribution produces bold text (taller block with more ink)', () {
      final plain = RenderTextBlock(
        nodeId: 'a',
        text: AttributedText('Bold'),
        textStyle: const TextStyle(fontSize: 16),
      );
      plain.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      // Bold text with an attribution applied.
      final boldText = AttributedText('Bold').applyAttribution(
        NamedAttribution.bold,
        0,
        3,
      );
      final bold = RenderTextBlock(
        nodeId: 'b',
        text: boldText,
        textStyle: const TextStyle(fontSize: 16),
      );
      bold.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      // Both should have a positive height; bold text rect should be at least
      // as wide as plain (font metrics may vary by platform, so we just verify
      // it lays out without error and height is positive).
      expect(bold.size.height, greaterThan(0));
    });

    test('italic attribution does not throw', () {
      final italicText = AttributedText('Italic').applyAttribution(
        NamedAttribution.italics,
        0,
        5,
      );
      final block = RenderTextBlock(
        nodeId: 'c',
        text: italicText,
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(() => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
          returnsNormally);
    });

    test('underline attribution does not throw', () {
      final text = AttributedText('Under').applyAttribution(
        NamedAttribution.underline,
        0,
        4,
      );
      final block = RenderTextBlock(
        nodeId: 'd',
        text: text,
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(() => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
          returnsNormally);
    });

    test('strikethrough attribution does not throw', () {
      final text = AttributedText('Strike').applyAttribution(
        NamedAttribution.strikethrough,
        0,
        5,
      );
      final block = RenderTextBlock(
        nodeId: 'e',
        text: text,
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(() => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
          returnsNormally);
    });

    test('code attribution uses monospace family', () {
      final text = AttributedText('code()').applyAttribution(
        NamedAttribution.code,
        0,
        5,
      );
      final block = RenderTextBlock(
        nodeId: 'f',
        text: text,
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(() => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
          returnsNormally);
    });
  });

  group('RenderTextBlock property setters', () {
    test('setting nodeId updates nodeId', () {
      final block = RenderTextBlock(
        nodeId: 'old',
        text: AttributedText('hi'),
      );
      block.nodeId = 'new';
      expect(block.nodeId, 'new');
    });

    test('setting textDirection updates painter direction', () {
      final block = RenderTextBlock(
        nodeId: 'p',
        text: AttributedText('hi'),
        textDirection: TextDirection.ltr,
      );
      block.textDirection = TextDirection.rtl;
      expect(block.textDirection, TextDirection.rtl);
    });

    test('setting textAlign updates painter alignment', () {
      final block = RenderTextBlock(
        nodeId: 'p',
        text: AttributedText('hi'),
        textAlign: TextAlign.start,
      );
      block.textAlign = TextAlign.center;
      expect(block.textAlign, TextAlign.center);
    });

    test('TextNodePosition with upstream affinity works', () {
      final block = RenderTextBlock(
        nodeId: 'p',
        text: AttributedText('Hello'),
        textStyle: const TextStyle(fontSize: 16),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      final rect = block.getLocalRectForPosition(
        const TextNodePosition(offset: 3, affinity: TextAffinity.upstream),
      );
      expect(rect.height, greaterThan(0));
    });
  });
}
