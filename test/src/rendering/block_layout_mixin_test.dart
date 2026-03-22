/// Tests for [BlockLayoutMixin].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlockLayoutMixin', () {
    test('default values match BlockAlignment.stretch and false/null', () {
      final block = RenderImageBlock(nodeId: 'test-1');
      expect(block.blockAlignment, BlockAlignment.stretch);
      expect(block.requestedWidth, isNull);
      expect(block.requestedHeight, isNull);
      expect(block.textWrap, TextWrapMode.none);
    });

    test('initBlockLayout sets values without markNeedsLayout', () {
      // The constructor calls initBlockLayout, so we verify values are set.
      final block = RenderImageBlock(
        nodeId: 'test-1',
        blockAlignment: BlockAlignment.center,
        requestedWidth: 300.0,
        requestedHeight: 200.0,
        textWrap: TextWrapMode.wrap,
      );
      expect(block.blockAlignment, BlockAlignment.center);
      expect(block.requestedWidth, 300.0);
      expect(block.requestedHeight, 200.0);
      expect(block.textWrap, TextWrapMode.wrap);
    });

    test('blockAlignment setter triggers markNeedsLayout', () {
      final block = RenderImageBlock(nodeId: 'test-1');
      // Layout once so markNeedsLayout has a meaningful state.
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.debugNeedsLayout, false);

      block.blockAlignment = BlockAlignment.center;
      expect(block.debugNeedsLayout, true);
    });

    test('blockAlignment setter is a no-op for same value', () {
      final block = RenderImageBlock(
        nodeId: 'test-1',
        blockAlignment: BlockAlignment.center,
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.debugNeedsLayout, false);

      block.blockAlignment = BlockAlignment.center;
      expect(block.debugNeedsLayout, false);
    });

    test('requestedWidth setter triggers markNeedsLayout', () {
      final block = RenderImageBlock(nodeId: 'test-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.debugNeedsLayout, false);

      block.requestedWidth = 200.0;
      expect(block.debugNeedsLayout, true);
    });

    test('requestedWidth setter is a no-op for same value', () {
      final block = RenderImageBlock(nodeId: 'test-1', requestedWidth: 200.0);
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.debugNeedsLayout, false);

      block.requestedWidth = 200.0;
      expect(block.debugNeedsLayout, false);
    });

    test('requestedHeight setter triggers markNeedsLayout', () {
      final block = RenderImageBlock(nodeId: 'test-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.debugNeedsLayout, false);

      block.requestedHeight = 150.0;
      expect(block.debugNeedsLayout, true);
    });

    test('requestedHeight setter is a no-op for same value', () {
      final block = RenderImageBlock(nodeId: 'test-1', requestedHeight: 150.0);
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.debugNeedsLayout, false);

      block.requestedHeight = 150.0;
      expect(block.debugNeedsLayout, false);
    });

    test('textWrap setter triggers markNeedsLayout', () {
      final block = RenderImageBlock(nodeId: 'test-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.debugNeedsLayout, false);

      block.textWrap = TextWrapMode.wrap;
      expect(block.debugNeedsLayout, true);
    });

    test('textWrap setter is a no-op for same value', () {
      final block = RenderImageBlock(nodeId: 'test-1', textWrap: TextWrapMode.wrap);
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.debugNeedsLayout, false);

      block.textWrap = TextWrapMode.wrap;
      expect(block.debugNeedsLayout, false);
    });

    test('mixin works on RenderCodeBlock', () {
      final block = RenderCodeBlock(
        nodeId: 'code-1',
        text: AttributedText('hello'),
        blockAlignment: BlockAlignment.end,
        requestedWidth: 500.0,
        textWrap: TextWrapMode.wrap,
      );
      expect(block.blockAlignment, BlockAlignment.end);
      expect(block.requestedWidth, 500.0);
      expect(block.textWrap, TextWrapMode.wrap);
    });

    test('mixin works on RenderBlockquoteBlock', () {
      final block = RenderBlockquoteBlock(
        nodeId: 'bq-1',
        text: AttributedText('quote'),
        blockAlignment: BlockAlignment.start,
        requestedHeight: 100.0,
      );
      expect(block.blockAlignment, BlockAlignment.start);
      expect(block.requestedHeight, 100.0);
    });

    test('mixin works on RenderHorizontalRuleBlock', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        blockAlignment: BlockAlignment.center,
        requestedWidth: 200.0,
        requestedHeight: 4.0,
        textWrap: TextWrapMode.wrap,
      );
      expect(block.blockAlignment, BlockAlignment.center);
      expect(block.requestedWidth, 200.0);
      expect(block.requestedHeight, 4.0);
      expect(block.textWrap, TextWrapMode.wrap);
    });

    test('debugFillBlockLayoutProperties adds dimension and resolved properties', () {
      final block = RenderImageBlock(
        nodeId: 'test-1',
        blockAlignment: BlockAlignment.center,
        widthDimension: const BlockDimension.pixels(300.0),
        heightDimension: const BlockDimension.pixels(200.0),
        textWrap: TextWrapMode.wrap,
      );
      final builder = DiagnosticPropertiesBuilder();
      block.debugFillBlockLayoutProperties(builder);
      final names = builder.properties.map((p) => p.name).toList();
      expect(names, contains('blockAlignment'));
      expect(names, contains('widthDimension'));
      expect(names, contains('heightDimension'));
      expect(names, contains('requestedWidth'));
      expect(names, contains('requestedHeight'));
      expect(names, contains('textWrap'));
    });
  });

  group('BlockLayoutMixin — BlockDimension', () {
    test('widthDimension defaults to null', () {
      final block = RenderImageBlock(nodeId: 'test-1');
      expect(block.widthDimension, isNull);
    });

    test('heightDimension defaults to null', () {
      final block = RenderImageBlock(nodeId: 'test-1');
      expect(block.heightDimension, isNull);
    });

    test('PixelDimension resolves requestedWidth immediately via constructor', () {
      final block = RenderImageBlock(
        nodeId: 'test-1',
        widthDimension: const BlockDimension.pixels(400.0),
      );
      expect(block.widthDimension, const BlockDimension.pixels(400.0));
      expect(block.requestedWidth, 400.0);
    });

    test('PixelDimension resolves requestedHeight immediately via constructor', () {
      final block = RenderImageBlock(
        nodeId: 'test-1',
        heightDimension: const BlockDimension.pixels(200.0),
      );
      expect(block.heightDimension, const BlockDimension.pixels(200.0));
      expect(block.requestedHeight, 200.0);
    });

    test('PercentDimension leaves requestedWidth null until resolved', () {
      final block = RenderImageBlock(
        nodeId: 'test-1',
        widthDimension: const BlockDimension.percent(0.5),
      );
      expect(block.widthDimension, const BlockDimension.percent(0.5));
      // Not resolved yet — no reference size available.
      expect(block.requestedWidth, isNull);
    });

    test('resolveWidth updates requestedWidth from PercentDimension', () {
      final block = RenderImageBlock(
        nodeId: 'test-1',
        widthDimension: const BlockDimension.percent(0.5),
      );
      (block as BlockLayoutMixin).resolveWidth(800.0);
      expect(block.requestedWidth, closeTo(400.0, 0.001));
    });

    test('resolveHeight updates requestedHeight from PercentDimension', () {
      final block = RenderImageBlock(
        nodeId: 'test-1',
        heightDimension: const BlockDimension.percent(0.25),
      );
      (block as BlockLayoutMixin).resolveHeight(600.0);
      expect(block.requestedHeight, closeTo(150.0, 0.001));
    });

    test('widthDimension setter triggers markNeedsLayout', () {
      final block = RenderImageBlock(nodeId: 'test-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.debugNeedsLayout, false);

      (block as BlockLayoutMixin).widthDimension = const BlockDimension.pixels(200.0);
      expect(block.debugNeedsLayout, true);
    });

    test('widthDimension setter is a no-op for same value', () {
      final block = RenderImageBlock(
        nodeId: 'test-1',
        widthDimension: const BlockDimension.pixels(300.0),
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.debugNeedsLayout, false);

      (block as BlockLayoutMixin).widthDimension = const BlockDimension.pixels(300.0);
      expect(block.debugNeedsLayout, false);
    });

    test('requestedWidth setter keeps widthDimension consistent', () {
      final block = RenderImageBlock(nodeId: 'test-1');
      block.requestedWidth = 250.0;
      expect(block.requestedWidth, 250.0);
      expect(block.widthDimension, const BlockDimension.pixels(250.0));
    });

    test('requestedHeight setter keeps heightDimension consistent', () {
      final block = RenderImageBlock(nodeId: 'test-1');
      block.requestedHeight = 150.0;
      expect(block.requestedHeight, 150.0);
      expect(block.heightDimension, const BlockDimension.pixels(150.0));
    });

    test('requestedWidth setter null clears widthDimension', () {
      final block = RenderImageBlock(
        nodeId: 'test-1',
        widthDimension: const BlockDimension.pixels(300.0),
      );
      block.requestedWidth = null;
      expect(block.requestedWidth, isNull);
      expect(block.widthDimension, isNull);
    });
  });
}
