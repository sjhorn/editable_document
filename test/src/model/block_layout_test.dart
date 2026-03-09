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
      expect(layout.textWrap, false);
      expect(layout.width, isNull);
      expect(layout.height, isNull);
    });

    test('CodeBlockNode implements HasBlockLayout', () {
      final node = CodeBlockNode(id: '2');
      expect(node, isA<HasBlockLayout>());
      final layout = node as HasBlockLayout;
      expect(layout.alignment, BlockAlignment.stretch);
      expect(layout.textWrap, false);
      expect(layout.width, isNull);
      expect(layout.height, isNull);
    });

    test('BlockquoteNode implements HasBlockLayout', () {
      final node = BlockquoteNode(id: '3');
      expect(node, isA<HasBlockLayout>());
      final layout = node as HasBlockLayout;
      expect(layout.alignment, BlockAlignment.stretch);
      expect(layout.textWrap, false);
      expect(layout.width, isNull);
      expect(layout.height, isNull);
    });

    test('HorizontalRuleNode implements HasBlockLayout', () {
      final node = HorizontalRuleNode(id: '4');
      expect(node, isA<HasBlockLayout>());
      final layout = node as HasBlockLayout;
      expect(layout.alignment, BlockAlignment.stretch);
      expect(layout.textWrap, false);
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
        textWrap: true,
      );
      final layout = node as HasBlockLayout;
      expect(layout.width, 200.0);
      expect(layout.height, 100.0);
      expect(layout.alignment, BlockAlignment.center);
      expect(layout.textWrap, true);
    });
  });
}
