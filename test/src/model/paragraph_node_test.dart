/// Tests for [ParagraphNode] — focusing on [textAlign] field.
///
/// These tests cover the [textAlign] constructor parameter, [copyWith],
/// equality, hashCode, and [debugFillProperties]/toString integration.
library;

import 'dart:ui' show TextAlign;

import 'package:editable_document/src/model/paragraph_node.dart';
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
}
