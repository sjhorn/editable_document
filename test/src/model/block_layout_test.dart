/// Tests for the [HasBlockLayout] interface.
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HasBlockLayout', () {
    test('ImageNode implements HasBlockLayout', () {
      final node = ImageNode(id: '1', imageUrl: 'https://example.com/a.png');
      expect(node, isA<HasBlockLayout>());
      final layout = node as HasBlockLayout;
      expect(layout.alignment, BlockAlignment.stretch);
      expect(layout.textWrap, TextWrapMode.none);
      expect(layout.width, isNull);
      expect(layout.height, isNull);
    });

    test('CodeBlockNode implements HasBlockLayout', () {
      final node = CodeBlockNode(id: '2');
      expect(node, isA<HasBlockLayout>());
      final layout = node as HasBlockLayout;
      expect(layout.alignment, BlockAlignment.stretch);
      expect(layout.textWrap, TextWrapMode.none);
      expect(layout.width, isNull);
      expect(layout.height, isNull);
    });

    test('BlockquoteNode implements HasBlockLayout', () {
      final node = BlockquoteNode(id: '3');
      expect(node, isA<HasBlockLayout>());
      final layout = node as HasBlockLayout;
      expect(layout.alignment, BlockAlignment.stretch);
      expect(layout.textWrap, TextWrapMode.none);
      expect(layout.width, isNull);
      expect(layout.height, isNull);
    });

    test('HorizontalRuleNode implements HasBlockLayout', () {
      final node = HorizontalRuleNode(id: '4');
      expect(node, isA<HasBlockLayout>());
      final layout = node as HasBlockLayout;
      expect(layout.alignment, BlockAlignment.stretch);
      expect(layout.textWrap, TextWrapMode.none);
      expect(layout.width, isNull);
      expect(layout.height, isNull);
    });

    test('ParagraphNode does not implement HasBlockLayout', () {
      final node = ParagraphNode(id: '5');
      expect(node, isNot(isA<HasBlockLayout>()));
    });

    test('ListItemNode does not implement HasBlockLayout', () {
      final node = ListItemNode(id: '6');
      expect(node, isNot(isA<HasBlockLayout>()));
    });

    test('custom values are accessible through the interface', () {
      final node = ImageNode(
        id: '7',
        imageUrl: 'https://example.com/b.png',
        width: 200.0,
        height: 100.0,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final layout = node as HasBlockLayout;
      expect(layout.width, 200.0);
      expect(layout.height, 100.0);
      expect(layout.alignment, BlockAlignment.center);
      expect(layout.textWrap, TextWrapMode.wrap);
    });
  });

  // ===========================================================================
  // isDraggable
  // ===========================================================================

  group('isDraggable', () {
    test('ImageNode isDraggable is true', () {
      final node = ImageNode(id: '1', imageUrl: 'https://example.com/a.png');
      expect((node as HasBlockLayout).isDraggable, isTrue);
    });

    test('CodeBlockNode isDraggable is true', () {
      final node = CodeBlockNode(id: '2');
      expect((node as HasBlockLayout).isDraggable, isTrue);
    });

    test('BlockquoteNode isDraggable is true', () {
      final node = BlockquoteNode(id: '3');
      expect((node as HasBlockLayout).isDraggable, isTrue);
    });

    test('HorizontalRuleNode isDraggable is true', () {
      final node = HorizontalRuleNode(id: '4');
      expect((node as HasBlockLayout).isDraggable, isTrue);
    });

    test('TableNode isDraggable is true', () {
      final node = TableNode(
        id: '5',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('cell')],
        ],
      );
      expect((node as HasBlockLayout).isDraggable, isTrue);
    });
  });

  // ===========================================================================
  // isResizable
  // ===========================================================================

  group('isResizable', () {
    test('ImageNode isResizable true when alignment != stretch', () {
      final node = ImageNode(
        id: '1',
        imageUrl: 'https://example.com/a.png',
        alignment: BlockAlignment.center,
      );
      expect((node as HasBlockLayout).isResizable, isTrue);
    });

    test('ImageNode isResizable false when alignment == stretch', () {
      final node = ImageNode(
        id: '1',
        imageUrl: 'https://example.com/a.png',
        alignment: BlockAlignment.stretch,
      );
      expect((node as HasBlockLayout).isResizable, isFalse);
    });

    test('CodeBlockNode isResizable true when alignment != stretch', () {
      final node = CodeBlockNode(id: '2', alignment: BlockAlignment.center);
      expect((node as HasBlockLayout).isResizable, isTrue);
    });

    test('CodeBlockNode isResizable false when alignment == stretch', () {
      final node = CodeBlockNode(id: '2', alignment: BlockAlignment.stretch);
      expect((node as HasBlockLayout).isResizable, isFalse);
    });

    test('BlockquoteNode isResizable true when alignment != stretch', () {
      final node = BlockquoteNode(id: '3', alignment: BlockAlignment.center);
      expect((node as HasBlockLayout).isResizable, isTrue);
    });

    test('HorizontalRuleNode isResizable false when alignment == stretch', () {
      final node = HorizontalRuleNode(id: '4', alignment: BlockAlignment.stretch);
      expect((node as HasBlockLayout).isResizable, isFalse);
    });

    test('TableNode isResizable true when alignment != stretch', () {
      final node = TableNode(
        id: '5',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('cell')],
        ],
        alignment: BlockAlignment.start,
      );
      expect((node as HasBlockLayout).isResizable, isTrue);
    });

    test('TableNode isResizable false when alignment == stretch', () {
      final node = TableNode(
        id: '5',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('cell')],
        ],
        alignment: BlockAlignment.stretch,
      );
      expect((node as HasBlockLayout).isResizable, isFalse);
    });
  });

  // ===========================================================================
  // copyWithSize
  // ===========================================================================

  group('copyWithSize', () {
    test('ImageNode copyWithSize updates width and height', () {
      final node = ImageNode(
        id: '1',
        imageUrl: 'https://example.com/a.png',
        alignment: BlockAlignment.center,
      );
      final layout = node as HasBlockLayout;
      final copy = layout.copyWithSize(width: 320.0, height: 240.0) as ImageNode;
      expect(copy.width, 320.0);
      expect(copy.height, 240.0);
      expect(copy.id, '1');
      expect(copy.imageUrl, 'https://example.com/a.png');
      expect(copy.alignment, BlockAlignment.center);
    });

    test('ImageNode copyWithSize preserves existing width when only height given', () {
      final node = ImageNode(
        id: '1',
        imageUrl: 'https://example.com/a.png',
        width: 100.0,
        alignment: BlockAlignment.center,
      );
      final copy = (node as HasBlockLayout).copyWithSize(height: 50.0) as ImageNode;
      expect(copy.width, 100.0);
      expect(copy.height, 50.0);
    });

    test('CodeBlockNode copyWithSize updates width and height', () {
      final node = CodeBlockNode(id: '2', alignment: BlockAlignment.center);
      final copy =
          (node as HasBlockLayout).copyWithSize(width: 640.0, height: 480.0) as CodeBlockNode;
      expect(copy.width, 640.0);
      expect(copy.height, 480.0);
      expect(copy.id, '2');
    });

    test('BlockquoteNode copyWithSize updates width and height', () {
      final node = BlockquoteNode(id: '3', alignment: BlockAlignment.center);
      final copy =
          (node as HasBlockLayout).copyWithSize(width: 400.0, height: 200.0) as BlockquoteNode;
      expect(copy.width, 400.0);
      expect(copy.height, 200.0);
    });

    test('HorizontalRuleNode copyWithSize updates width and height', () {
      final node = HorizontalRuleNode(id: '4', alignment: BlockAlignment.center);
      final copy =
          (node as HasBlockLayout).copyWithSize(width: 300.0, height: 2.0) as HorizontalRuleNode;
      expect(copy.width, 300.0);
      expect(copy.height, 2.0);
    });

    test('TableNode copyWithSize updates width and height', () {
      final node = TableNode(
        id: '5',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('cell')],
        ],
        alignment: BlockAlignment.center,
      );
      final copy = (node as HasBlockLayout).copyWithSize(width: 500.0, height: 300.0) as TableNode;
      expect(copy.width, 500.0);
      expect(copy.height, 300.0);
      expect(copy.id, '5');
      expect(copy.rowCount, 1);
    });

    test('copyWithSize with no args preserves current width and height', () {
      final node = ImageNode(
        id: '1',
        imageUrl: 'https://example.com/a.png',
        width: 100.0,
        height: 50.0,
        alignment: BlockAlignment.center,
      );
      final copy = (node as HasBlockLayout).copyWithSize() as ImageNode;
      expect(copy.width, 100.0);
      expect(copy.height, 50.0);
    });

    test('ImageNode copyWithSize with alignment changes the alignment on the copy', () {
      final node = ImageNode(
        id: '1',
        imageUrl: 'https://example.com/a.png',
        alignment: BlockAlignment.stretch,
      );
      final copy =
          (node as HasBlockLayout).copyWithSize(alignment: BlockAlignment.center) as ImageNode;
      expect(copy.alignment, BlockAlignment.center);
      expect(copy.id, '1');
      expect(copy.imageUrl, 'https://example.com/a.png');
    });

    test('CodeBlockNode copyWithSize with alignment changes the alignment on the copy', () {
      final node = CodeBlockNode(id: '2', alignment: BlockAlignment.stretch);
      final copy =
          (node as HasBlockLayout).copyWithSize(alignment: BlockAlignment.end) as CodeBlockNode;
      expect(copy.alignment, BlockAlignment.end);
      expect(copy.id, '2');
    });

    test('BlockquoteNode copyWithSize with alignment changes the alignment on the copy', () {
      final node = BlockquoteNode(id: '3', alignment: BlockAlignment.center);
      final copy =
          (node as HasBlockLayout).copyWithSize(alignment: BlockAlignment.start) as BlockquoteNode;
      expect(copy.alignment, BlockAlignment.start);
    });

    test('HorizontalRuleNode copyWithSize with alignment changes the alignment on the copy', () {
      final node = HorizontalRuleNode(id: '4', alignment: BlockAlignment.center);
      final copy = (node as HasBlockLayout).copyWithSize(alignment: BlockAlignment.end)
          as HorizontalRuleNode;
      expect(copy.alignment, BlockAlignment.end);
    });

    test('TableNode copyWithSize with alignment changes the alignment on the copy', () {
      final node = TableNode(
        id: '5',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('cell')],
        ],
        alignment: BlockAlignment.stretch,
      );
      final copy =
          (node as HasBlockLayout).copyWithSize(alignment: BlockAlignment.center) as TableNode;
      expect(copy.alignment, BlockAlignment.center);
      expect(copy.id, '5');
    });

    test('copyWithSize null alignment preserves the current alignment', () {
      final node = ImageNode(
        id: '1',
        imageUrl: 'https://example.com/a.png',
        alignment: BlockAlignment.end,
      );
      final copy = (node as HasBlockLayout).copyWithSize(width: 200.0) as ImageNode;
      expect(copy.alignment, BlockAlignment.end);
      expect(copy.width, 200.0);
    });
  });
}
