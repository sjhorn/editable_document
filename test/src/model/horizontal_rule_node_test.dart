/// Tests for [HorizontalRuleNode] — width, height, textWrap, spaceBefore,
/// and spaceAfter fields.
library;

import 'package:editable_document/src/model/block_alignment.dart';
import 'package:editable_document/src/model/block_border.dart';
import 'package:editable_document/src/model/horizontal_rule_node.dart';
import 'package:editable_document/src/model/text_wrap_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HorizontalRuleNode', () {
    // -------------------------------------------------------------------------
    // Default construction
    // -------------------------------------------------------------------------

    test('default construction has null width and height and textWrap TextWrapMode.none', () {
      final node = HorizontalRuleNode(id: 'hr-1');

      expect(node.width, isNull);
      expect(node.height, isNull);
      expect(node.textWrap, TextWrapMode.none);
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
        textWrap: TextWrapMode.wrap,
        alignment: BlockAlignment.center,
      );

      expect(node.width, 400.0);
      expect(node.height, 2.0);
      expect(node.textWrap, TextWrapMode.wrap);
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
        textWrap: TextWrapMode.wrap,
        alignment: BlockAlignment.end,
      );

      final copy = original.copyWith(id: 'hr-3-copy');

      expect(copy.id, 'hr-3-copy');
      expect(copy.width, 300.0);
      expect(copy.height, 4.0);
      expect(copy.textWrap, TextWrapMode.wrap);
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
      final original = HorizontalRuleNode(id: 'hr-6', textWrap: TextWrapMode.none);
      final copy = original.copyWith(textWrap: TextWrapMode.wrap);

      expect(copy.textWrap, TextWrapMode.wrap);
    });

    // -------------------------------------------------------------------------
    // Equality — two identical nodes are equal
    // -------------------------------------------------------------------------

    test('two nodes with identical fields are equal', () {
      final a = HorizontalRuleNode(
        id: 'hr-7',
        width: 250.0,
        height: 3.0,
        textWrap: TextWrapMode.wrap,
        alignment: BlockAlignment.center,
      );
      final b = HorizontalRuleNode(
        id: 'hr-7',
        width: 250.0,
        height: 3.0,
        textWrap: TextWrapMode.wrap,
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
      final a = HorizontalRuleNode(id: 'hr-10', textWrap: TextWrapMode.none);
      final b = HorizontalRuleNode(id: 'hr-10', textWrap: TextWrapMode.wrap);

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
      final a = HorizontalRuleNode(
        id: 'hr-13',
        width: 50.0,
        height: 2.0,
        textWrap: TextWrapMode.wrap,
      );
      final b = HorizontalRuleNode(
        id: 'hr-13',
        width: 50.0,
        height: 2.0,
        textWrap: TextWrapMode.wrap,
      );

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
        textWrap: TextWrapMode.wrap,
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
        textWrap: TextWrapMode.wrap,
      );

      final s = node.toString();
      expect(s, contains('width: 128.0'));
      expect(s, contains('height: 1.0'));
      expect(s, contains('textWrap: TextWrapMode.wrap'));
    });

    // -------------------------------------------------------------------------
    // spaceBefore — default value
    // -------------------------------------------------------------------------

    test('spaceBefore defaults to null', () {
      final node = HorizontalRuleNode(id: 'hr-16');
      expect(node.spaceBefore, isNull);
    });

    // -------------------------------------------------------------------------
    // spaceAfter — default value
    // -------------------------------------------------------------------------

    test('spaceAfter defaults to null', () {
      final node = HorizontalRuleNode(id: 'hr-17');
      expect(node.spaceAfter, isNull);
    });

    // -------------------------------------------------------------------------
    // spaceBefore/spaceAfter — constructor
    // -------------------------------------------------------------------------

    test('constructor stores spaceBefore', () {
      final node = HorizontalRuleNode(id: 'hr-18', spaceBefore: 8.0);
      expect(node.spaceBefore, 8.0);
    });

    test('constructor stores spaceAfter', () {
      final node = HorizontalRuleNode(id: 'hr-19', spaceAfter: 16.0);
      expect(node.spaceAfter, 16.0);
    });

    // -------------------------------------------------------------------------
    // spaceBefore/spaceAfter — copyWith
    // -------------------------------------------------------------------------

    test('copyWith preserves spaceBefore when not overridden', () {
      final original = HorizontalRuleNode(id: 'hr-20', spaceBefore: 8.0);
      final copy = original.copyWith(id: 'hr-20-copy');
      expect(copy.spaceBefore, 8.0);
    });

    test('copyWith preserves spaceAfter when not overridden', () {
      final original = HorizontalRuleNode(id: 'hr-21', spaceAfter: 16.0);
      final copy = original.copyWith(id: 'hr-21-copy');
      expect(copy.spaceAfter, 16.0);
    });

    test('copyWith replaces spaceBefore', () {
      final original = HorizontalRuleNode(id: 'hr-22', spaceBefore: 8.0);
      final copy = original.copyWith(spaceBefore: 24.0);
      expect(copy.spaceBefore, 24.0);
    });

    test('copyWith replaces spaceAfter', () {
      final original = HorizontalRuleNode(id: 'hr-23', spaceAfter: 16.0);
      final copy = original.copyWith(spaceAfter: 32.0);
      expect(copy.spaceAfter, 32.0);
    });

    // -------------------------------------------------------------------------
    // spaceBefore/spaceAfter — equality
    // -------------------------------------------------------------------------

    test('nodes with different spaceBefore are not equal', () {
      final a = HorizontalRuleNode(id: 'hr-24', spaceBefore: 8.0);
      final b = HorizontalRuleNode(id: 'hr-24', spaceBefore: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('nodes with different spaceAfter are not equal', () {
      final a = HorizontalRuleNode(id: 'hr-25', spaceAfter: 8.0);
      final b = HorizontalRuleNode(id: 'hr-25', spaceAfter: 16.0);
      expect(a, isNot(equals(b)));
    });

    // -------------------------------------------------------------------------
    // debugFillProperties — includes spaceBefore/spaceAfter
    // -------------------------------------------------------------------------

    test('debugFillProperties includes spaceBefore when non-null', () {
      final node = HorizontalRuleNode(id: 'hr-26', spaceBefore: 8.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'spaceBefore',
            orElse: () => throw StateError('spaceBefore property not found'),
          );
      expect(prop.value, 8.0);
    });

    test('debugFillProperties includes spaceAfter when non-null', () {
      final node = HorizontalRuleNode(id: 'hr-27', spaceAfter: 16.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'spaceAfter',
            orElse: () => throw StateError('spaceAfter property not found'),
          );
      expect(prop.value, 16.0);
    });
  });

  // -------------------------------------------------------------------------
  // border — default and construction
  // -------------------------------------------------------------------------

  group('HorizontalRuleNode border', () {
    test('border defaults to null', () {
      final node = HorizontalRuleNode(id: 'hr-28');
      expect(node.border, isNull);
    });

    test('constructor stores border', () {
      const border = BlockBorder(style: BlockBorderStyle.solid, width: 2.0);
      final node = HorizontalRuleNode(id: 'hr-29', border: border);
      expect(node.border, border);
    });

    test('copyWith preserves border when not overridden', () {
      const border = BlockBorder(style: BlockBorderStyle.dashed, width: 1.5);
      final original = HorizontalRuleNode(id: 'hr-30', border: border);
      final copy = original.copyWith(id: 'hr-30-copy');
      expect(copy.border, border);
    });

    test('copyWith replaces border', () {
      const original = BlockBorder(style: BlockBorderStyle.solid, width: 1.0);
      const replacement = BlockBorder(style: BlockBorderStyle.dotted, width: 3.0);
      final node = HorizontalRuleNode(id: 'hr-31', border: original);
      final copy = node.copyWith(border: replacement);
      expect(copy.border, replacement);
    });

    test('nodes with different border are not equal', () {
      final a = HorizontalRuleNode(id: 'hr-32', border: const BlockBorder(width: 1.0));
      final b = HorizontalRuleNode(id: 'hr-32', border: const BlockBorder(width: 2.0));
      expect(a, isNot(equals(b)));
    });

    test('unequal when one border is null and other is not', () {
      final a = HorizontalRuleNode(id: 'hr-33');
      final b = HorizontalRuleNode(id: 'hr-33', border: const BlockBorder());
      expect(a, isNot(equals(b)));
    });
  });
}
