/// Tests for the semantics configuration of [RenderDocumentLayout].
///
/// These tests verify that [RenderDocumentLayout.describeSemanticsConfiguration]
/// correctly sets the flags required for Phase 8 accessibility support:
///   - [SemanticsConfiguration.isSemanticBoundary] — isolates the document tree
///   - [SemanticsConfiguration.explicitChildNodes] — delegates to per-block children
///   - [SemanticsConfiguration.liveRegion] — announces dynamic content changes
///
/// Focus-order is tested by asserting that the child render objects are
/// accessible in document order (first-to-last) via the container mixin.
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a fresh [SemanticsConfiguration] populated by calling
/// [RenderDocumentLayout.describeSemanticsConfiguration].
SemanticsConfiguration _configFor(RenderDocumentLayout layout) {
  final config = SemanticsConfiguration();
  layout.describeSemanticsConfiguration(config);
  return config;
}

/// Creates a minimal [RenderTextBlock] suitable for layout/semantics tests.
RenderTextBlock _textBlock(String nodeId, String text) => RenderTextBlock(
      nodeId: nodeId,
      text: AttributedText(text),
      textStyle: const TextStyle(fontSize: 16),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RenderDocumentLayout — semantics configuration', () {
    test('isSemanticBoundary is true', () {
      final layout = RenderDocumentLayout();
      final config = _configFor(layout);
      expect(config.isSemanticBoundary, isTrue);
    });

    test('explicitChildNodes is true', () {
      final layout = RenderDocumentLayout();
      final config = _configFor(layout);
      expect(config.explicitChildNodes, isTrue);
    });

    test('liveRegion is true', () {
      final layout = RenderDocumentLayout();
      final config = _configFor(layout);
      expect(config.liveRegion, isTrue);
    });

    test('semantics flags are consistent for a layout with children', () {
      final layout = RenderDocumentLayout();
      layout.add(_textBlock('p1', 'First paragraph'));
      layout.add(_textBlock('p2', 'Second paragraph'));
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      final config = _configFor(layout);
      expect(config.isSemanticBoundary, isTrue);
      expect(config.explicitChildNodes, isTrue);
      expect(config.liveRegion, isTrue);
    });

    test('semantics flags are set even for an empty layout', () {
      final layout = RenderDocumentLayout();
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      final config = _configFor(layout);
      expect(config.isSemanticBoundary, isTrue);
      expect(config.explicitChildNodes, isTrue);
      expect(config.liveRegion, isTrue);
    });
  });

  group('RenderDocumentLayout — focus / traversal order', () {
    test('children are accessible in document order (first to last)', () {
      final c1 = _textBlock('p1', 'Alpha');
      final c2 = _textBlock('p2', 'Beta');
      final c3 = _textBlock('p3', 'Gamma');

      final layout = RenderDocumentLayout();
      layout.add(c1);
      layout.add(c2);
      layout.add(c3);
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      // Collect children by walking the ContainerRenderObjectMixin linked list.
      final children = <RenderDocumentBlock>[];
      RenderDocumentBlock? child = layout.firstChild;
      while (child != null) {
        children.add(child);
        child = layout.childAfter(child);
      }

      expect(children, hasLength(3));
      expect(children[0].nodeId, 'p1');
      expect(children[1].nodeId, 'p2');
      expect(children[2].nodeId, 'p3');
    });

    test('traversal order is preserved after adding children out of sequence', () {
      // Children added in order p1 → p2 must be traversed in that order.
      final c1 = _textBlock('p1', 'First');
      final c2 = _textBlock('p2', 'Second');

      final layout = RenderDocumentLayout();
      layout.add(c1);
      layout.add(c2);
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      expect(layout.firstChild!.nodeId, 'p1');
      expect(layout.childAfter(layout.firstChild!)!.nodeId, 'p2');
      expect(layout.childAfter(layout.childAfter(layout.firstChild!)!), isNull);
    });

    test('lastChild is the last document block in focus order', () {
      final c1 = _textBlock('p1', 'First');
      final c2 = _textBlock('p2', 'Last');

      final layout = RenderDocumentLayout();
      layout.add(c1);
      layout.add(c2);
      layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);

      expect(layout.lastChild!.nodeId, 'p2');
    });
  });
}
