import 'package:editable_document/src/model/block_alignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlockAlignment', () {
    test('has exactly four values', () {
      expect(BlockAlignment.values, hasLength(4));
    });

    test('values list is in the correct order', () {
      expect(BlockAlignment.values, [
        BlockAlignment.start,
        BlockAlignment.center,
        BlockAlignment.end,
        BlockAlignment.stretch,
      ]);
    });

    test('start value exists with correct name', () {
      expect(BlockAlignment.start.name, 'start');
    });

    test('center value exists with correct name', () {
      expect(BlockAlignment.center.name, 'center');
    });

    test('end value exists with correct name', () {
      expect(BlockAlignment.end.name, 'end');
    });

    test('stretch value exists with correct name', () {
      expect(BlockAlignment.stretch.name, 'stretch');
    });

    test('values are distinct', () {
      final values = BlockAlignment.values;
      final unique = values.toSet();
      expect(unique, hasLength(values.length));
    });
  });
}
