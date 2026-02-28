/// Tests for [RenderParagraphBlock].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RenderParagraphBlock heading styles', () {
    const baseStyle = TextStyle(fontSize: 16.0);

    double blockHeight(ParagraphBlockType type) {
      final block = RenderParagraphBlock(
        nodeId: 'n',
        text: AttributedText('Heading'),
        blockType: type,
        baseTextStyle: baseStyle,
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      return block.size.height;
    }

    test('header1 is taller than paragraph', () {
      expect(blockHeight(ParagraphBlockType.header1),
          greaterThan(blockHeight(ParagraphBlockType.paragraph)));
    });

    test('header1 is taller than header2', () {
      expect(blockHeight(ParagraphBlockType.header1),
          greaterThan(blockHeight(ParagraphBlockType.header2)));
    });

    test('header2 is taller than header3', () {
      expect(blockHeight(ParagraphBlockType.header2),
          greaterThan(blockHeight(ParagraphBlockType.header3)));
    });

    test('header6 is shorter than or equal to paragraph', () {
      // h6 uses fontSize * 0.67 which is smaller than 1.0.
      expect(blockHeight(ParagraphBlockType.header6),
          lessThanOrEqualTo(blockHeight(ParagraphBlockType.paragraph)));
    });

    test('blockType setter triggers relayout', () {
      final block = RenderParagraphBlock(
        nodeId: 'n',
        text: AttributedText('Text'),
        blockType: ParagraphBlockType.paragraph,
        baseTextStyle: baseStyle,
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      final paragraphHeight = block.size.height;

      block.blockType = ParagraphBlockType.header1;
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.size.height, greaterThan(paragraphHeight));
    });

    test('blockquote lays out without error', () {
      final block = RenderParagraphBlock(
        nodeId: 'n',
        text: AttributedText('Quote'),
        blockType: ParagraphBlockType.blockquote,
        baseTextStyle: baseStyle,
      );
      expect(() => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
          returnsNormally);
      expect(block.size.height, greaterThan(0));
    });

    test('codeBlock block type lays out without error', () {
      final block = RenderParagraphBlock(
        nodeId: 'n',
        text: AttributedText('code()'),
        blockType: ParagraphBlockType.codeBlock,
        baseTextStyle: baseStyle,
      );
      expect(() => block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true),
          returnsNormally);
      expect(block.size.height, greaterThan(0));
    });
  });

  group('RenderParagraphBlock inherits RenderTextBlock behaviour', () {
    test('getPositionAtOffset works', () {
      final block = RenderParagraphBlock(
        nodeId: 'p',
        text: AttributedText('Hello world'),
        blockType: ParagraphBlockType.paragraph,
        baseTextStyle: const TextStyle(fontSize: 16),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      final pos = block.getPositionAtOffset(Offset.zero);
      expect(pos, isA<TextNodePosition>());
    });
  });
}
