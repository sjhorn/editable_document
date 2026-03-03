/// Semantics tests for [RenderImageBlock].
///
/// Verifies that [RenderImageBlock.describeSemanticsConfiguration] produces
/// the correct [SemanticsConfiguration] for assistive technologies.
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RenderImageBlock semantics — isImage flag', () {
    test('describeSemanticsConfiguration sets isImage to true', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      final config = SemanticsConfiguration();

      block.describeSemanticsConfiguration(config);

      expect(config.isImage, isTrue);
    });
  });

  group('RenderImageBlock semantics — isSemanticBoundary', () {
    test('describeSemanticsConfiguration sets isSemanticBoundary to true', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      final config = SemanticsConfiguration();

      block.describeSemanticsConfiguration(config);

      expect(config.isSemanticBoundary, isTrue);
    });
  });

  group('RenderImageBlock semantics — label from altText', () {
    test('label defaults to "Image" when altText is null', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      final config = SemanticsConfiguration();

      block.describeSemanticsConfiguration(config);

      expect(config.label, 'Image');
    });

    test('label uses altText when altText is provided at construction', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        altText: 'A scenic mountain vista',
      );
      final config = SemanticsConfiguration();

      block.describeSemanticsConfiguration(config);

      expect(config.label, 'A scenic mountain vista');
    });

    test('label uses updated altText after setter is called', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      block.altText = 'Logo';
      final config = SemanticsConfiguration();

      block.describeSemanticsConfiguration(config);

      expect(config.label, 'Logo');
    });

    test('label reverts to "Image" when altText is cleared to null', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        altText: 'Initial description',
      );
      block.altText = null;
      final config = SemanticsConfiguration();

      block.describeSemanticsConfiguration(config);

      expect(config.label, 'Image');
    });

    test('empty string altText is used as-is rather than falling back to "Image"', () {
      final block = RenderImageBlock(nodeId: 'img-1', altText: '');
      final config = SemanticsConfiguration();

      block.describeSemanticsConfiguration(config);

      // An empty string is a valid (non-null) altText.
      expect(config.label, '');
    });
  });

  group('RenderImageBlock semantics — altText property', () {
    test('altText getter returns null by default', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      expect(block.altText, isNull);
    });

    test('altText getter returns the value set at construction', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        altText: 'Photo of a cat',
      );
      expect(block.altText, 'Photo of a cat');
    });

    test('altText setter updates the stored value', () {
      final block = RenderImageBlock(nodeId: 'img-1');
      block.altText = 'New description';
      expect(block.altText, 'New description');
    });

    test('altText setter is idempotent when value is unchanged', () {
      final block = RenderImageBlock(nodeId: 'img-1', altText: 'Same');
      // Attaching is required to call markNeedsSemanticsUpdate without error.
      final pipelineOwner = PipelineOwner();
      block.attach(pipelineOwner);

      // Calling the setter with the same value must not throw.
      expect(() => block.altText = 'Same', returnsNormally);
      expect(block.altText, 'Same');
    });

    test('altText setter triggers semantics update when value changes', () {
      final block = RenderImageBlock(nodeId: 'img-1', altText: 'Before');
      final pipelineOwner = PipelineOwner();
      block.attach(pipelineOwner);

      // Changing the value must not throw and must update the stored value.
      block.altText = 'After';
      expect(block.altText, 'After');
    });
  });

  group('RenderImageBlock semantics — debugFillProperties', () {
    test('altText appears in diagnostic properties when set', () {
      final block = RenderImageBlock(
        nodeId: 'img-1',
        altText: 'Mountain photo',
      );
      final builder = DiagnosticPropertiesBuilder();
      block.debugFillProperties(builder);

      final names = builder.properties.map((p) => p.name).toList();
      expect(names, contains('altText'));
    });
  });
}
