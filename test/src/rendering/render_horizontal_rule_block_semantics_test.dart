/// Semantics tests for [RenderHorizontalRuleBlock].
///
/// Verifies that [RenderHorizontalRuleBlock.describeSemanticsConfiguration]
/// produces the correct [SemanticsConfiguration] for assistive technologies.
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RenderHorizontalRuleBlock semantics — isSemanticBoundary', () {
    test('describeSemanticsConfiguration sets isSemanticBoundary to true', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      final config = SemanticsConfiguration();

      block.describeSemanticsConfiguration(config);

      expect(config.isSemanticBoundary, isTrue);
    });
  });

  group('RenderHorizontalRuleBlock semantics — label', () {
    test('describeSemanticsConfiguration sets label to "Horizontal rule"', () {
      final block = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      final config = SemanticsConfiguration();

      block.describeSemanticsConfiguration(config);

      expect(config.label, 'Horizontal rule');
    });

    test('label is consistent regardless of visual properties', () {
      final block = RenderHorizontalRuleBlock(
        nodeId: 'hr-2',
        color: const Color(0xFF000000),
        thickness: 4.0,
        verticalPadding: 16.0,
      );
      final config = SemanticsConfiguration();

      block.describeSemanticsConfiguration(config);

      expect(config.label, 'Horizontal rule');
    });
  });

  group('RenderHorizontalRuleBlock semantics — multiple instances', () {
    test('each instance produces its own independent SemanticsConfiguration', () {
      final block1 = RenderHorizontalRuleBlock(nodeId: 'hr-1');
      final block2 = RenderHorizontalRuleBlock(nodeId: 'hr-2');

      final config1 = SemanticsConfiguration();
      final config2 = SemanticsConfiguration();

      block1.describeSemanticsConfiguration(config1);
      block2.describeSemanticsConfiguration(config2);

      expect(config1.label, 'Horizontal rule');
      expect(config2.label, 'Horizontal rule');
      expect(config1.isSemanticBoundary, isTrue);
      expect(config2.isSemanticBoundary, isTrue);
    });
  });
}
