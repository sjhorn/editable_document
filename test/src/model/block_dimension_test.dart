/// Tests for [BlockDimension], [PixelDimension], and [PercentDimension].
library;

import 'package:editable_document/src/model/block_dimension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // PixelDimension — constructor and value
  // ---------------------------------------------------------------------------
  group('PixelDimension constructor', () {
    test('stores value', () {
      const dim = PixelDimension(400.0);
      expect(dim.value, 400.0);
    });

    test('factory BlockDimension.pixels creates PixelDimension', () {
      const dim = BlockDimension.pixels(300.0);
      expect(dim, isA<PixelDimension>());
      expect((dim as PixelDimension).value, 300.0);
    });
  });

  // ---------------------------------------------------------------------------
  // PercentDimension — constructor and value
  // ---------------------------------------------------------------------------
  group('PercentDimension constructor', () {
    test('stores value', () {
      const dim = PercentDimension(0.5);
      expect(dim.value, 0.5);
    });

    test('factory BlockDimension.percent creates PercentDimension', () {
      const dim = BlockDimension.percent(0.75);
      expect(dim, isA<PercentDimension>());
      expect((dim as PercentDimension).value, 0.75);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockDimension.resolve — static method
  // ---------------------------------------------------------------------------
  group('BlockDimension.resolve', () {
    test('resolves PixelDimension directly (returns value)', () {
      const dim = BlockDimension.pixels(400.0);
      expect(BlockDimension.resolve(dim, 800.0), 400.0);
    });

    test('resolves PercentDimension by multiplying by referenceSize', () {
      const dim = BlockDimension.percent(0.5);
      expect(BlockDimension.resolve(dim, 600.0), 300.0);
    });

    test('resolves null to null', () {
      expect(BlockDimension.resolve(null, 800.0), isNull);
    });

    test('PercentDimension(1.0) resolves to full reference size', () {
      const dim = BlockDimension.percent(1.0);
      expect(BlockDimension.resolve(dim, 1000.0), 1000.0);
    });

    test('PercentDimension(0.0) resolves to zero', () {
      const dim = BlockDimension.percent(0.0);
      expect(BlockDimension.resolve(dim, 800.0), 0.0);
    });

    test('PixelDimension ignores referenceSize', () {
      const dim = BlockDimension.pixels(250.0);
      expect(BlockDimension.resolve(dim, 100.0), 250.0);
      expect(BlockDimension.resolve(dim, 9999.0), 250.0);
    });
  });

  // ---------------------------------------------------------------------------
  // Equality
  // ---------------------------------------------------------------------------
  group('PixelDimension equality', () {
    test('two PixelDimensions with same value are equal', () {
      const a = PixelDimension(400.0);
      const b = PixelDimension(400.0);
      expect(a, equals(b));
    });

    test('two PixelDimensions with different values are not equal', () {
      const a = PixelDimension(400.0);
      const b = PixelDimension(800.0);
      expect(a, isNot(equals(b)));
    });

    test('identical PixelDimension equals itself', () {
      const dim = PixelDimension(100.0);
      expect(dim, equals(dim));
    });
  });

  group('PercentDimension equality', () {
    test('two PercentDimensions with same value are equal', () {
      const a = PercentDimension(0.5);
      const b = PercentDimension(0.5);
      expect(a, equals(b));
    });

    test('two PercentDimensions with different values are not equal', () {
      const a = PercentDimension(0.5);
      const b = PercentDimension(0.75);
      expect(a, isNot(equals(b)));
    });

    test('identical PercentDimension equals itself', () {
      const dim = PercentDimension(0.25);
      expect(dim, equals(dim));
    });
  });

  group('Cross-type inequality', () {
    test('PixelDimension(0.5) != PercentDimension(0.5)', () {
      const px = PixelDimension(0.5);
      const pct = PercentDimension(0.5);
      expect(px, isNot(equals(pct)));
    });

    test('PixelDimension(1.0) != PercentDimension(1.0)', () {
      const px = PixelDimension(1.0);
      const pct = PercentDimension(1.0);
      expect(px, isNot(equals(pct)));
    });
  });

  // ---------------------------------------------------------------------------
  // hashCode — consistent with equality
  // ---------------------------------------------------------------------------
  group('hashCode', () {
    test('equal PixelDimensions have same hashCode', () {
      const a = PixelDimension(400.0);
      const b = PixelDimension(400.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equal PercentDimensions have same hashCode', () {
      const a = PercentDimension(0.5);
      const b = PercentDimension(0.5);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different PixelDimension values produce different hashCodes', () {
      const a = PixelDimension(100.0);
      const b = PixelDimension(200.0);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('different PercentDimension values produce different hashCodes', () {
      const a = PercentDimension(0.25);
      const b = PercentDimension(0.75);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  // ---------------------------------------------------------------------------
  // toString — format verification
  // ---------------------------------------------------------------------------
  group('toString', () {
    test('PixelDimension toString shows pixel value', () {
      const dim = PixelDimension(400.0);
      expect(dim.toString(), 'BlockDimension.pixels(400.0)');
    });

    test('PercentDimension toString shows percent value', () {
      const dim = PercentDimension(0.5);
      expect(dim.toString(), 'BlockDimension.percent(0.5)');
    });
  });

  // ---------------------------------------------------------------------------
  // debugFillProperties
  // ---------------------------------------------------------------------------
  group('debugFillProperties', () {
    test('PixelDimension debugFillProperties includes value', () {
      const dim = PixelDimension(640.0);
      final builder = DiagnosticPropertiesBuilder();
      dim.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'value',
            orElse: () => throw StateError('value property not found'),
          );
      expect(prop.value, 640.0);
    });

    test('PercentDimension debugFillProperties includes value', () {
      const dim = PercentDimension(0.75);
      final builder = DiagnosticPropertiesBuilder();
      dim.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'value',
            orElse: () => throw StateError('value property not found'),
          );
      expect(prop.value, 0.75);
    });
  });
}
