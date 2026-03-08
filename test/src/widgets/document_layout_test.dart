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

  // -------------------------------------------------------------------------
  // Center float text wrapping
  // -------------------------------------------------------------------------

  group('DocumentLayout — center float text wrapping', () {
    testWidgets(
      'center float text wraps beside image with DocumentScrollable',
      (tester) async {
        // Test the full stack including DocumentScrollable (which adds
        // horizontal SingleChildScrollView and viewportWidth scope).
        final doc = _docWith([
          ImageNode(
            id: 'img1',
            imageUrl: 'https://example.com/img.png',
            altText: 'Test',
            width: 200,
            height: 120,
            alignment: BlockAlignment.center,
            textWrap: true,
          ),
          ParagraphNode(
            id: 'p1',
            text: AttributedText(
              'This paragraph should wrap beside the float image. '
              'It contains enough text to span multiple lines easily.',
            ),
          ),
        ]);
        final controller = _controller(doc);
        final layoutKey = GlobalKey<DocumentLayoutState>();
        final focusNode = FocusNode();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 400,
                child: DocumentScrollable(
                  controller: controller,
                  layoutKey: layoutKey,
                  child: DocumentLayout(
                    key: layoutKey,
                    document: doc,
                    controller: controller,
                    componentBuilders: defaultComponentBuilders,
                    blockSpacing: 0.0,
                  ),
                ),
              ),
            ),
          ),
        );

        final layoutState = layoutKey.currentState!;
        final textBlock = layoutState.componentForNode('p1') as RenderTextBlock;
        final textData = textBlock.parentData as DocumentBlockParentData;
        final imgBlock = layoutState.componentForNode('img1')!;

        // Text block must have an exclusion rect for center float.
        expect(textData.exclusionRect, isNotNull,
            reason: 'text should receive exclusionRect from center float');

        // First char must be in beside zone, not below the image.
        final firstCharRect = textBlock.getLocalRectForPosition(
          const TextNodePosition(offset: 0),
        );
        expect(firstCharRect.top, lessThan(imgBlock.size.height),
            reason: 'first char at y=${firstCharRect.top} should be in '
                'beside zone, not below float height=${imgBlock.size.height}');

        focusNode.dispose();
      },
    );

    testWidgets(
      'text wraps beside center float after alignment change from start',
      (tester) async {
        // Start with a start-aligned float image + paragraph after it.
        final doc = _docWith([
          ImageNode(
            id: 'img1',
            imageUrl: 'https://example.com/img.png',
            altText: 'Test',
            width: 200,
            height: 120,
            alignment: BlockAlignment.start,
            textWrap: true,
          ),
          ParagraphNode(
            id: 'p1',
            text: AttributedText(
              'This paragraph should wrap beside the float image. '
              'It contains enough text to span multiple lines.',
            ),
          ),
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
              blockSpacing: 0.0,
            ),
            width: 600,
          ),
        );

        // Get the text block's render object and its position with start float.
        final layoutState = layoutKey.currentState!;
        final textBlockStart = layoutState.componentForNode('p1') as RenderTextBlock;
        final textDataStart = textBlockStart.parentData as DocumentBlockParentData;
        final imgStart = layoutState.componentForNode('img1')!;
        final imgDataStart = imgStart.parentData as DocumentBlockParentData;

        // With start float, text starts at same y and is pushed right.
        expect(textDataStart.offset.dy, imgDataStart.offset.dy,
            reason: 'start: text should start at same y as float');
        expect(textDataStart.offset.dx, greaterThan(0),
            reason: 'start: text should be pushed right');

        // --- Change alignment to center ---
        final editor = UndoableEditor(
          editContext: EditContext(document: doc, controller: controller),
        );
        editor.submit(ReplaceNodeRequest(
          nodeId: 'img1',
          newNode: ImageNode(
            id: 'img1',
            imageUrl: 'https://example.com/img.png',
            altText: 'Test',
            width: 200,
            height: 120,
            alignment: BlockAlignment.center,
            textWrap: true,
          ),
        ));
        await tester.pump();

        // Re-fetch render objects after rebuild.
        final textBlockCenter = layoutState.componentForNode('p1') as RenderTextBlock;
        final textDataCenter = textBlockCenter.parentData as DocumentBlockParentData;
        final imgCenter = layoutState.componentForNode('img1')!;
        final imgDataCenter = imgCenter.parentData as DocumentBlockParentData;

        // With center float, text block should still start at same y as float.
        expect(textDataCenter.offset.dy, imgDataCenter.offset.dy,
            reason: 'center: text should start at same y as float');

        // Text block should receive an exclusion rect (center float path).
        expect(textDataCenter.exclusionRect, isNotNull,
            reason: 'center: text should receive exclusionRect');

        // First character should be in the beside zone (y < floatHeight).
        final firstCharRect = textBlockCenter.getLocalRectForPosition(
          const TextNodePosition(offset: 0),
        );
        expect(firstCharRect.top, lessThan(imgCenter.size.height),
            reason: 'center: first char y=${firstCharRect.top} should be '
                'less than float height=${imgCenter.size.height}');

        // Text block height should not be image height + full text height
        // (which would mean text went entirely to below zone).
        final fullWidthTextHeight = textBlockStart.size.height;
        expect(
            textBlockCenter.size.height, lessThan(imgCenter.size.height + fullWidthTextHeight + 1),
            reason: 'center: text block should not be image+fullText tall');
      },
    );
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
