/// Tests for [ImageNode] — lockAspect, spaceBefore, and spaceAfter fields.
library;

import 'package:editable_document/src/model/block_border.dart';
import 'package:editable_document/src/model/image_node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageNode', () {
    // -------------------------------------------------------------------------
    // lockAspect — default value
    // -------------------------------------------------------------------------

    test('lockAspect defaults to true', () {
      final node = ImageNode(id: 'img-1', imageUrl: 'https://example.com/a.png');

      expect(node.lockAspect, isTrue);
    });

    // -------------------------------------------------------------------------
    // lockAspect — explicit false
    // -------------------------------------------------------------------------

    test('constructor stores lockAspect: false', () {
      final node = ImageNode(
        id: 'img-2',
        imageUrl: 'https://example.com/a.png',
        lockAspect: false,
      );

      expect(node.lockAspect, isFalse);
    });

    // -------------------------------------------------------------------------
    // copyWith — overrides lockAspect
    // -------------------------------------------------------------------------

    test('copyWith(lockAspect: false) returns node with lockAspect == false', () {
      final original = ImageNode(id: 'img-3', imageUrl: 'https://example.com/a.png');
      final copy = original.copyWith(lockAspect: false);

      expect(copy.lockAspect, isFalse);
    });

    // -------------------------------------------------------------------------
    // copyWith — preserves lockAspect when not overridden
    // -------------------------------------------------------------------------

    test('copyWith() with no lockAspect arg preserves current value', () {
      final original = ImageNode(
        id: 'img-4',
        imageUrl: 'https://example.com/a.png',
        lockAspect: false,
      );
      final copy = original.copyWith(id: 'img-4-copy');

      expect(copy.lockAspect, isFalse);
    });

    test('copyWith() preserves lockAspect: true', () {
      final original = ImageNode(id: 'img-5', imageUrl: 'https://example.com/a.png');
      final copy = original.copyWith(id: 'img-5-copy');

      expect(copy.lockAspect, isTrue);
    });

    // -------------------------------------------------------------------------
    // Equality — different lockAspect are not equal
    // -------------------------------------------------------------------------

    test('two nodes with different lockAspect are not equal', () {
      final a = ImageNode(
        id: 'img-6',
        imageUrl: 'https://example.com/a.png',
        lockAspect: true,
      );
      final b = ImageNode(
        id: 'img-6',
        imageUrl: 'https://example.com/a.png',
        lockAspect: false,
      );

      expect(a, isNot(equals(b)));
    });

    // -------------------------------------------------------------------------
    // Equality — identical lockAspect are equal
    // -------------------------------------------------------------------------

    test('two nodes with identical fields including lockAspect are equal', () {
      final a = ImageNode(
        id: 'img-7',
        imageUrl: 'https://example.com/a.png',
        lockAspect: false,
      );
      final b = ImageNode(
        id: 'img-7',
        imageUrl: 'https://example.com/a.png',
        lockAspect: false,
      );

      expect(a, equals(b));
    });

    // -------------------------------------------------------------------------
    // hashCode — differs for different lockAspect
    // -------------------------------------------------------------------------

    test('hashCode differs for different lockAspect values', () {
      final a = ImageNode(
        id: 'img-8',
        imageUrl: 'https://example.com/a.png',
        lockAspect: true,
      );
      final b = ImageNode(
        id: 'img-8',
        imageUrl: 'https://example.com/a.png',
        lockAspect: false,
      );

      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    // -------------------------------------------------------------------------
    // debugFillProperties — includes lockAspect
    // -------------------------------------------------------------------------

    test('debugFillProperties includes lockAspect', () {
      final node = ImageNode(
        id: 'img-9',
        imageUrl: 'https://example.com/a.png',
        lockAspect: false,
      );

      final description = node.toDiagnosticsNode().toStringDeep();
      expect(description, contains('lockAspect'));
    });

    // -------------------------------------------------------------------------
    // toString — includes lockAspect
    // -------------------------------------------------------------------------

    test('toString includes lockAspect', () {
      final node = ImageNode(
        id: 'img-10',
        imageUrl: 'https://example.com/a.png',
        lockAspect: false,
      );

      final s = node.toString();
      expect(s, contains('lockAspect: false'));
    });

    // -------------------------------------------------------------------------
    // spaceBefore — default value
    // -------------------------------------------------------------------------

    test('spaceBefore defaults to null', () {
      final node = ImageNode(id: 'img-11', imageUrl: 'https://example.com/a.png');
      expect(node.spaceBefore, isNull);
    });

    // -------------------------------------------------------------------------
    // spaceAfter — default value
    // -------------------------------------------------------------------------

    test('spaceAfter defaults to null', () {
      final node = ImageNode(id: 'img-12', imageUrl: 'https://example.com/a.png');
      expect(node.spaceAfter, isNull);
    });

    // -------------------------------------------------------------------------
    // spaceBefore/spaceAfter — constructor
    // -------------------------------------------------------------------------

    test('constructor stores spaceBefore', () {
      final node = ImageNode(
        id: 'img-13',
        imageUrl: 'https://example.com/a.png',
        spaceBefore: 8.0,
      );
      expect(node.spaceBefore, 8.0);
    });

    test('constructor stores spaceAfter', () {
      final node = ImageNode(
        id: 'img-14',
        imageUrl: 'https://example.com/a.png',
        spaceAfter: 16.0,
      );
      expect(node.spaceAfter, 16.0);
    });

    // -------------------------------------------------------------------------
    // spaceBefore/spaceAfter — copyWith preserves when not overridden
    // -------------------------------------------------------------------------

    test('copyWith preserves spaceBefore when not overridden', () {
      final original = ImageNode(
        id: 'img-15',
        imageUrl: 'https://example.com/a.png',
        spaceBefore: 8.0,
      );
      final copy = original.copyWith(id: 'img-15-copy');
      expect(copy.spaceBefore, 8.0);
    });

    test('copyWith preserves spaceAfter when not overridden', () {
      final original = ImageNode(
        id: 'img-16',
        imageUrl: 'https://example.com/a.png',
        spaceAfter: 16.0,
      );
      final copy = original.copyWith(id: 'img-16-copy');
      expect(copy.spaceAfter, 16.0);
    });

    test('copyWith replaces spaceBefore', () {
      final original = ImageNode(
        id: 'img-17',
        imageUrl: 'https://example.com/a.png',
        spaceBefore: 8.0,
      );
      final copy = original.copyWith(spaceBefore: 24.0);
      expect(copy.spaceBefore, 24.0);
    });

    test('copyWith replaces spaceAfter', () {
      final original = ImageNode(
        id: 'img-18',
        imageUrl: 'https://example.com/a.png',
        spaceAfter: 16.0,
      );
      final copy = original.copyWith(spaceAfter: 32.0);
      expect(copy.spaceAfter, 32.0);
    });

    // -------------------------------------------------------------------------
    // spaceBefore/spaceAfter — equality
    // -------------------------------------------------------------------------

    test('nodes with different spaceBefore are not equal', () {
      final a = ImageNode(
        id: 'img-19',
        imageUrl: 'https://example.com/a.png',
        spaceBefore: 8.0,
      );
      final b = ImageNode(
        id: 'img-19',
        imageUrl: 'https://example.com/a.png',
        spaceBefore: 16.0,
      );
      expect(a, isNot(equals(b)));
    });

    test('nodes with different spaceAfter are not equal', () {
      final a = ImageNode(
        id: 'img-20',
        imageUrl: 'https://example.com/a.png',
        spaceAfter: 8.0,
      );
      final b = ImageNode(
        id: 'img-20',
        imageUrl: 'https://example.com/a.png',
        spaceAfter: 16.0,
      );
      expect(a, isNot(equals(b)));
    });

    // -------------------------------------------------------------------------
    // debugFillProperties — includes spaceBefore/spaceAfter
    // -------------------------------------------------------------------------

    test('debugFillProperties includes spaceBefore when non-null', () {
      final node = ImageNode(
        id: 'img-21',
        imageUrl: 'https://example.com/a.png',
        spaceBefore: 8.0,
      );
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'spaceBefore',
            orElse: () => throw StateError('spaceBefore property not found'),
          );
      expect(prop.value, 8.0);
    });

    test('debugFillProperties includes spaceAfter when non-null', () {
      final node = ImageNode(
        id: 'img-22',
        imageUrl: 'https://example.com/a.png',
        spaceAfter: 16.0,
      );
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
  // border — default value
  // -------------------------------------------------------------------------

  group('ImageNode border', () {
    test('border defaults to null', () {
      final node = ImageNode(id: 'img-23', imageUrl: 'https://example.com/a.png');
      expect(node.border, isNull);
    });

    test('constructor stores border', () {
      const border = BlockBorder(style: BlockBorderStyle.solid, width: 2.0);
      final node = ImageNode(
        id: 'img-24',
        imageUrl: 'https://example.com/a.png',
        border: border,
      );
      expect(node.border, border);
    });

    test('copyWith preserves border when not overridden', () {
      const border = BlockBorder(style: BlockBorderStyle.dashed, width: 1.5);
      final original = ImageNode(
        id: 'img-25',
        imageUrl: 'https://example.com/a.png',
        border: border,
      );
      final copy = original.copyWith(id: 'img-25-copy');
      expect(copy.border, border);
    });

    test('copyWith replaces border', () {
      const original = BlockBorder(style: BlockBorderStyle.solid, width: 1.0);
      const replacement = BlockBorder(style: BlockBorderStyle.dotted, width: 3.0);
      final node = ImageNode(
        id: 'img-26',
        imageUrl: 'https://example.com/a.png',
        border: original,
      );
      final copy = node.copyWith(border: replacement);
      expect(copy.border, replacement);
    });

    test('nodes with different border are not equal', () {
      final a = ImageNode(
        id: 'img-27',
        imageUrl: 'https://example.com/a.png',
        border: const BlockBorder(width: 1.0),
      );
      final b = ImageNode(
        id: 'img-27',
        imageUrl: 'https://example.com/a.png',
        border: const BlockBorder(width: 2.0),
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when one border is null and other is not', () {
      final a = ImageNode(id: 'img-28', imageUrl: 'https://example.com/a.png');
      final b = ImageNode(
        id: 'img-28',
        imageUrl: 'https://example.com/a.png',
        border: const BlockBorder(),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
