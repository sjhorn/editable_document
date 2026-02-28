import 'dart:ui' show TextAffinity;

import 'package:editable_document/src/model/node_position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextNodePosition', () {
    test('creation with offset uses downstream affinity by default', () {
      const pos = TextNodePosition(offset: 5);
      expect(pos.offset, 5);
      expect(pos.affinity, TextAffinity.downstream);
    });

    test('creation with explicit upstream affinity', () {
      const pos = TextNodePosition(offset: 3, affinity: TextAffinity.upstream);
      expect(pos.offset, 3);
      expect(pos.affinity, TextAffinity.upstream);
    });

    group('copyWith', () {
      test('copy changing offset leaves affinity unchanged', () {
        const original = TextNodePosition(offset: 2, affinity: TextAffinity.upstream);
        final copy = original.copyWith(offset: 10);
        expect(copy.offset, 10);
        expect(copy.affinity, TextAffinity.upstream);
      });

      test('copy changing affinity leaves offset unchanged', () {
        const original = TextNodePosition(offset: 7);
        final copy = original.copyWith(affinity: TextAffinity.upstream);
        expect(copy.offset, 7);
        expect(copy.affinity, TextAffinity.upstream);
      });

      test('copy with no arguments returns identical values', () {
        const original = TextNodePosition(offset: 4, affinity: TextAffinity.downstream);
        final copy = original.copyWith();
        expect(copy.offset, 4);
        expect(copy.affinity, TextAffinity.downstream);
      });
    });

    group('equality', () {
      test('same offset and affinity are equal', () {
        const a = TextNodePosition(offset: 5);
        const b = TextNodePosition(offset: 5);
        expect(a, equals(b));
      });

      test('different offset are not equal', () {
        const a = TextNodePosition(offset: 5);
        const b = TextNodePosition(offset: 6);
        expect(a, isNot(equals(b)));
      });

      test('different affinity are not equal', () {
        const a = TextNodePosition(offset: 5, affinity: TextAffinity.downstream);
        const b = TextNodePosition(offset: 5, affinity: TextAffinity.upstream);
        expect(a, isNot(equals(b)));
      });
    });

    group('hashCode', () {
      test('equal positions have equal hash codes', () {
        const a = TextNodePosition(offset: 5, affinity: TextAffinity.downstream);
        const b = TextNodePosition(offset: 5, affinity: TextAffinity.downstream);
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains offset', () {
        const pos = TextNodePosition(offset: 42);
        expect(pos.toString(), contains('42'));
      });

      test('contains affinity', () {
        const pos = TextNodePosition(offset: 0, affinity: TextAffinity.upstream);
        expect(pos.toString(), contains('upstream'));
      });
    });
  });

  group('BinaryNodePosition', () {
    test('upstream type has upstream BinaryNodePositionType', () {
      const pos = BinaryNodePosition(BinaryNodePositionType.upstream);
      expect(pos.type, BinaryNodePositionType.upstream);
    });

    test('downstream type has downstream BinaryNodePositionType', () {
      const pos = BinaryNodePosition(BinaryNodePositionType.downstream);
      expect(pos.type, BinaryNodePositionType.downstream);
    });

    group('named constructors', () {
      test('BinaryNodePosition.upstream() creates upstream position', () {
        const pos = BinaryNodePosition.upstream();
        expect(pos.type, BinaryNodePositionType.upstream);
      });

      test('BinaryNodePosition.downstream() creates downstream position', () {
        const pos = BinaryNodePosition.downstream();
        expect(pos.type, BinaryNodePositionType.downstream);
      });
    });

    group('equality', () {
      test('same type are equal', () {
        const a = BinaryNodePosition.upstream();
        const b = BinaryNodePosition.upstream();
        expect(a, equals(b));
      });

      test('different types are not equal', () {
        const a = BinaryNodePosition.upstream();
        const b = BinaryNodePosition.downstream();
        expect(a, isNot(equals(b)));
      });
    });

    group('hashCode', () {
      test('equal positions have equal hash codes', () {
        const a = BinaryNodePosition.downstream();
        const b = BinaryNodePosition.downstream();
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('upstream toString is readable', () {
        const pos = BinaryNodePosition.upstream();
        expect(pos.toString(), contains('upstream'));
      });

      test('downstream toString is readable', () {
        const pos = BinaryNodePosition.downstream();
        expect(pos.toString(), contains('downstream'));
      });
    });
  });

  group('NodePosition polymorphism', () {
    test('TextNodePosition is a NodePosition', () {
      const NodePosition pos = TextNodePosition(offset: 0);
      expect(pos, isA<NodePosition>());
    });

    test('BinaryNodePosition is a NodePosition', () {
      const NodePosition pos = BinaryNodePosition.upstream();
      expect(pos, isA<NodePosition>());
    });

    test('both types can be stored in the same list', () {
      final List<NodePosition> positions = [
        const TextNodePosition(offset: 1),
        const BinaryNodePosition.downstream(),
        const TextNodePosition(offset: 99, affinity: TextAffinity.upstream),
        const BinaryNodePosition.upstream(),
      ];
      expect(positions, hasLength(4));
      expect(positions[0], isA<TextNodePosition>());
      expect(positions[1], isA<BinaryNodePosition>());
    });
  });
}
