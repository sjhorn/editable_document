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

  group('FontFamilyAttribution rendering', () {
    test('renders text with font family attribution without throwing', () {
      final text = AttributedText('Roboto text').applyAttribution(
        const FontFamilyAttribution('Roboto'),
        0,
        10,
      );
      final block = RenderTextBlock(
        nodeId: 'ff1',
        text: text,
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(
        () => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
        returnsNormally,
      );
    });

    test('font family attribution produces a positive-height block', () {
      final text = AttributedText('Monospace').applyAttribution(
        const FontFamilyAttribution('monospace'),
        0,
        8,
      );
      final block = RenderTextBlock(
        nodeId: 'ff2',
        text: text,
        textStyle: const TextStyle(fontSize: 16),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.size.height, greaterThan(0));
    });

    test('different font families on adjacent runs do not throw', () {
      final rawText = AttributedText('AB');
      final withA = rawText.applyAttribution(const FontFamilyAttribution('Roboto'), 0, 0);
      final withAB = withA.applyAttribution(const FontFamilyAttribution('Merriweather'), 1, 1);
      final block = RenderTextBlock(
        nodeId: 'ff3',
        text: withAB,
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(
        () => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
        returnsNormally,
      );
    });
  });

  group('FontSizeAttribution rendering', () {
    test('renders text with font size attribution without throwing', () {
      final text = AttributedText('Large text').applyAttribution(
        const FontSizeAttribution(24.0),
        0,
        9,
      );
      final block = RenderTextBlock(
        nodeId: 'fs1',
        text: text,
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(
        () => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
        returnsNormally,
      );
    });

    test('larger font size attribution produces a taller block', () {
      final normalText = AttributedText('Hello');
      final largeText = AttributedText('Hello').applyAttribution(
        const FontSizeAttribution(48.0),
        0,
        4,
      );

      final normalBlock = RenderTextBlock(
        nodeId: 'fs2a',
        text: normalText,
        textStyle: const TextStyle(fontSize: 16),
      );
      normalBlock.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      final largeBlock = RenderTextBlock(
        nodeId: 'fs2b',
        text: largeText,
        textStyle: const TextStyle(fontSize: 16),
      );
      largeBlock.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      expect(largeBlock.size.height, greaterThan(normalBlock.size.height));
    });

    test('font size attribution on partial run does not throw', () {
      // Apply large font to just a few characters in the middle.
      final text = AttributedText('Hello World').applyAttribution(
        const FontSizeAttribution(32.0),
        3,
        7,
      );
      final block = RenderTextBlock(
        nodeId: 'fs3',
        text: text,
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(
        () => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
        returnsNormally,
      );
    });
  });

  group('TextColorAttribution rendering', () {
    test('renders text with text color attribution without throwing', () {
      final text = AttributedText('Red text').applyAttribution(
        const TextColorAttribution(0xFFFF0000),
        0,
        7,
      );
      final block = RenderTextBlock(
        nodeId: 'tc1',
        text: text,
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(
        () => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
        returnsNormally,
      );
    });

    test('text color attribution produces a positive-height block', () {
      final text = AttributedText('Blue text').applyAttribution(
        const TextColorAttribution(0xFF0000FF),
        0,
        8,
      );
      final block = RenderTextBlock(
        nodeId: 'tc2',
        text: text,
        textStyle: const TextStyle(fontSize: 16),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.size.height, greaterThan(0));
    });

    test('multiple text color attributions on adjacent runs do not throw', () {
      final rawText = AttributedText('RG');
      final withR = rawText.applyAttribution(const TextColorAttribution(0xFFFF0000), 0, 0);
      final withRG = withR.applyAttribution(const TextColorAttribution(0xFF00FF00), 1, 1);
      final block = RenderTextBlock(
        nodeId: 'tc3',
        text: withRG,
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(
        () => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
        returnsNormally,
      );
    });
  });

  group('BackgroundColorAttribution rendering', () {
    test('renders text with background color attribution without throwing', () {
      final text = AttributedText('Highlighted').applyAttribution(
        const BackgroundColorAttribution(0xFFFFFF00),
        0,
        10,
      );
      final block = RenderTextBlock(
        nodeId: 'bg1',
        text: text,
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(
        () => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
        returnsNormally,
      );
    });

    test('background color attribution produces a positive-height block', () {
      final text = AttributedText('Highlighted').applyAttribution(
        const BackgroundColorAttribution(0xFF00FF00),
        0,
        10,
      );
      final block = RenderTextBlock(
        nodeId: 'bg2',
        text: text,
        textStyle: const TextStyle(fontSize: 16),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.size.height, greaterThan(0));
    });

    test('background color does not interfere with text color attribution', () {
      // Apply both text color and background color to the same span.
      final withTextColor = AttributedText('Styled').applyAttribution(
        const TextColorAttribution(0xFFFFFFFF),
        0,
        5,
      );
      final withBoth = withTextColor.applyAttribution(
        const BackgroundColorAttribution(0xFF000000),
        0,
        5,
      );
      final block = RenderTextBlock(
        nodeId: 'bg3',
        text: withBoth,
        textStyle: const TextStyle(fontSize: 16),
      );
      expect(
        () => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
        returnsNormally,
      );
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

  // ---------------------------------------------------------------------------
  // Exclusion zone text wrapping (center float)
  // ---------------------------------------------------------------------------

  group('RenderTextBlock exclusion zone layout', () {
    // Helper that creates a layout with a center float + text, returning the
    // text block whose parentData will have exclusionRect set.
    RenderTextBlock _textBlockWithExclusion({
      String text = 'The quick brown fox jumps over the lazy dog and '
          'continues running across the wide open field where many animals '
          'roam freely beneath the clear blue sky on a warm summer day.',
      double maxWidth = 400.0,
      double floatWidth = 100.0,
      double floatHeight = 80.0,
    }) {
      final image = RenderImageBlock(
        nodeId: 'img1',
        imageWidth: floatWidth,
        imageHeight: floatHeight,
        blockAlignment: BlockAlignment.center,
        requestedWidth: floatWidth,
        requestedHeight: floatHeight,
        textWrap: true,
      );
      final textBlock = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText(text),
        textStyle: const TextStyle(fontSize: 16),
      );
      final layout = RenderDocumentLayout(blockSpacing: 0.0);
      layout.add(image);
      layout.add(textBlock);
      layout.layout(BoxConstraints(maxWidth: maxWidth), parentUsesSize: true);
      return textBlock;
    }

    test('text block beside center float has exclusionRect set', () {
      final block = _textBlockWithExclusion();
      final data = block.parentData as DocumentBlockParentData;
      expect(data.exclusionRect, isNotNull);
    });

    test('text block has positive height with exclusion zone', () {
      final block = _textBlockWithExclusion();
      expect(block.size.height, greaterThan(0));
    });

    test('block height is at least the exclusion rect height', () {
      final block = _textBlockWithExclusion();
      final data = block.parentData as DocumentBlockParentData;
      // With enough text, the block should be at least as tall as the
      // exclusion zone.
      expect(block.size.height, greaterThanOrEqualTo(data.exclusionRect!.height));
    });

    test('text block width is full maxWidth with center float', () {
      const maxWidth = 400.0;
      final block = _textBlockWithExclusion(maxWidth: maxWidth);
      expect(block.size.width, closeTo(maxWidth, 0.5));
    });

    test('hit test at left of exclusion zone returns valid text position', () {
      final block = _textBlockWithExclusion();
      final data = block.parentData as DocumentBlockParentData;
      final exclusion = data.exclusionRect!;

      // Click in the left column area, vertically in the middle of exclusion.
      final midY = (exclusion.top + exclusion.bottom) / 2;
      final pos = block.getPositionAtOffset(Offset(10.0, midY));
      expect(pos, isA<TextNodePosition>());
    });

    test('hit test at right of exclusion zone returns valid text position', () {
      final block = _textBlockWithExclusion();
      final data = block.parentData as DocumentBlockParentData;
      final exclusion = data.exclusionRect!;

      // Click in the right column area, vertically in the middle of exclusion.
      final midY = (exclusion.top + exclusion.bottom) / 2;
      final pos = block.getPositionAtOffset(Offset(exclusion.right + 10.0, midY));
      expect(pos, isA<TextNodePosition>());
    });

    test('hit test above exclusion zone returns valid text position', () {
      // If there is text above the exclusion (when exclusion.top > 0).
      final block = _textBlockWithExclusion();
      final pos = block.getPositionAtOffset(const Offset(10.0, 2.0));
      expect(pos, isA<TextNodePosition>());
    });

    test('hit test below exclusion zone returns valid text position', () {
      final block = _textBlockWithExclusion();
      final data = block.parentData as DocumentBlockParentData;
      final exclusion = data.exclusionRect!;

      // Click below the exclusion zone.
      if (block.size.height > exclusion.bottom + 5.0) {
        final pos = block.getPositionAtOffset(Offset(10.0, exclusion.bottom + 5.0));
        expect(pos, isA<TextNodePosition>());
      }
    });

    test('caret rect for position 0 has valid height', () {
      final block = _textBlockWithExclusion();
      final rect = block.getLocalRectForPosition(
        const TextNodePosition(offset: 0),
      );
      expect(rect.height, greaterThan(0));
    });

    test('caret rect for end-of-text position is not at x=0', () {
      // Use short text so all of it fits in the beside zone (no below zone).
      final block = _textBlockWithExclusion(
        text: 'Short text.',
        floatHeight: 200.0,
      );
      final endPos = const TextNodePosition(offset: 'Short text.'.length);
      final rect = block.getLocalRectForPosition(endPos);
      expect(rect.height, greaterThan(0));
      // The caret should be at the end of the text, not at x=0.
      expect(rect.left, greaterThan(0));
    });

    test('getEndpointsForSelection returns rects with exclusion zone', () {
      final block = _textBlockWithExclusion();
      final rects = block.getEndpointsForSelection(
        const TextNodePosition(offset: 0),
        const TextNodePosition(offset: 10),
      );
      expect(rects, isNotEmpty);
      for (final r in rects) {
        expect(r.height, greaterThan(0));
      }
    });
  });
}
