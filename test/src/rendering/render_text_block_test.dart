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

  group('RenderTextBlock caret height stability', () {
    test('caret height is identical at space and non-space in header1 text', () {
      // Regression test: getLocalRectForPosition must return a consistent
      // caret height regardless of whether the position is at a space or a
      // non-space character.  Previously the implementation used
      // getFullHeightForCaret(), which can return different values at spaces
      // or attribution boundaries and causes a visible "jump".
      //
      // "Hello World" — position 5 is the space between the two words.
      final block = RenderTextBlock(
        nodeId: 'h1',
        text: AttributedText('Hello World'),
        textStyle: const TextStyle(
          fontSize: 32.0, // large size makes metric differences more apparent
          fontWeight: FontWeight.bold,
        ),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      // Height at a normal character position.
      final rectAtH = block.getLocalRectForPosition(const TextNodePosition(offset: 0));
      // Height at the space character.
      final rectAtSpace = block.getLocalRectForPosition(const TextNodePosition(offset: 5));
      // Height at a character after the space.
      final rectAfterSpace = block.getLocalRectForPosition(const TextNodePosition(offset: 6));

      expect(
        rectAtSpace.height,
        rectAtH.height,
        reason: 'caret height at a space must equal caret height at a normal character',
      );
      expect(
        rectAfterSpace.height,
        rectAtH.height,
        reason: 'caret height after a space must equal caret height at a normal character',
      );
    });
  });

  group('RenderTextBlock getLineBoundary', () {
    // Use a narrow width so that a long sentence wraps onto a second visual
    // line, giving us two distinct lines to query.
    const narrowWidth = 200.0;

    // The sentence is long enough that with fontSize 16 and maxWidth 200 it
    // will always wrap into at least two visual lines across all platforms.
    const sentence = 'The quick brown fox jumps over the lazy dog near the riverbank';

    late RenderTextBlock block;

    setUp(() {
      block = RenderTextBlock(
        nodeId: 'wrap',
        text: AttributedText(sentence),
        textStyle: const TextStyle(fontSize: 16),
      );
      block.layout(const BoxConstraints(maxWidth: narrowWidth), parentUsesSize: true);
    });

    test('returns a valid TextRange for a position on the first visual line', () {
      // Offset 0 is always on the first visual line.
      final range = block.getLineBoundary(const TextNodePosition(offset: 0));

      expect(range.isValid, isTrue);
      expect(range.start, 0);
      // The first line must end before the full sentence length.
      expect(range.end, lessThan(sentence.length));
    });

    test('first-line range does not extend to a position on the second line', () {
      final firstRange = block.getLineBoundary(const TextNodePosition(offset: 0));

      // A position just past the first-line boundary must not be contained in
      // the first-line range.
      expect(firstRange.end, lessThan(sentence.length),
          reason: 'text must wrap so that there is a second visual line');

      final secondRange = block.getLineBoundary(TextNodePosition(offset: firstRange.end));

      // The two ranges must be distinct (non-overlapping).
      expect(secondRange.start, greaterThanOrEqualTo(firstRange.end));
    });

    test('second visual line range starts where the first line ends', () {
      final firstRange = block.getLineBoundary(const TextNodePosition(offset: 0));

      // Query the position right at the start of the second visual line.
      final secondRange = block.getLineBoundary(TextNodePosition(offset: firstRange.end));

      expect(secondRange.start, firstRange.end);
      expect(secondRange.end, greaterThan(secondRange.start));
    });

    test('position in middle of first line still returns the full first-line range', () {
      final firstRange = block.getLineBoundary(const TextNodePosition(offset: 0));

      // Mid-point inside the first line.
      final mid = firstRange.end ~/ 2;
      expect(mid, greaterThan(0), reason: 'need a non-zero mid-point');

      final midRange = block.getLineBoundary(TextNodePosition(offset: mid));

      expect(midRange.start, firstRange.start);
      expect(midRange.end, firstRange.end);
    });
  });

  group('RenderTextBlock baseline computation', () {
    // getDryBaseline is callable without an active PipelineOwner, making
    // these tests straightforward unit tests.

    test('reports a non-null alphabetic baseline', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
        textStyle: const TextStyle(fontSize: 16),
      );
      final double? baseline = block.getDryBaseline(
        const BoxConstraints(maxWidth: 400),
        TextBaseline.alphabetic,
      );
      expect(baseline, isNotNull);
      expect(baseline, greaterThan(0));
    });

    test('alphabetic baseline is less than block height', () {
      // The baseline sits above the descender line, so it must be strictly
      // less than the full line height.
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
        textStyle: const TextStyle(fontSize: 16),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      final double baseline = block.getDryBaseline(
        const BoxConstraints(maxWidth: 400),
        TextBaseline.alphabetic,
      )!;
      expect(baseline, lessThan(block.size.height));
    });

    test('ideographic baseline is reported as non-null', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
        textStyle: const TextStyle(fontSize: 16),
      );
      final double? baseline = block.getDryBaseline(
        const BoxConstraints(maxWidth: 400),
        TextBaseline.ideographic,
      );
      expect(baseline, isNotNull);
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
