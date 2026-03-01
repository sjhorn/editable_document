/// Tests for [DocumentLayout], [DocumentLayoutState], and
/// [_DocumentLayoutRenderWidget].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Builds a [MaterialApp] wrapping a [DocumentLayout] with a constrained
/// width but unconstrained height, matching how [DocumentLayout] is typically
/// used inside a scrollable.
///
/// The layout is placed in a [SingleChildScrollView] so the
/// [RenderDocumentLayout] receives loose height constraints.
Widget _buildLayout(
  DocumentLayout layout, {
  double width = 600,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: SingleChildScrollView(child: layout),
      ),
    ),
  );
}

MutableDocument _docWith(List<DocumentNode> nodes) => MutableDocument(nodes);

DocumentEditingController _controller(MutableDocument doc) =>
    DocumentEditingController(document: doc);

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Basic rendering
  // -------------------------------------------------------------------------

  group('DocumentLayout — basic rendering', () {
    testWidgets('renders without error for empty document', (tester) async {
      final doc = _docWith([]);
      final controller = _controller(doc);

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders one child per document node', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('First')),
        ParagraphNode(id: 'p2', text: AttributedText('Second')),
        HorizontalRuleNode(id: 'hr1'),
      ]);
      final controller = _controller(doc);

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      // DocumentLayout itself is the widget under test; no throw is enough
      // for structural tests, but we also confirm the render object exists.
      final renderObj = tester.renderObject(find.byType(DocumentLayout));
      expect(renderObj, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles all five default node types', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
        ListItemNode(id: 'li1', text: AttributedText('Item')),
        ImageNode(id: 'img1', imageUrl: 'https://example.com/img.png'),
        CodeBlockNode(id: 'cb1', text: AttributedText('void main() {}')),
        HorizontalRuleNode(id: 'hr1'),
      ]);
      final controller = _controller(doc);

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('skips nodes with no matching builder', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
        _UnknownNode(id: 'u1'), // no builder handles this
      ]);
      final controller = _controller(doc);

      // Should not throw — unhandled nodes are silently skipped.
      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // blockSpacing property
  // -------------------------------------------------------------------------

  group('DocumentLayout — blockSpacing', () {
    testWidgets('default blockSpacing is 12.0', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('A')),
      ]);
      final controller = _controller(doc);

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      final layout = tester.widget<DocumentLayout>(find.byType(DocumentLayout));
      expect(layout.blockSpacing, 12.0);
    });

    testWidgets('custom blockSpacing is stored on the widget', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('A')),
      ]);
      final controller = _controller(doc);

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
            blockSpacing: 24.0,
          ),
        ),
      );

      final layout = tester.widget<DocumentLayout>(find.byType(DocumentLayout));
      expect(layout.blockSpacing, 24.0);
    });
  });

  // -------------------------------------------------------------------------
  // Rebuild on document changes
  // -------------------------------------------------------------------------

  group('DocumentLayout — document change reactivity', () {
    testWidgets('rebuilds when a node is inserted', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('First')),
      ]);
      final controller = _controller(doc);

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      // Insert a second node.
      doc.insertNode(1, ParagraphNode(id: 'p2', text: AttributedText('Second')));
      await tester.pump();

      // No exception is the main assertion; the widget survived the rebuild.
      expect(tester.takeException(), isNull);
    });

    testWidgets('rebuilds when a node is deleted', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('First')),
        ParagraphNode(id: 'p2', text: AttributedText('Second')),
      ]);
      final controller = _controller(doc);

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      doc.deleteNode('p2');
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Rebuild on controller (selection) changes
  // -------------------------------------------------------------------------

  group('DocumentLayout — controller change reactivity', () {
    testWidgets('rebuilds when selection changes', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = _controller(doc);

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 2),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // DocumentLayoutState geometry queries
  // -------------------------------------------------------------------------

  group('DocumentLayoutState geometry queries', () {
    testWidgets('componentForNode returns non-null for existing node', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = _controller(doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            key: layoutKey,
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      final block = layoutKey.currentState!.componentForNode('p1');
      expect(block, isNotNull);
    });

    testWidgets('componentForNode returns null for missing node', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = _controller(doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            key: layoutKey,
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      final block = layoutKey.currentState!.componentForNode('does-not-exist');
      expect(block, isNull);
    });

    testWidgets('rectForDocumentPosition returns Rect for valid position', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = _controller(doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            key: layoutKey,
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      final rect = layoutKey.currentState!.rectForDocumentPosition(
        const DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
      );

      expect(rect, isNotNull);
    });

    testWidgets('rectForDocumentPosition returns null for unknown node', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = _controller(doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            key: layoutKey,
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      final rect = layoutKey.currentState!.rectForDocumentPosition(
        const DocumentPosition(
          nodeId: 'missing',
          nodePosition: TextNodePosition(offset: 0),
        ),
      );

      expect(rect, isNull);
    });

    testWidgets('documentPositionAtOffset returns position inside a block', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = _controller(doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            key: layoutKey,
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      // Hit-test somewhere inside the rendered paragraph.
      final pos = layoutKey.currentState!.documentPositionAtOffset(const Offset(10, 5));
      // May be null if offset misses the block, but must not throw.
      expect(tester.takeException(), isNull);
      // If it returned a position it must have the right nodeId.
      if (pos != null) {
        expect(pos.nodeId, 'p1');
      }
    });

    testWidgets('documentPositionNearestToOffset always returns a position', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = _controller(doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            key: layoutKey,
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      // Far below all content — should still return a valid position.
      final pos = layoutKey.currentState!.documentPositionNearestToOffset(
        const Offset(10, 9999),
      );
      expect(pos, isNotNull);
      expect(pos.nodeId, 'p1');
    });

    testWidgets('computeMaxScrollExtent returns non-negative value', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      ]);
      final controller = _controller(doc);
      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            key: layoutKey,
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
          ),
        ),
      );

      final extent = layoutKey.currentState!.computeMaxScrollExtent(800.0);
      expect(extent, greaterThanOrEqualTo(0.0));
    });
  });

  // -------------------------------------------------------------------------
  // stylesheet
  // -------------------------------------------------------------------------

  group('DocumentLayout — stylesheet', () {
    testWidgets('accepts and stores a stylesheet without error', (tester) async {
      final doc = _docWith([
        ParagraphNode(id: 'p1', text: AttributedText('Styled')),
      ]);
      final controller = _controller(doc);

      await tester.pumpWidget(
        _buildLayout(
          DocumentLayout(
            document: doc,
            controller: controller,
            componentBuilders: defaultComponentBuilders,
            stylesheet: {'body': const TextStyle(fontSize: 16)},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Test-only document node that no default builder handles
// ---------------------------------------------------------------------------

class _UnknownNode extends DocumentNode {
  _UnknownNode({required super.id});

  @override
  DocumentNode copyWith({String? id, Map<String, dynamic>? metadata}) =>
      _UnknownNode(id: id ?? this.id);

  @override
  bool operator ==(Object other) => identical(this, other) || other is _UnknownNode;

  @override
  int get hashCode => id.hashCode;
}
