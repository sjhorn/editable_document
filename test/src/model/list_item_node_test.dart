/// Tests for [ListItemNode] — focusing on [textAlign] field.
///
/// These tests cover the [textAlign] constructor parameter, [copyWith],
/// equality, hashCode, and toString integration.
library;

import 'dart:ui' show TextAlign;

import 'package:editable_document/src/model/list_item_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ListItemNode — textAlign default value
  // ---------------------------------------------------------------------------
  group('ListItemNode textAlign default', () {
    test('textAlign defaults to TextAlign.start', () {
      final node = ListItemNode(id: 'li1');
      expect(node.textAlign, TextAlign.start);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — constructor with textAlign
  // ---------------------------------------------------------------------------
  group('ListItemNode constructor with textAlign', () {
    test('textAlign is set correctly to center', () {
      final node = ListItemNode(id: 'li1', textAlign: TextAlign.center);
      expect(node.textAlign, TextAlign.center);
    });

    test('textAlign is set correctly to end', () {
      final node = ListItemNode(id: 'li1', textAlign: TextAlign.end);
      expect(node.textAlign, TextAlign.end);
    });

    test('textAlign is set correctly to justify', () {
      final node = ListItemNode(id: 'li1', textAlign: TextAlign.justify);
      expect(node.textAlign, TextAlign.justify);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — copyWith with textAlign
  // ---------------------------------------------------------------------------
  group('ListItemNode copyWith textAlign', () {
    test('copyWith replaces textAlign', () {
      final node = ListItemNode(id: 'li1', textAlign: TextAlign.start);
      final copy = node.copyWith(textAlign: TextAlign.center);
      expect(copy.textAlign, TextAlign.center);
    });

    test('copyWith preserves textAlign when not specified', () {
      final node = ListItemNode(id: 'li1', textAlign: TextAlign.end);
      final copy = node.copyWith(id: 'li2');
      expect(copy.textAlign, TextAlign.end);
    });

    test('copyWith preserves other fields when only textAlign changes', () {
      final node = ListItemNode(
        id: 'li1',
        textAlign: TextAlign.start,
        type: ListItemType.ordered,
        indent: 2,
      );
      final copy = node.copyWith(textAlign: TextAlign.justify);
      expect(copy.id, 'li1');
      expect(copy.type, ListItemType.ordered);
      expect(copy.indent, 2);
      expect(copy.textAlign, TextAlign.justify);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — equality with textAlign
  // ---------------------------------------------------------------------------
  group('ListItemNode equality with textAlign', () {
    test('equal when textAlign is the same', () {
      final a = ListItemNode(id: 'li1', textAlign: TextAlign.center);
      final b = ListItemNode(id: 'li1', textAlign: TextAlign.center);
      expect(a, equals(b));
    });

    test('unequal when textAlign differs', () {
      final a = ListItemNode(id: 'li1', textAlign: TextAlign.start);
      final b = ListItemNode(id: 'li1', textAlign: TextAlign.center);
      expect(a, isNot(equals(b)));
    });

    test('equal when textAlign is both default', () {
      final a = ListItemNode(id: 'li1');
      final b = ListItemNode(id: 'li1');
      expect(a, equals(b));
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — hashCode consistency with textAlign
  // ---------------------------------------------------------------------------
  group('ListItemNode hashCode with textAlign', () {
    test('hashCode matches for equal nodes with same textAlign', () {
      final a = ListItemNode(id: 'li1', textAlign: TextAlign.center);
      final b = ListItemNode(id: 'li1', textAlign: TextAlign.center);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode differs when textAlign differs', () {
      final a = ListItemNode(id: 'li1', textAlign: TextAlign.start);
      final b = ListItemNode(id: 'li1', textAlign: TextAlign.center);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — toString includes textAlign
  // ---------------------------------------------------------------------------
  group('ListItemNode toString with textAlign', () {
    test('toString includes textAlign value', () {
      final node = ListItemNode(id: 'li1', textAlign: TextAlign.center);
      expect(node.toString(), contains('center'));
    });

    test('toString still includes id', () {
      final node = ListItemNode(id: 'li-unique', textAlign: TextAlign.justify);
      expect(node.toString(), contains('li-unique'));
    });
  });
}
