/// Tests for [BlockBorderStyle] and [BlockBorder].
library;

import 'dart:ui' show Color;

import 'package:editable_document/src/model/block_border.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // BlockBorderStyle — enum values
  // ---------------------------------------------------------------------------
  group('BlockBorderStyle enum', () {
    test('has exactly four values', () {
      expect(BlockBorderStyle.values, hasLength(4));
    });

    test('values list is in the correct order', () {
      expect(BlockBorderStyle.values, [
        BlockBorderStyle.none,
        BlockBorderStyle.solid,
        BlockBorderStyle.dotted,
        BlockBorderStyle.dashed,
      ]);
    });

    test('none value exists with correct name', () {
      expect(BlockBorderStyle.none.name, 'none');
    });

    test('solid value exists with correct name', () {
      expect(BlockBorderStyle.solid.name, 'solid');
    });

    test('dotted value exists with correct name', () {
      expect(BlockBorderStyle.dotted.name, 'dotted');
    });

    test('dashed value exists with correct name', () {
      expect(BlockBorderStyle.dashed.name, 'dashed');
    });

    test('values are distinct', () {
      final values = BlockBorderStyle.values;
      final unique = values.toSet();
      expect(unique, hasLength(values.length));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockBorder — default values
  // ---------------------------------------------------------------------------
  group('BlockBorder defaults', () {
    test('style defaults to BlockBorderStyle.solid', () {
      const border = BlockBorder();
      expect(border.style, BlockBorderStyle.solid);
    });

    test('width defaults to 1.0', () {
      const border = BlockBorder();
      expect(border.width, 1.0);
    });

    test('color defaults to null', () {
      const border = BlockBorder();
      expect(border.color, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockBorder — constructor with custom values
  // ---------------------------------------------------------------------------
  group('BlockBorder constructor', () {
    test('style is set correctly', () {
      const border = BlockBorder(style: BlockBorderStyle.dashed);
      expect(border.style, BlockBorderStyle.dashed);
    });

    test('width is set correctly', () {
      const border = BlockBorder(width: 3.0);
      expect(border.width, 3.0);
    });

    test('color is set correctly', () {
      const color = Color(0xFFFF0000);
      const border = BlockBorder(color: color);
      expect(border.color, color);
    });

    test('all fields set together', () {
      const color = Color(0xFF0000FF);
      const border = BlockBorder(
        style: BlockBorderStyle.dotted,
        width: 2.5,
        color: color,
      );
      expect(border.style, BlockBorderStyle.dotted);
      expect(border.width, 2.5);
      expect(border.color, color);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockBorder — equality
  // ---------------------------------------------------------------------------
  group('BlockBorder equality', () {
    test('two borders with identical fields are equal', () {
      const a = BlockBorder(style: BlockBorderStyle.solid, width: 2.0);
      const b = BlockBorder(style: BlockBorderStyle.solid, width: 2.0);
      expect(a, equals(b));
    });

    test('default borders are equal', () {
      const a = BlockBorder();
      const b = BlockBorder();
      expect(a, equals(b));
    });

    test('unequal when style differs', () {
      const a = BlockBorder(style: BlockBorderStyle.solid);
      const b = BlockBorder(style: BlockBorderStyle.dashed);
      expect(a, isNot(equals(b)));
    });

    test('unequal when width differs', () {
      const a = BlockBorder(width: 1.0);
      const b = BlockBorder(width: 2.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when color differs', () {
      const a = BlockBorder(color: Color(0xFFFF0000));
      const b = BlockBorder(color: Color(0xFF0000FF));
      expect(a, isNot(equals(b)));
    });

    test('unequal when one color is null and other is not', () {
      const a = BlockBorder();
      const b = BlockBorder(color: Color(0xFF000000));
      expect(a, isNot(equals(b)));
    });

    test('identical instance equals itself', () {
      const border = BlockBorder(style: BlockBorderStyle.dotted, width: 3.0);
      expect(border, equals(border));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockBorder — hashCode
  // ---------------------------------------------------------------------------
  group('BlockBorder hashCode', () {
    test('hashCode matches for equal borders', () {
      const a = BlockBorder(style: BlockBorderStyle.dashed, width: 2.0);
      const b = BlockBorder(style: BlockBorderStyle.dashed, width: 2.0);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode is consistent on same instance', () {
      const border = BlockBorder(style: BlockBorderStyle.solid, width: 1.5);
      expect(border.hashCode, border.hashCode);
    });

    test('hashCode differs when style differs', () {
      const a = BlockBorder(style: BlockBorderStyle.solid);
      const b = BlockBorder(style: BlockBorderStyle.dotted);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('hashCode differs when width differs', () {
      const a = BlockBorder(width: 1.0);
      const b = BlockBorder(width: 4.0);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockBorder — toString
  // ---------------------------------------------------------------------------
  group('BlockBorder toString', () {
    test('toString includes style', () {
      const border = BlockBorder(style: BlockBorderStyle.dashed);
      expect(border.toString(), contains('dashed'));
    });

    test('toString includes width', () {
      const border = BlockBorder(width: 3.0);
      expect(border.toString(), contains('3.0'));
    });

    test('toString includes color when set', () {
      const color = Color(0xFFABCDEF);
      const border = BlockBorder(color: color);
      expect(border.toString(), contains('color'));
    });

    test('toString mentions BlockBorder type', () {
      const border = BlockBorder();
      expect(border.toString(), contains('BlockBorder'));
    });
  });
}
