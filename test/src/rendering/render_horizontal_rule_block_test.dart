/// Tests for [RenderHorizontalRuleBlock].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RenderHorizontalRuleBlock layout', () {
    test('fills available width', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.layout(const BoxConstraints(maxWidth: 500), parentUsesSize: true);
      expect(block.size.width, 500.0);
    });

    test('height equals thickness + 2 * verticalPadding', () {
      const thickness = 2.0;
      const verticalPadding = 8.0;
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        thickness: thickness,
        verticalPadding: verticalPadding,
      );
      block.layout(const BoxConstraints(maxWidth: 500), parentUsesSize: true);
      expect(block.size.height, closeTo(thickness + 2 * verticalPadding, 0.01));
    });

    test('default thickness and verticalPadding produce positive height', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.layout(const BoxConstraints(maxWidth: 500), parentUsesSize: true);
      expect(block.size.height, greaterThan(0));
    });

    test('custom thickness changes layout height', () {
      final thin = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        thickness: 1.0,
        verticalPadding: 8.0,
      );
      thin.layout(const BoxConstraints(maxWidth: 500), parentUsesSize: true);

      final thick = RenderHorizontalRuleBlock(
        nodeId: 'hr-2',
        thickness: 4.0,
        verticalPadding: 8.0,
      );
      thick.layout(const BoxConstraints(maxWidth: 500), parentUsesSize: true);

      expect(thick.size.height, greaterThan(thin.size.height));
    });
  });

  group('RenderHorizontalRuleBlock hit testing', () {
    late RenderHorizontalRuleBlock block;

    setUp(() {
      block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
    });

    test('tap on left half returns upstream', () {
      final pos = block.getPositionAtOffset(const Offset(50, 5));
      expect(pos, isA<BinaryNodePosition>());
      expect((pos as BinaryNodePosition).type, BinaryNodePositionType.upstream);
    });

    test('tap on right half returns downstream', () {
      final pos = block.getPositionAtOffset(Offset(block.size.width - 50, 5));
      expect(pos, isA<BinaryNodePosition>());
      expect((pos as BinaryNodePosition).type, BinaryNodePositionType.downstream);
    });
  });

  group('RenderHorizontalRuleBlock position queries', () {
    late RenderHorizontalRuleBlock block;

    setUp(() {
      block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
    });

    test('getLocalRectForPosition upstream covers block', () {
      final rect = block.getLocalRectForPosition(const BinaryNodePosition.upstream());
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
    });

    test('getLocalRectForPosition downstream covers block', () {
      final rect = block.getLocalRectForPosition(const BinaryNodePosition.downstream());
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
    });

    test('getEndpointsForSelection returns one rect for the full block', () {
      final rects = block.getEndpointsForSelection(
        const BinaryNodePosition.upstream(),
        const BinaryNodePosition.downstream(),
      );
      expect(rects, hasLength(1));
      expect(rects.first, equals(Offset.zero & block.size));
    });
  });

  group('RenderHorizontalRuleBlock properties', () {
    test('nodeId is readable and writable', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.nodeId, 'hr-1');
      block.nodeId = 'hr-2';
      expect(block.nodeId, 'hr-2');
    });

    test('color can be set', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        color: const Color(0xFF888888),
      );
      expect(block.color, const Color(0xFF888888));
    });

    test('setting thickness triggers layout', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        thickness: 1.0,
        verticalPadding: 8.0,
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      final before = block.size.height;

      block.thickness = 6.0;
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.size.height, greaterThan(before));
    });
  });

  group('RenderHorizontalRuleBlock layout property defaults and setter', () {
    test('blockAlignment defaults to BlockAlignment.stretch', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.blockAlignment, BlockAlignment.stretch);
    });

    test('requestedWidth defaults to null (base class default)', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.requestedWidth, isNull);
    });

    test('requestedHeight defaults to null (base class default)', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.requestedHeight, isNull);
    });

    test('textWrap defaults to TextWrapMode.none (base class default)', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.textWrap, TextWrapMode.none);
    });

    test('blockAlignment setter roundtrip', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.blockAlignment = BlockAlignment.center;
      expect(block.blockAlignment, BlockAlignment.center);
    });

    test('setting blockAlignment to same value is a no-op', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.blockAlignment = BlockAlignment.stretch;
      expect(block.blockAlignment, BlockAlignment.stretch);
    });

    test('constructor accepts blockAlignment parameter', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        blockAlignment: BlockAlignment.end,
      );
      expect(block.blockAlignment, BlockAlignment.end);
    });

    test('setting blockAlignment triggers layout', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      // Change to a different value — should not throw.
      block.blockAlignment = BlockAlignment.center;
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.blockAlignment, BlockAlignment.center);
    });
  });

  group('RenderHorizontalRuleBlock sizing properties', () {
    test('requestedWidth overrides width in layout', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        requestedWidth: 200,
      );
      block.layout(const BoxConstraints(maxWidth: 500), parentUsesSize: true);
      expect(block.size.width, 200.0);
    });

    test('requestedHeight overrides height in layout', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        requestedHeight: 50,
      );
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      expect(block.size.height, 50.0);
    });

    test('both requestedWidth and requestedHeight are used together', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        requestedWidth: 300,
        requestedHeight: 40,
      );
      block.layout(const BoxConstraints(maxWidth: 600), parentUsesSize: true);
      expect(block.size.width, 300.0);
      expect(block.size.height, 40.0);
    });

    test('requestedWidth setter roundtrip', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.requestedWidth = 250.0;
      expect(block.requestedWidth, 250.0);
    });

    test('requestedHeight setter roundtrip', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.requestedHeight = 60.0;
      expect(block.requestedHeight, 60.0);
    });

    test('textWrap setter roundtrip', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.textWrap, TextWrapMode.none);
      block.textWrap = TextWrapMode.wrap;
      expect(block.textWrap, TextWrapMode.wrap);
    });

    test('constructor accepts requestedWidth, requestedHeight, and textWrap', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        requestedWidth: 180.0,
        requestedHeight: 24.0,
        textWrap: TextWrapMode.wrap,
      );
      expect(block.requestedWidth, 180.0);
      expect(block.requestedHeight, 24.0);
      expect(block.textWrap, TextWrapMode.wrap);
    });

    test('null requestedWidth falls back to constraints.maxWidth', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.layout(const BoxConstraints(maxWidth: 500), parentUsesSize: true);
      expect(block.size.width, 500.0);
    });
  });

  group('RenderHorizontalRuleBlock clearsFloat', () {
    test('clearsFloat returns true when requestedWidth is null', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.clearsFloat, isTrue);
    });

    test('clearsFloat returns false when requestedWidth is set', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-1',
        requestedWidth: 200.0,
      );
      expect(block.clearsFloat, isFalse);
    });

    test('clearsFloat updates when requestedWidth is assigned', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.clearsFloat, isTrue);
      block.requestedWidth = 300.0;
      expect(block.clearsFloat, isFalse);
      block.requestedWidth = null;
      expect(block.clearsFloat, isTrue);
    });
  });

  group('RenderHorizontalRuleBlock border property', () {
    test('border is null by default', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      expect(block.border, isNull);
    });

    test('border returns value set via setter', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      const border = BlockBorder(style: BlockBorderStyle.solid, width: 2.0);
      block.border = border;
      expect(block.border, equals(border));
    });

    test('setting border to same value is a no-op', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      const border = BlockBorder(style: BlockBorderStyle.dotted, width: 1.0);
      block.border = border;
      block.border = border;
      expect(block.border, equals(border));
    });

    test('setting border to null clears the value', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      block.border = const BlockBorder();
      block.border = null;
      expect(block.border, isNull);
    });
  });
}
