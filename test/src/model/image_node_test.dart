/// Tests for [ImageNode] — lockAspect field.
library;

import 'package:editable_document/src/model/image_node.dart';
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
  });
}
