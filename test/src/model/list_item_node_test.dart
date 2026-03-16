/// Tests for [ListItemNode] — focusing on [textAlign], [lineHeight],
/// [spaceBefore], and [spaceAfter] fields.
///
/// These tests cover the [textAlign], [lineHeight], [spaceBefore], and
/// [spaceAfter] constructor parameters, [copyWith], equality, hashCode, and
/// toString integration.
library;

import 'dart:ui' show TextAlign;

import 'package:editable_document/src/model/list_item_node.dart';
import 'package:flutter/foundation.dart';
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

  // ---------------------------------------------------------------------------
  // ListItemNode — lineHeight default value
  // ---------------------------------------------------------------------------
  group('ListItemNode lineHeight default', () {
    test('lineHeight defaults to null', () {
      final node = ListItemNode(id: 'li1');
      expect(node.lineHeight, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — constructor with lineHeight
  // ---------------------------------------------------------------------------
  group('ListItemNode constructor with lineHeight', () {
    test('lineHeight is set correctly to 1.5', () {
      final node = ListItemNode(id: 'li1', lineHeight: 1.5);
      expect(node.lineHeight, 1.5);
    });

    test('lineHeight is set correctly to 2.0', () {
      final node = ListItemNode(id: 'li1', lineHeight: 2.0);
      expect(node.lineHeight, 2.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — copyWith with lineHeight
  // ---------------------------------------------------------------------------
  group('ListItemNode copyWith lineHeight', () {
    test('copyWith replaces lineHeight', () {
      final node = ListItemNode(id: 'li1', lineHeight: 1.5);
      final copy = node.copyWith(lineHeight: 2.0);
      expect(copy.lineHeight, 2.0);
    });

    test('copyWith preserves lineHeight when not specified', () {
      final node = ListItemNode(id: 'li1', lineHeight: 1.8);
      final copy = node.copyWith(id: 'li2');
      expect(copy.lineHeight, 1.8);
    });

    test('copyWith preserves other fields when only lineHeight changes', () {
      final node = ListItemNode(
        id: 'li1',
        type: ListItemType.ordered,
        indent: 2,
        textAlign: TextAlign.center,
        lineHeight: 1.0,
      );
      final copy = node.copyWith(lineHeight: 1.5);
      expect(copy.id, 'li1');
      expect(copy.type, ListItemType.ordered);
      expect(copy.indent, 2);
      expect(copy.textAlign, TextAlign.center);
      expect(copy.lineHeight, 1.5);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — equality with lineHeight
  // ---------------------------------------------------------------------------
  group('ListItemNode equality with lineHeight', () {
    test('equal when lineHeight is both null', () {
      final a = ListItemNode(id: 'li1');
      final b = ListItemNode(id: 'li1');
      expect(a, equals(b));
    });

    test('equal when lineHeight is the same non-null value', () {
      final a = ListItemNode(id: 'li1', lineHeight: 1.5);
      final b = ListItemNode(id: 'li1', lineHeight: 1.5);
      expect(a, equals(b));
    });

    test('unequal when lineHeight differs', () {
      final a = ListItemNode(id: 'li1', lineHeight: 1.5);
      final b = ListItemNode(id: 'li1', lineHeight: 2.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when one lineHeight is null and other is not', () {
      final a = ListItemNode(id: 'li1');
      final b = ListItemNode(id: 'li1', lineHeight: 1.5);
      expect(a, isNot(equals(b)));
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — hashCode with lineHeight
  // ---------------------------------------------------------------------------
  group('ListItemNode hashCode with lineHeight', () {
    test('hashCode matches for equal nodes with same lineHeight', () {
      final a = ListItemNode(id: 'li1', lineHeight: 1.5);
      final b = ListItemNode(id: 'li1', lineHeight: 1.5);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode differs when lineHeight differs', () {
      final a = ListItemNode(id: 'li1', lineHeight: 1.5);
      final b = ListItemNode(id: 'li1', lineHeight: 2.0);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — toString includes lineHeight
  // ---------------------------------------------------------------------------
  group('ListItemNode toString with lineHeight', () {
    test('toString includes lineHeight when set', () {
      final node = ListItemNode(id: 'li1', lineHeight: 1.5);
      expect(node.toString(), contains('1.5'));
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — debugFillProperties includes lineHeight
  // ---------------------------------------------------------------------------
  group('ListItemNode debugFillProperties with lineHeight', () {
    test('debugFillProperties includes lineHeight when non-null', () {
      final node = ListItemNode(id: 'li1', lineHeight: 1.5);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'lineHeight',
            orElse: () => throw StateError('lineHeight property not found'),
          );
      expect(prop.value, 1.5);
    });

    test('debugFillProperties lineHeight is absent (default null) when not set', () {
      final node = ListItemNode(id: 'li1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'lineHeight');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — spaceBefore default value
  // ---------------------------------------------------------------------------
  group('ListItemNode spaceBefore default', () {
    test('spaceBefore defaults to null', () {
      final node = ListItemNode(id: 'li1');
      expect(node.spaceBefore, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — spaceAfter default value
  // ---------------------------------------------------------------------------
  group('ListItemNode spaceAfter default', () {
    test('spaceAfter defaults to null', () {
      final node = ListItemNode(id: 'li1');
      expect(node.spaceAfter, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — constructor with spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('ListItemNode constructor with spaceBefore/spaceAfter', () {
    test('spaceBefore is set correctly', () {
      final node = ListItemNode(id: 'li1', spaceBefore: 8.0);
      expect(node.spaceBefore, 8.0);
    });

    test('spaceAfter is set correctly', () {
      final node = ListItemNode(id: 'li1', spaceAfter: 16.0);
      expect(node.spaceAfter, 16.0);
    });

    test('both spaceBefore and spaceAfter can be set together', () {
      final node = ListItemNode(id: 'li1', spaceBefore: 4.0, spaceAfter: 12.0);
      expect(node.spaceBefore, 4.0);
      expect(node.spaceAfter, 12.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — copyWith with spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('ListItemNode copyWith spaceBefore/spaceAfter', () {
    test('copyWith replaces spaceBefore', () {
      final node = ListItemNode(id: 'li1', spaceBefore: 8.0);
      final copy = node.copyWith(spaceBefore: 16.0);
      expect(copy.spaceBefore, 16.0);
    });

    test('copyWith preserves spaceBefore when not specified', () {
      final node = ListItemNode(id: 'li1', spaceBefore: 8.0);
      final copy = node.copyWith(id: 'li2');
      expect(copy.spaceBefore, 8.0);
    });

    test('copyWith replaces spaceAfter', () {
      final node = ListItemNode(id: 'li1', spaceAfter: 12.0);
      final copy = node.copyWith(spaceAfter: 24.0);
      expect(copy.spaceAfter, 24.0);
    });

    test('copyWith preserves spaceAfter when not specified', () {
      final node = ListItemNode(id: 'li1', spaceAfter: 12.0);
      final copy = node.copyWith(id: 'li2');
      expect(copy.spaceAfter, 12.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — equality with spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('ListItemNode equality with spaceBefore/spaceAfter', () {
    test('unequal when spaceBefore differs', () {
      final a = ListItemNode(id: 'li1', spaceBefore: 8.0);
      final b = ListItemNode(id: 'li1', spaceBefore: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when spaceAfter differs', () {
      final a = ListItemNode(id: 'li1', spaceAfter: 8.0);
      final b = ListItemNode(id: 'li1', spaceAfter: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('equal when spaceBefore and spaceAfter are both null', () {
      final a = ListItemNode(id: 'li1');
      final b = ListItemNode(id: 'li1');
      expect(a, equals(b));
    });

    test('equal when spaceBefore and spaceAfter match', () {
      final a = ListItemNode(id: 'li1', spaceBefore: 4.0, spaceAfter: 8.0);
      final b = ListItemNode(id: 'li1', spaceBefore: 4.0, spaceAfter: 8.0);
      expect(a, equals(b));
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — debugFillProperties includes spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('ListItemNode debugFillProperties with spaceBefore/spaceAfter', () {
    test('debugFillProperties includes spaceBefore when non-null', () {
      final node = ListItemNode(id: 'li1', spaceBefore: 8.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'spaceBefore',
            orElse: () => throw StateError('spaceBefore property not found'),
          );
      expect(prop.value, 8.0);
    });

    test('debugFillProperties includes spaceAfter when non-null', () {
      final node = ListItemNode(id: 'li1', spaceAfter: 16.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'spaceAfter',
            orElse: () => throw StateError('spaceAfter property not found'),
          );
      expect(prop.value, 16.0);
    });

    test('debugFillProperties spaceBefore value is null when not set', () {
      final node = ListItemNode(id: 'li1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'spaceBefore');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });

    test('debugFillProperties spaceAfter value is null when not set', () {
      final node = ListItemNode(id: 'li1');
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
  // ListItemNode — indentLeft default value
  // ---------------------------------------------------------------------------
  group('ListItemNode indentLeft default', () {
    test('indentLeft defaults to null', () {
      final node = ListItemNode(id: 'li1');
      expect(node.indentLeft, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — indentRight default value
  // ---------------------------------------------------------------------------
  group('ListItemNode indentRight default', () {
    test('indentRight defaults to null', () {
      final node = ListItemNode(id: 'li1');
      expect(node.indentRight, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — constructor with indent fields
  // ---------------------------------------------------------------------------
  group('ListItemNode constructor with indent fields', () {
    test('indentLeft is set correctly', () {
      final node = ListItemNode(id: 'li1', indentLeft: 16.0);
      expect(node.indentLeft, 16.0);
    });

    test('indentRight is set correctly', () {
      final node = ListItemNode(id: 'li1', indentRight: 8.0);
      expect(node.indentRight, 8.0);
    });

    test('both indentLeft and indentRight can be set together', () {
      final node = ListItemNode(id: 'li1', indentLeft: 16.0, indentRight: 8.0);
      expect(node.indentLeft, 16.0);
      expect(node.indentRight, 8.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — copyWith with indent fields
  // ---------------------------------------------------------------------------
  group('ListItemNode copyWith indent fields', () {
    test('copyWith replaces indentLeft', () {
      final node = ListItemNode(id: 'li1', indentLeft: 8.0);
      final copy = node.copyWith(indentLeft: 16.0);
      expect(copy.indentLeft, 16.0);
    });

    test('copyWith preserves indentLeft when not specified', () {
      final node = ListItemNode(id: 'li1', indentLeft: 8.0);
      final copy = node.copyWith(id: 'li2');
      expect(copy.indentLeft, 8.0);
    });

    test('copyWith replaces indentRight', () {
      final node = ListItemNode(id: 'li1', indentRight: 8.0);
      final copy = node.copyWith(indentRight: 16.0);
      expect(copy.indentRight, 16.0);
    });

    test('copyWith preserves indentRight when not specified', () {
      final node = ListItemNode(id: 'li1', indentRight: 8.0);
      final copy = node.copyWith(id: 'li2');
      expect(copy.indentRight, 8.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — equality with indent fields
  // ---------------------------------------------------------------------------
  group('ListItemNode equality with indent fields', () {
    test('equal when all indent fields are both null', () {
      final a = ListItemNode(id: 'li1');
      final b = ListItemNode(id: 'li1');
      expect(a, equals(b));
    });

    test('equal when indent fields match', () {
      final a = ListItemNode(id: 'li1', indentLeft: 16.0, indentRight: 8.0);
      final b = ListItemNode(id: 'li1', indentLeft: 16.0, indentRight: 8.0);
      expect(a, equals(b));
    });

    test('unequal when indentLeft differs', () {
      final a = ListItemNode(id: 'li1', indentLeft: 8.0);
      final b = ListItemNode(id: 'li1', indentLeft: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when indentRight differs', () {
      final a = ListItemNode(id: 'li1', indentRight: 4.0);
      final b = ListItemNode(id: 'li1', indentRight: 8.0);
      expect(a, isNot(equals(b)));
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — hashCode with indent fields
  // ---------------------------------------------------------------------------
  group('ListItemNode hashCode with indent fields', () {
    test('hashCode matches for equal nodes with same indent fields', () {
      final a = ListItemNode(id: 'li1', indentLeft: 16.0, indentRight: 8.0);
      final b = ListItemNode(id: 'li1', indentLeft: 16.0, indentRight: 8.0);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode differs when indentLeft differs', () {
      final a = ListItemNode(id: 'li1', indentLeft: 8.0);
      final b = ListItemNode(id: 'li1', indentLeft: 16.0);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode — debugFillProperties includes indent fields
  // ---------------------------------------------------------------------------
  group('ListItemNode debugFillProperties with indent fields', () {
    test('debugFillProperties includes indentLeft when non-null', () {
      final node = ListItemNode(id: 'li1', indentLeft: 16.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'indentLeft',
            orElse: () => throw StateError('indentLeft property not found'),
          );
      expect(prop.value, 16.0);
    });

    test('debugFillProperties includes indentRight when non-null', () {
      final node = ListItemNode(id: 'li1', indentRight: 8.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'indentRight',
            orElse: () => throw StateError('indentRight property not found'),
          );
      expect(prop.value, 8.0);
    });

    test('debugFillProperties indentLeft value is null when not set', () {
      final node = ListItemNode(id: 'li1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'indentLeft');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });
  });
}
