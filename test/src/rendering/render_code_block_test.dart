/// Tests for [RenderCodeBlock].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RenderCodeBlock layout property defaults and setters', () {
    test('blockAlignment defaults to BlockAlignment.stretch', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
      );
      expect(block.blockAlignment, BlockAlignment.stretch);
    });

    test('requestedWidth defaults to null', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
      );
      expect(block.requestedWidth, isNull);
    });

    test('requestedHeight defaults to null', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
      );
      expect(block.requestedHeight, isNull);
    });

    test('textWrap defaults to false', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
      );
      expect(block.textWrap, isFalse);
    });

    test('blockAlignment setter roundtrip', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
      );
      block.blockAlignment = BlockAlignment.center;
      expect(block.blockAlignment, BlockAlignment.center);
    });

    test('requestedWidth setter roundtrip', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
      );
      block.requestedWidth = 250.0;
      expect(block.requestedWidth, 250.0);
    });

    test('requestedHeight setter roundtrip', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
      );
      block.requestedHeight = 80.0;
      expect(block.requestedHeight, 80.0);
    });

    test('textWrap setter roundtrip', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
      );
      block.textWrap = true;
      expect(block.textWrap, isTrue);
    });

    test('setting blockAlignment to same value is a no-op', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
      );
      block.blockAlignment = BlockAlignment.stretch;
      expect(block.blockAlignment, BlockAlignment.stretch);
    });

    test('constructor accepts blockAlignment parameter', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
        blockAlignment: BlockAlignment.start,
      );
      expect(block.blockAlignment, BlockAlignment.start);
    });

    test('constructor accepts requestedWidth parameter', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
        requestedWidth: 320.0,
      );
      expect(block.requestedWidth, 320.0);
    });

    test('constructor accepts requestedHeight parameter', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
        requestedHeight: 120.0,
      );
      expect(block.requestedHeight, 120.0);
    });

    test('constructor accepts textWrap parameter', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
        textWrap: true,
      );
      expect(block.textWrap, isTrue);
    });

    test('requestedWidth constrains text layout width', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
        requestedWidth: 200.0,
      );
      block.layout(
        const BoxConstraints(maxWidth: 600, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      // Block width should equal requestedWidth when it fits within constraints.
      expect(block.size.width, 200.0);
    });

    test('requestedHeight sets block height', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
        requestedHeight: 80.0,
      );
      block.layout(
        const BoxConstraints(maxWidth: 600, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      expect(block.size.height, 80.0);
    });
  });
}
