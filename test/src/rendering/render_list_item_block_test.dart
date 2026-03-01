/// Tests for [RenderListItemBlock] geometry query methods.
///
/// Verifies that [getLocalRectForPosition], [getPositionAtOffset], and
/// [getEndpointsForSelection] all account for the horizontal text indent that
/// [RenderListItemBlock] applies during paint.
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The marker width constant mirrored from render_list_item_block.dart.
/// For indent=0 the text starts at 24.0 * (0 + 1) = 24.0.
const double _kExpectedIndentOffset = 24.0;

void main() {
  group('RenderListItemBlock geometry queries', () {
    late RenderListItemBlock block;

    setUp(() {
      block = RenderListItemBlock(
        nodeId: 'li1',
        text: AttributedText('List item text'),
        textStyle: const TextStyle(fontSize: 16),
      );
      // indent=0 (default) → _textIndentOffset = 24.0 * 1 = 24.0
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
    });

    test('getLocalRectForPosition shifts rect left edge by text indent offset', () {
      final rect = block.getLocalRectForPosition(const TextNodePosition(offset: 0));
      // The caret at offset 0 should be at x=24.0, not x=0.0, because the
      // text is painted starting at _textIndentOffset.
      expect(rect.left, _kExpectedIndentOffset);
    });

    test('getLocalRectForPosition has positive height', () {
      final rect = block.getLocalRectForPosition(const TextNodePosition(offset: 0));
      expect(rect.height, greaterThan(0));
    });

    test('getLocalRectForPosition at later offset is still shifted', () {
      final r0 = block.getLocalRectForPosition(const TextNodePosition(offset: 0));
      final r5 = block.getLocalRectForPosition(const TextNodePosition(offset: 5));
      // Both rects must start at or beyond the indent offset.
      expect(r0.left, greaterThanOrEqualTo(_kExpectedIndentOffset));
      expect(r5.left, greaterThan(r0.left));
    });

    test('getPositionAtOffset at x=indent returns offset 0', () {
      // Tapping at the very start of the text area (x == _textIndentOffset)
      // should map to the first character in the text, not a position within
      // the marker gutter.
      final pos =
          block.getPositionAtOffset(const Offset(_kExpectedIndentOffset, 0)) as TextNodePosition;
      expect(pos.offset, 0);
    });

    test('getPositionAtOffset removes indent before hit-testing', () {
      // Without the fix, tapping at x=0 (inside the marker gutter) would be
      // passed directly to the TextPainter and would still return offset 0
      // (clamped), so this test distinguishes by checking that a tap at x=0
      // maps to offset 0 while a tap shifted right maps to a later offset.
      final posAtStart =
          block.getPositionAtOffset(const Offset(_kExpectedIndentOffset, 0)) as TextNodePosition;
      // A tap well to the right of the indent should give a non-zero offset.
      final posAtRight =
          block.getPositionAtOffset(Offset(block.size.width - 1, 0)) as TextNodePosition;
      expect(posAtRight.offset, greaterThan(posAtStart.offset));
    });

    test('getEndpointsForSelection rects are shifted by text indent offset', () {
      final rects = block.getEndpointsForSelection(
        const TextNodePosition(offset: 0),
        const TextNodePosition(offset: 4),
      );
      expect(rects, isNotEmpty);
      for (final r in rects) {
        // Every selection rect must start at or beyond the indent offset.
        expect(
          r.left,
          greaterThanOrEqualTo(_kExpectedIndentOffset),
          reason: 'selection rect left=${r.left} is inside the marker gutter',
        );
      }
    });

    test('getEndpointsForSelection collapsed returns empty', () {
      final rects = block.getEndpointsForSelection(
        const TextNodePosition(offset: 3),
        const TextNodePosition(offset: 3),
      );
      expect(rects, isEmpty);
    });
  });

  group('RenderListItemBlock geometry queries — ordered list with indent', () {
    late RenderListItemBlock block;

    setUp(() {
      block = RenderListItemBlock(
        nodeId: 'li2',
        text: AttributedText('Nested item'),
        textStyle: const TextStyle(fontSize: 16),
        type: ListItemType.ordered,
        indent: 1,
        ordinalIndex: 2,
      );
      // indent=1 → _textIndentOffset = 24.0 * (1 + 1) = 48.0
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
    });

    test('getLocalRectForPosition shifts by two marker widths for indent=1', () {
      const expectedOffset = 24.0 * 2; // 48.0
      final rect = block.getLocalRectForPosition(const TextNodePosition(offset: 0));
      expect(rect.left, expectedOffset);
    });

    test('getEndpointsForSelection rects start at two-marker-width offset', () {
      const expectedOffset = 24.0 * 2; // 48.0
      final rects = block.getEndpointsForSelection(
        const TextNodePosition(offset: 0),
        const TextNodePosition(offset: 3),
      );
      expect(rects, isNotEmpty);
      for (final r in rects) {
        expect(r.left, greaterThanOrEqualTo(expectedOffset));
      }
    });
  });
}
