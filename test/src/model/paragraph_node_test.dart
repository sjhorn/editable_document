/// Tests for [ParagraphNode] — focusing on [textAlign], [lineHeight],
/// [spaceBefore], and [spaceAfter] fields.
///
/// These tests cover the [textAlign], [lineHeight], [spaceBefore], and
/// [spaceAfter] constructor parameters, [copyWith], equality, hashCode, and
/// [debugFillProperties]/toString integration.
library;

import 'dart:ui' show TextAlign;

import 'package:editable_document/src/model/block_border.dart';
import 'package:editable_document/src/model/paragraph_node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ParagraphNode — textAlign default value
  // ---------------------------------------------------------------------------
  group('ParagraphNode textAlign default', () {
    test('textAlign defaults to TextAlign.start', () {
      final node = ParagraphNode(id: 'p1');
      expect(node.textAlign, TextAlign.start);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — constructor with textAlign
  // ---------------------------------------------------------------------------
  group('ParagraphNode constructor with textAlign', () {
    test('textAlign is set correctly to center', () {
      final node = ParagraphNode(id: 'p1', textAlign: TextAlign.center);
      expect(node.textAlign, TextAlign.center);
    });

    test('textAlign is set correctly to end', () {
      final node = ParagraphNode(id: 'p1', textAlign: TextAlign.end);
      expect(node.textAlign, TextAlign.end);
    });

    test('textAlign is set correctly to justify', () {
      final node = ParagraphNode(id: 'p1', textAlign: TextAlign.justify);
      expect(node.textAlign, TextAlign.justify);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — copyWith with textAlign
  // ---------------------------------------------------------------------------
  group('ParagraphNode copyWith textAlign', () {
    test('copyWith replaces textAlign', () {
      final node = ParagraphNode(id: 'p1', textAlign: TextAlign.start);
      final copy = node.copyWith(textAlign: TextAlign.center);
      expect(copy.textAlign, TextAlign.center);
    });

    test('copyWith preserves textAlign when not specified', () {
      final node = ParagraphNode(id: 'p1', textAlign: TextAlign.end);
      final copy = node.copyWith(id: 'p2');
      expect(copy.textAlign, TextAlign.end);
    });

    test('copyWith preserves other fields when only textAlign changes', () {
      final node = ParagraphNode(
        id: 'p1',
        textAlign: TextAlign.start,
        blockType: ParagraphBlockType.header1,
      );
      final copy = node.copyWith(textAlign: TextAlign.justify);
      expect(copy.id, 'p1');
      expect(copy.blockType, ParagraphBlockType.header1);
      expect(copy.textAlign, TextAlign.justify);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — equality with textAlign
  // ---------------------------------------------------------------------------
  group('ParagraphNode equality with textAlign', () {
    test('equal when textAlign is the same', () {
      final a = ParagraphNode(id: 'p1', textAlign: TextAlign.center);
      final b = ParagraphNode(id: 'p1', textAlign: TextAlign.center);
      expect(a, equals(b));
    });

    test('unequal when textAlign differs', () {
      final a = ParagraphNode(id: 'p1', textAlign: TextAlign.start);
      final b = ParagraphNode(id: 'p1', textAlign: TextAlign.center);
      expect(a, isNot(equals(b)));
    });

    test('equal when textAlign is both default', () {
      final a = ParagraphNode(id: 'p1');
      final b = ParagraphNode(id: 'p1');
      expect(a, equals(b));
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — hashCode consistency with textAlign
  // ---------------------------------------------------------------------------
  group('ParagraphNode hashCode with textAlign', () {
    test('hashCode matches for equal nodes with same textAlign', () {
      final a = ParagraphNode(id: 'p1', textAlign: TextAlign.center);
      final b = ParagraphNode(id: 'p1', textAlign: TextAlign.center);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode differs when textAlign differs', () {
      final a = ParagraphNode(id: 'p1', textAlign: TextAlign.start);
      final b = ParagraphNode(id: 'p1', textAlign: TextAlign.center);
      // Not strictly required by contract but expected for a well-distributed hash.
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — toString includes textAlign
  // ---------------------------------------------------------------------------
  group('ParagraphNode toString with textAlign', () {
    test('toString includes textAlign value', () {
      final node = ParagraphNode(id: 'p1', textAlign: TextAlign.center);
      expect(node.toString(), contains('center'));
    });

    test('toString still includes id', () {
      final node = ParagraphNode(id: 'para-unique', textAlign: TextAlign.justify);
      expect(node.toString(), contains('para-unique'));
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — lineHeight default value
  // ---------------------------------------------------------------------------
  group('ParagraphNode lineHeight default', () {
    test('lineHeight defaults to null', () {
      final node = ParagraphNode(id: 'p1');
      expect(node.lineHeight, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — constructor with lineHeight
  // ---------------------------------------------------------------------------
  group('ParagraphNode constructor with lineHeight', () {
    test('lineHeight is set correctly to 1.5', () {
      final node = ParagraphNode(id: 'p1', lineHeight: 1.5);
      expect(node.lineHeight, 1.5);
    });

    test('lineHeight is set correctly to 2.0', () {
      final node = ParagraphNode(id: 'p1', lineHeight: 2.0);
      expect(node.lineHeight, 2.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — copyWith with lineHeight
  // ---------------------------------------------------------------------------
  group('ParagraphNode copyWith lineHeight', () {
    test('copyWith replaces lineHeight', () {
      final node = ParagraphNode(id: 'p1', lineHeight: 1.5);
      final copy = node.copyWith(lineHeight: 2.0);
      expect(copy.lineHeight, 2.0);
    });

    test('copyWith preserves lineHeight when not specified', () {
      final node = ParagraphNode(id: 'p1', lineHeight: 1.8);
      final copy = node.copyWith(id: 'p2');
      expect(copy.lineHeight, 1.8);
    });

    test('copyWith preserves other fields when only lineHeight changes', () {
      final node = ParagraphNode(
        id: 'p1',
        textAlign: TextAlign.center,
        blockType: ParagraphBlockType.header2,
        lineHeight: 1.0,
      );
      final copy = node.copyWith(lineHeight: 1.5);
      expect(copy.id, 'p1');
      expect(copy.textAlign, TextAlign.center);
      expect(copy.blockType, ParagraphBlockType.header2);
      expect(copy.lineHeight, 1.5);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — equality with lineHeight
  // ---------------------------------------------------------------------------
  group('ParagraphNode equality with lineHeight', () {
    test('equal when lineHeight is both null', () {
      final a = ParagraphNode(id: 'p1');
      final b = ParagraphNode(id: 'p1');
      expect(a, equals(b));
    });

    test('equal when lineHeight is the same non-null value', () {
      final a = ParagraphNode(id: 'p1', lineHeight: 1.5);
      final b = ParagraphNode(id: 'p1', lineHeight: 1.5);
      expect(a, equals(b));
    });

    test('unequal when lineHeight differs', () {
      final a = ParagraphNode(id: 'p1', lineHeight: 1.5);
      final b = ParagraphNode(id: 'p1', lineHeight: 2.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when one lineHeight is null and other is not', () {
      final a = ParagraphNode(id: 'p1');
      final b = ParagraphNode(id: 'p1', lineHeight: 1.5);
      expect(a, isNot(equals(b)));
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — hashCode with lineHeight
  // ---------------------------------------------------------------------------
  group('ParagraphNode hashCode with lineHeight', () {
    test('hashCode matches for equal nodes with same lineHeight', () {
      final a = ParagraphNode(id: 'p1', lineHeight: 1.5);
      final b = ParagraphNode(id: 'p1', lineHeight: 1.5);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode differs when lineHeight differs', () {
      final a = ParagraphNode(id: 'p1', lineHeight: 1.5);
      final b = ParagraphNode(id: 'p1', lineHeight: 2.0);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — toString includes lineHeight
  // ---------------------------------------------------------------------------
  group('ParagraphNode toString with lineHeight', () {
    test('toString includes lineHeight when set', () {
      final node = ParagraphNode(id: 'p1', lineHeight: 1.5);
      expect(node.toString(), contains('1.5'));
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — debugFillProperties includes lineHeight
  // ---------------------------------------------------------------------------
  group('ParagraphNode debugFillProperties with lineHeight', () {
    test('debugFillProperties includes lineHeight when non-null', () {
      final node = ParagraphNode(id: 'p1', lineHeight: 1.5);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'lineHeight',
            orElse: () => throw StateError('lineHeight property not found'),
          );
      expect(prop.value, 1.5);
    });

    test('debugFillProperties lineHeight is absent (default null) when not set', () {
      final node = ParagraphNode(id: 'p1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'lineHeight');
      // The property may exist but its value should be null.
      for (final p in props) {
        expect(p.value, isNull);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — spaceBefore default value
  // ---------------------------------------------------------------------------
  group('ParagraphNode spaceBefore default', () {
    test('spaceBefore defaults to null', () {
      final node = ParagraphNode(id: 'p1');
      expect(node.spaceBefore, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — spaceAfter default value
  // ---------------------------------------------------------------------------
  group('ParagraphNode spaceAfter default', () {
    test('spaceAfter defaults to null', () {
      final node = ParagraphNode(id: 'p1');
      expect(node.spaceAfter, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — constructor with spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('ParagraphNode constructor with spaceBefore/spaceAfter', () {
    test('spaceBefore is set correctly', () {
      final node = ParagraphNode(id: 'p1', spaceBefore: 8.0);
      expect(node.spaceBefore, 8.0);
    });

    test('spaceAfter is set correctly', () {
      final node = ParagraphNode(id: 'p1', spaceAfter: 16.0);
      expect(node.spaceAfter, 16.0);
    });

    test('both spaceBefore and spaceAfter can be set together', () {
      final node = ParagraphNode(id: 'p1', spaceBefore: 4.0, spaceAfter: 12.0);
      expect(node.spaceBefore, 4.0);
      expect(node.spaceAfter, 12.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — copyWith with spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('ParagraphNode copyWith spaceBefore/spaceAfter', () {
    test('copyWith replaces spaceBefore', () {
      final node = ParagraphNode(id: 'p1', spaceBefore: 8.0);
      final copy = node.copyWith(spaceBefore: 16.0);
      expect(copy.spaceBefore, 16.0);
    });

    test('copyWith preserves spaceBefore when not specified', () {
      final node = ParagraphNode(id: 'p1', spaceBefore: 8.0);
      final copy = node.copyWith(id: 'p2');
      expect(copy.spaceBefore, 8.0);
    });

    test('copyWith replaces spaceAfter', () {
      final node = ParagraphNode(id: 'p1', spaceAfter: 12.0);
      final copy = node.copyWith(spaceAfter: 24.0);
      expect(copy.spaceAfter, 24.0);
    });

    test('copyWith preserves spaceAfter when not specified', () {
      final node = ParagraphNode(id: 'p1', spaceAfter: 12.0);
      final copy = node.copyWith(id: 'p2');
      expect(copy.spaceAfter, 12.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — equality with spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('ParagraphNode equality with spaceBefore/spaceAfter', () {
    test('unequal when spaceBefore differs', () {
      final a = ParagraphNode(id: 'p1', spaceBefore: 8.0);
      final b = ParagraphNode(id: 'p1', spaceBefore: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when spaceAfter differs', () {
      final a = ParagraphNode(id: 'p1', spaceAfter: 8.0);
      final b = ParagraphNode(id: 'p1', spaceAfter: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('equal when spaceBefore and spaceAfter are both null', () {
      final a = ParagraphNode(id: 'p1');
      final b = ParagraphNode(id: 'p1');
      expect(a, equals(b));
    });

    test('equal when spaceBefore and spaceAfter match', () {
      final a = ParagraphNode(id: 'p1', spaceBefore: 4.0, spaceAfter: 8.0);
      final b = ParagraphNode(id: 'p1', spaceBefore: 4.0, spaceAfter: 8.0);
      expect(a, equals(b));
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — debugFillProperties includes spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('ParagraphNode debugFillProperties with spaceBefore/spaceAfter', () {
    test('debugFillProperties includes spaceBefore when non-null', () {
      final node = ParagraphNode(id: 'p1', spaceBefore: 8.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'spaceBefore',
            orElse: () => throw StateError('spaceBefore property not found'),
          );
      expect(prop.value, 8.0);
    });

    test('debugFillProperties includes spaceAfter when non-null', () {
      final node = ParagraphNode(id: 'p1', spaceAfter: 16.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'spaceAfter',
            orElse: () => throw StateError('spaceAfter property not found'),
          );
      expect(prop.value, 16.0);
    });

    test('debugFillProperties spaceBefore value is null when not set', () {
      final node = ParagraphNode(id: 'p1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'spaceBefore');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });

    test('debugFillProperties spaceAfter value is null when not set', () {
      final node = ParagraphNode(id: 'p1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'spaceAfter');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — indentLeft default value
  // ---------------------------------------------------------------------------
  group('ParagraphNode indentLeft default', () {
    test('indentLeft defaults to null', () {
      final node = ParagraphNode(id: 'p1');
      expect(node.indentLeft, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — indentRight default value
  // ---------------------------------------------------------------------------
  group('ParagraphNode indentRight default', () {
    test('indentRight defaults to null', () {
      final node = ParagraphNode(id: 'p1');
      expect(node.indentRight, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — firstLineIndent default value
  // ---------------------------------------------------------------------------
  group('ParagraphNode firstLineIndent default', () {
    test('firstLineIndent defaults to null', () {
      final node = ParagraphNode(id: 'p1');
      expect(node.firstLineIndent, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — constructor with indent fields
  // ---------------------------------------------------------------------------
  group('ParagraphNode constructor with indent fields', () {
    test('indentLeft is set correctly', () {
      final node = ParagraphNode(id: 'p1', indentLeft: 16.0);
      expect(node.indentLeft, 16.0);
    });

    test('indentRight is set correctly', () {
      final node = ParagraphNode(id: 'p1', indentRight: 8.0);
      expect(node.indentRight, 8.0);
    });

    test('firstLineIndent is set correctly (positive)', () {
      final node = ParagraphNode(id: 'p1', firstLineIndent: 24.0);
      expect(node.firstLineIndent, 24.0);
    });

    test('firstLineIndent is set correctly (negative — hanging indent)', () {
      final node = ParagraphNode(id: 'p1', firstLineIndent: -16.0);
      expect(node.firstLineIndent, -16.0);
    });

    test('all three indent fields can be set together', () {
      final node =
          ParagraphNode(id: 'p1', indentLeft: 16.0, indentRight: 8.0, firstLineIndent: 24.0);
      expect(node.indentLeft, 16.0);
      expect(node.indentRight, 8.0);
      expect(node.firstLineIndent, 24.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — copyWith with indent fields
  // ---------------------------------------------------------------------------
  group('ParagraphNode copyWith indent fields', () {
    test('copyWith replaces indentLeft', () {
      final node = ParagraphNode(id: 'p1', indentLeft: 8.0);
      final copy = node.copyWith(indentLeft: 16.0);
      expect(copy.indentLeft, 16.0);
    });

    test('copyWith preserves indentLeft when not specified', () {
      final node = ParagraphNode(id: 'p1', indentLeft: 8.0);
      final copy = node.copyWith(id: 'p2');
      expect(copy.indentLeft, 8.0);
    });

    test('copyWith replaces indentRight', () {
      final node = ParagraphNode(id: 'p1', indentRight: 8.0);
      final copy = node.copyWith(indentRight: 16.0);
      expect(copy.indentRight, 16.0);
    });

    test('copyWith preserves indentRight when not specified', () {
      final node = ParagraphNode(id: 'p1', indentRight: 8.0);
      final copy = node.copyWith(id: 'p2');
      expect(copy.indentRight, 8.0);
    });

    test('copyWith replaces firstLineIndent', () {
      final node = ParagraphNode(id: 'p1', firstLineIndent: 24.0);
      final copy = node.copyWith(firstLineIndent: -16.0);
      expect(copy.firstLineIndent, -16.0);
    });

    test('copyWith preserves firstLineIndent when not specified', () {
      final node = ParagraphNode(id: 'p1', firstLineIndent: 24.0);
      final copy = node.copyWith(id: 'p2');
      expect(copy.firstLineIndent, 24.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — equality with indent fields
  // ---------------------------------------------------------------------------
  group('ParagraphNode equality with indent fields', () {
    test('equal when all indent fields are both null', () {
      final a = ParagraphNode(id: 'p1');
      final b = ParagraphNode(id: 'p1');
      expect(a, equals(b));
    });

    test('equal when all indent fields match', () {
      final a = ParagraphNode(id: 'p1', indentLeft: 16.0, indentRight: 8.0, firstLineIndent: 24.0);
      final b = ParagraphNode(id: 'p1', indentLeft: 16.0, indentRight: 8.0, firstLineIndent: 24.0);
      expect(a, equals(b));
    });

    test('unequal when indentLeft differs', () {
      final a = ParagraphNode(id: 'p1', indentLeft: 8.0);
      final b = ParagraphNode(id: 'p1', indentLeft: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when indentRight differs', () {
      final a = ParagraphNode(id: 'p1', indentRight: 4.0);
      final b = ParagraphNode(id: 'p1', indentRight: 8.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when firstLineIndent differs', () {
      final a = ParagraphNode(id: 'p1', firstLineIndent: 16.0);
      final b = ParagraphNode(id: 'p1', firstLineIndent: 24.0);
      expect(a, isNot(equals(b)));
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — hashCode with indent fields
  // ---------------------------------------------------------------------------
  group('ParagraphNode hashCode with indent fields', () {
    test('hashCode matches for equal nodes with same indent fields', () {
      final a = ParagraphNode(id: 'p1', indentLeft: 16.0, indentRight: 8.0, firstLineIndent: 24.0);
      final b = ParagraphNode(id: 'p1', indentLeft: 16.0, indentRight: 8.0, firstLineIndent: 24.0);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode differs when indentLeft differs', () {
      final a = ParagraphNode(id: 'p1', indentLeft: 8.0);
      final b = ParagraphNode(id: 'p1', indentLeft: 16.0);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — toString includes indent fields
  // ---------------------------------------------------------------------------
  group('ParagraphNode toString with indent fields', () {
    test('toString includes indentLeft when set', () {
      final node = ParagraphNode(id: 'p1', indentLeft: 16.0);
      expect(node.toString(), contains('16.0'));
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — debugFillProperties includes indent fields
  // ---------------------------------------------------------------------------
  group('ParagraphNode debugFillProperties with indent fields', () {
    test('debugFillProperties includes indentLeft when non-null', () {
      final node = ParagraphNode(id: 'p1', indentLeft: 16.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'indentLeft',
            orElse: () => throw StateError('indentLeft property not found'),
          );
      expect(prop.value, 16.0);
    });

    test('debugFillProperties includes indentRight when non-null', () {
      final node = ParagraphNode(id: 'p1', indentRight: 8.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'indentRight',
            orElse: () => throw StateError('indentRight property not found'),
          );
      expect(prop.value, 8.0);
    });

    test('debugFillProperties includes firstLineIndent when non-null', () {
      final node = ParagraphNode(id: 'p1', firstLineIndent: 24.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'firstLineIndent',
            orElse: () => throw StateError('firstLineIndent property not found'),
          );
      expect(prop.value, 24.0);
    });

    test('debugFillProperties indentLeft value is null when not set', () {
      final node = ParagraphNode(id: 'p1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'indentLeft');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — border default value
  // ---------------------------------------------------------------------------
  group('ParagraphNode border default', () {
    test('border defaults to null', () {
      final node = ParagraphNode(id: 'p1');
      expect(node.border, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — constructor with border
  // ---------------------------------------------------------------------------
  group('ParagraphNode constructor with border', () {
    test('border is set correctly', () {
      const border = BlockBorder(style: BlockBorderStyle.solid, width: 2.0);
      final node = ParagraphNode(id: 'p1', border: border);
      expect(node.border, border);
    });

    test('border with dashed style is set correctly', () {
      const border = BlockBorder(style: BlockBorderStyle.dashed, width: 1.5);
      final node = ParagraphNode(id: 'p1', border: border);
      expect(node.border?.style, BlockBorderStyle.dashed);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — copyWith with border
  // ---------------------------------------------------------------------------
  group('ParagraphNode copyWith border', () {
    test('copyWith replaces border', () {
      const original = BlockBorder(style: BlockBorderStyle.solid, width: 1.0);
      const replacement = BlockBorder(style: BlockBorderStyle.dashed, width: 2.0);
      final node = ParagraphNode(id: 'p1', border: original);
      final copy = node.copyWith(border: replacement);
      expect(copy.border, replacement);
    });

    test('copyWith preserves border when not specified', () {
      const border = BlockBorder(style: BlockBorderStyle.dotted, width: 3.0);
      final node = ParagraphNode(id: 'p1', border: border);
      final copy = node.copyWith(id: 'p2');
      expect(copy.border, border);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — equality with border
  // ---------------------------------------------------------------------------
  group('ParagraphNode equality with border', () {
    test('equal when border is both null', () {
      final a = ParagraphNode(id: 'p1');
      final b = ParagraphNode(id: 'p1');
      expect(a, equals(b));
    });

    test('equal when border matches', () {
      const border = BlockBorder(style: BlockBorderStyle.solid, width: 2.0);
      final a = ParagraphNode(id: 'p1', border: border);
      final b = ParagraphNode(id: 'p1', border: border);
      expect(a, equals(b));
    });

    test('unequal when border differs', () {
      final a = ParagraphNode(id: 'p1', border: const BlockBorder(width: 1.0));
      final b = ParagraphNode(id: 'p1', border: const BlockBorder(width: 2.0));
      expect(a, isNot(equals(b)));
    });

    test('unequal when one border is null and other is not', () {
      final a = ParagraphNode(id: 'p1');
      final b = ParagraphNode(id: 'p1', border: const BlockBorder());
      expect(a, isNot(equals(b)));
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode — debugFillProperties includes border
  // ---------------------------------------------------------------------------
  group('ParagraphNode debugFillProperties with border', () {
    test('debugFillProperties includes border when non-null', () {
      const border = BlockBorder(style: BlockBorderStyle.dashed, width: 2.0);
      final node = ParagraphNode(id: 'p1', border: border);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DiagnosticsProperty<BlockBorder?>>().firstWhere(
            (p) => p.name == 'border',
            orElse: () => throw StateError('border property not found'),
          );
      expect(prop.value, border);
    });

    test('debugFillProperties border value is null when not set', () {
      final node = ParagraphNode(id: 'p1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props = builder.properties
          .whereType<DiagnosticsProperty<BlockBorder?>>()
          .where((p) => p.name == 'border');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });
  });
}
