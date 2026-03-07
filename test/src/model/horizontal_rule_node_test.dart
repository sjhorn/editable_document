/// Tests for [HorizontalRuleNode] — width, height, and textWrap fields.
library;

import 'package:editable_document/src/model/block_alignment.dart';
import 'package:editable_document/src/model/horizontal_rule_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HorizontalRuleNode', () {
    // -------------------------------------------------------------------------
    // Default construction
    // -------------------------------------------------------------------------

    test('default construction has null width and height and textWrap false', () {
      final node = HorizontalRuleNode(id: 'hr-1');

      expect(node.width, isNull);
      expect(node.height, isNull);
      expect(node.textWrap, isFalse);
      expect(node.alignment, BlockAlignment.stretch);
    });

    // -------------------------------------------------------------------------
    // Constructor with explicit values
    // -------------------------------------------------------------------------

    test('constructor stores explicit width, height, and textWrap', () {
      final node = HorizontalRuleNode(
        id: 'hr-2',
        width: 400.0,
        height: 2.0,
        textWrap: true,
        alignment: BlockAlignment.center,
      );

      expect(node.width, 400.0);
      expect(node.height, 2.0);
      expect(node.textWrap, isTrue);
      expect(node.alignment, BlockAlignment.center);
    });

    // -------------------------------------------------------------------------
    // copyWith — preserves existing values when not overridden
    // -------------------------------------------------------------------------

    test('copyWith preserves width, height, and textWrap when not overridden', () {
      final original = HorizontalRuleNode(
        id: 'hr-3',
        width: 300.0,
        height: 4.0,
        textWrap: true,
        alignment: BlockAlignment.end,
      );

      final copy = original.copyWith(id: 'hr-3-copy');

      expect(copy.id, 'hr-3-copy');
      expect(copy.width, 300.0);
      expect(copy.height, 4.0);
      expect(copy.textWrap, isTrue);
      expect(copy.alignment, BlockAlignment.end);
    });

    // -------------------------------------------------------------------------
    // copyWith — overrides individual fields
    // -------------------------------------------------------------------------

    test('copyWith overrides width independently', () {
      final original = HorizontalRuleNode(id: 'hr-4', width: 100.0, height: 2.0);
      final copy = original.copyWith(width: 200.0);

      expect(copy.width, 200.0);
      expect(copy.height, 2.0);
    });

    test('copyWith overrides height independently', () {
      final original = HorizontalRuleNode(id: 'hr-5', width: 100.0, height: 2.0);
      final copy = original.copyWith(height: 8.0);

      expect(copy.width, 100.0);
      expect(copy.height, 8.0);
    });

    test('copyWith overrides textWrap independently', () {
      final original = HorizontalRuleNode(id: 'hr-6', textWrap: false);
      final copy = original.copyWith(textWrap: true);

      expect(copy.textWrap, isTrue);
    });

    // -------------------------------------------------------------------------
    // Equality — two identical nodes are equal
    // -------------------------------------------------------------------------

    test('two nodes with identical fields are equal', () {
      final a = HorizontalRuleNode(
        id: 'hr-7',
        width: 250.0,
        height: 3.0,
        textWrap: true,
        alignment: BlockAlignment.center,
      );
      final b = HorizontalRuleNode(
        id: 'hr-7',
        width: 250.0,
        height: 3.0,
        textWrap: true,
        alignment: BlockAlignment.center,
      );

      expect(a, equals(b));
    });

    // -------------------------------------------------------------------------
    // Equality — different fields are not equal
    // -------------------------------------------------------------------------

    test('nodes with different width are not equal', () {
      final a = HorizontalRuleNode(id: 'hr-8', width: 100.0);
      final b = HorizontalRuleNode(id: 'hr-8', width: 200.0);

      expect(a, isNot(equals(b)));
    });

    test('nodes with different height are not equal', () {
      final a = HorizontalRuleNode(id: 'hr-9', height: 1.0);
      final b = HorizontalRuleNode(id: 'hr-9', height: 5.0);

      expect(a, isNot(equals(b)));
    });

    test('nodes with different textWrap are not equal', () {
      final a = HorizontalRuleNode(id: 'hr-10', textWrap: false);
      final b = HorizontalRuleNode(id: 'hr-10', textWrap: true);

      expect(a, isNot(equals(b)));
    });

    test('node with null width differs from node with explicit width', () {
      final a = HorizontalRuleNode(id: 'hr-11');
      final b = HorizontalRuleNode(id: 'hr-11', width: 0.0);

      expect(a, isNot(equals(b)));
    });

    // -------------------------------------------------------------------------
    // hashCode — differs for different width values
    // -------------------------------------------------------------------------

    test('hashCode differs for different width values', () {
      final a = HorizontalRuleNode(id: 'hr-12', width: 100.0);
      final b = HorizontalRuleNode(id: 'hr-12', width: 999.0);

      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('hashCode is equal for identical nodes', () {
      final a = HorizontalRuleNode(id: 'hr-13', width: 50.0, height: 2.0, textWrap: true);
      final b = HorizontalRuleNode(id: 'hr-13', width: 50.0, height: 2.0, textWrap: true);

      expect(a.hashCode, equals(b.hashCode));
    });

    // -------------------------------------------------------------------------
    // debugFillProperties — new properties are present
    // -------------------------------------------------------------------------

    test('debugFillProperties includes width, height, and textWrap', () {
      final node = HorizontalRuleNode(
        id: 'hr-14',
        width: 320.0,
        height: 4.0,
        textWrap: true,
      );

      final description = node.toDiagnosticsNode().toStringDeep();
      expect(description, contains('width'));
      expect(description, contains('height'));
      expect(description, contains('textWrap'));
    });

    // -------------------------------------------------------------------------
    // toString
    // -------------------------------------------------------------------------

    test('toString includes width, height, and textWrap', () {
      final node = HorizontalRuleNode(
        id: 'hr-15',
        width: 128.0,
        height: 1.0,
        textWrap: true,
      );

      final s = node.toString();
      expect(s, contains('width: 128.0'));
      expect(s, contains('height: 1.0'));
      expect(s, contains('textWrap: true'));
    });
  });
}
