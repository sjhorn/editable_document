/// Extended coverage tests for [DocumentPropertyPanel].
///
/// These tests exercise every node-type branch that [DocumentPropertyPanel]
/// dispatches to, and also cover the mutation helpers (spacing, border,
/// block-alignment, text-wrap, indent, width, height) by simulating user
/// interaction with the child editors.
library;

import 'package:editable_document/src/model/attributed_text.dart';
import 'package:editable_document/src/model/block_alignment.dart';
import 'package:editable_document/src/model/block_dimension.dart';
import 'package:editable_document/src/model/blockquote_node.dart';
import 'package:editable_document/src/model/code_block_node.dart';
import 'package:editable_document/src/model/document_editing_controller.dart';
import 'package:editable_document/src/model/document_node.dart';
import 'package:editable_document/src/model/document_position.dart';
import 'package:editable_document/src/model/document_selection.dart';
import 'package:editable_document/src/model/edit_request.dart';
import 'package:editable_document/src/model/horizontal_rule_node.dart';
import 'package:editable_document/src/model/image_node.dart';
import 'package:editable_document/src/model/list_item_node.dart';
import 'package:editable_document/src/model/mutable_document.dart';
import 'package:editable_document/src/model/node_position.dart';
import 'package:editable_document/src/model/paragraph_node.dart';
import 'package:editable_document/src/model/table_node.dart';
import 'package:editable_document/src/model/text_wrap_mode.dart';
import 'package:editable_document/src/widgets/properties/block_alignment_editor.dart';
import 'package:editable_document/src/widgets/properties/block_border_editor.dart';
import 'package:editable_document/src/widgets/properties/block_dimension_editor.dart';
import 'package:editable_document/src/widgets/properties/document_property_panel.dart';
import 'package:editable_document/src/widgets/properties/image_properties_editor.dart';
import 'package:editable_document/src/widgets/properties/indent_editor.dart';
import 'package:editable_document/src/widgets/properties/line_height_editor.dart';
import 'package:editable_document/src/widgets/properties/spacing_editor.dart';
import 'package:editable_document/src/widgets/properties/text_alignment_editor.dart';
import 'package:editable_document/src/widgets/properties/text_wrap_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(
        body: SizedBox(width: 280, height: 600, child: child),
      ),
    );

DocumentPropertyPanel _panel(
  DocumentEditingController controller, {
  void Function(EditRequest)? onRequest,
}) =>
    DocumentPropertyPanel(
      controller: controller,
      requestHandler: onRequest ?? (_) {},
      width: 280,
    );

DocumentEditingController _controllerFor(
  DocumentNode node, {
  NodePosition? position,
}) {
  final pos = position ?? const TextNodePosition(offset: 0);
  return DocumentEditingController(
    document: MutableDocument([node]),
    selection: DocumentSelection.collapsed(
      position: DocumentPosition(nodeId: node.id, nodePosition: pos),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DocumentPropertyPanel — paragraph node', () {
    test('effectiveWidth falls back to constructor width when no theme', () {
      final controller = DocumentEditingController(
        document: MutableDocument([
          ParagraphNode(id: 'p1', text: AttributedText('hi')),
        ]),
      );
      addTearDown(controller.dispose);
      final panel = DocumentPropertyPanel(
        controller: controller,
        requestHandler: _noOp,
        width: 320,
      );
      expect(panel.effectiveWidth(null), 320);
    });

    testWidgets(
        'renders TextAlignmentEditor, LineHeightEditor, SpacingEditor, '
        'BlockBorderEditor, IndentEditor', (tester) async {
      final controller = _controllerFor(
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(_panel(controller)));
      await tester.pumpAndSettle();

      expect(find.byType(DocumentPropertyPanel), findsOneWidget);
      expect(find.byType(TextAlignmentEditor), findsOneWidget);
      expect(find.byType(LineHeightEditor), findsOneWidget);
      expect(find.byType(SpacingEditor), findsOneWidget);
      expect(find.byType(BlockBorderEditor), findsOneWidget);
      expect(find.byType(IndentEditor), findsOneWidget);
      // Paragraph is NOT a container — no TextWrapEditor or BlockDimensionEditor.
      expect(find.byType(TextWrapEditor), findsNothing);
      expect(find.byType(BlockDimensionEditor), findsNothing);
      expect(find.byType(BlockAlignmentEditor), findsNothing);
    });
  });

  group('DocumentPropertyPanel — list item node', () {
    testWidgets(
        'renders TextAlignmentEditor, LineHeightEditor, SpacingEditor, '
        'BlockBorderEditor, IndentEditor (no firstLine)', (tester) async {
      final controller = _controllerFor(
        ListItemNode(
          id: 'li1',
          text: AttributedText('Item'),
          type: ListItemType.unordered,
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(_panel(controller)));
      await tester.pumpAndSettle();

      expect(find.byType(TextAlignmentEditor), findsOneWidget);
      expect(find.byType(LineHeightEditor), findsOneWidget);
      expect(find.byType(SpacingEditor), findsOneWidget);
      expect(find.byType(BlockBorderEditor), findsOneWidget);
      expect(find.byType(IndentEditor), findsOneWidget);
      expect(find.byType(TextWrapEditor), findsNothing);
    });
  });

  group('DocumentPropertyPanel — blockquote node', () {
    testWidgets('renders all text + container sections', (tester) async {
      final controller = _controllerFor(
        BlockquoteNode(id: 'bq1', text: AttributedText('Quote')),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(_panel(controller)));
      await tester.pumpAndSettle();

      expect(find.byType(TextAlignmentEditor), findsOneWidget);
      expect(find.byType(LineHeightEditor), findsOneWidget);
      expect(find.byType(SpacingEditor), findsOneWidget);
      expect(find.byType(BlockBorderEditor), findsOneWidget);
      expect(find.byType(IndentEditor), findsOneWidget);
      expect(find.byType(BlockAlignmentEditor), findsOneWidget);
      expect(find.byType(TextWrapEditor), findsOneWidget);
      expect(find.byType(BlockDimensionEditor), findsOneWidget);
    });
  });

  group('DocumentPropertyPanel — code block node', () {
    testWidgets('renders LineHeightEditor and container sections, no text align', (tester) async {
      final controller = _controllerFor(
        CodeBlockNode(id: 'cb1', text: AttributedText('print("hi");')),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(_panel(controller)));
      await tester.pumpAndSettle();

      // CodeBlockNode is isTextOrCode but NOT isText (no TextAlignmentEditor).
      expect(find.byType(TextAlignmentEditor), findsNothing);
      expect(find.byType(LineHeightEditor), findsOneWidget);
      expect(find.byType(SpacingEditor), findsOneWidget);
      expect(find.byType(BlockBorderEditor), findsOneWidget);
      // CodeBlockNode has no indent section.
      expect(find.byType(IndentEditor), findsNothing);
      expect(find.byType(BlockAlignmentEditor), findsOneWidget);
      expect(find.byType(TextWrapEditor), findsOneWidget);
      expect(find.byType(BlockDimensionEditor), findsOneWidget);
    });
  });

  group('DocumentPropertyPanel — image node', () {
    testWidgets('renders all container + image sections', (tester) async {
      final controller = _controllerFor(
        ImageNode(
          id: 'img1',
          imageUrl: 'https://example.com/photo.jpg',
        ),
        position: const BinaryNodePosition.upstream(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(_panel(controller)));
      await tester.pumpAndSettle();

      expect(find.byType(TextAlignmentEditor), findsNothing);
      expect(find.byType(LineHeightEditor), findsNothing);
      expect(find.byType(SpacingEditor), findsOneWidget);
      expect(find.byType(BlockBorderEditor), findsOneWidget);
      expect(find.byType(IndentEditor), findsNothing);
      expect(find.byType(BlockAlignmentEditor), findsOneWidget);
      expect(find.byType(TextWrapEditor), findsOneWidget);
      expect(find.byType(BlockDimensionEditor), findsOneWidget);
      expect(find.byType(ImagePropertiesEditor), findsOneWidget);
    });

    testWidgets('onPickImageFile callback forwarded to ImagePropertiesEditor', (tester) async {
      var pickCalled = false;
      final controller = _controllerFor(
        ImageNode(id: 'img2', imageUrl: 'https://example.com/a.png'),
        position: const BinaryNodePosition.upstream(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          DocumentPropertyPanel(
            controller: controller,
            requestHandler: (_) {},
            width: 280,
            onPickImageFile: () => pickCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editor = tester.widget<ImagePropertiesEditor>(
        find.byType(ImagePropertiesEditor),
      );
      expect(editor.onPickFile, isNotNull);
      editor.onPickFile!();
      expect(pickCalled, isTrue);
    });
  });

  group('DocumentPropertyPanel — horizontal rule node', () {
    testWidgets('renders container sections only, no text or indent sections', (tester) async {
      final controller = _controllerFor(
        HorizontalRuleNode(id: 'hr1'),
        position: const BinaryNodePosition.upstream(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(_panel(controller)));
      await tester.pumpAndSettle();

      expect(find.byType(TextAlignmentEditor), findsNothing);
      expect(find.byType(LineHeightEditor), findsNothing);
      expect(find.byType(SpacingEditor), findsOneWidget);
      expect(find.byType(BlockBorderEditor), findsOneWidget);
      expect(find.byType(IndentEditor), findsNothing);
      expect(find.byType(BlockAlignmentEditor), findsOneWidget);
      expect(find.byType(TextWrapEditor), findsOneWidget);
      expect(find.byType(BlockDimensionEditor), findsOneWidget);
      expect(find.byType(ImagePropertiesEditor), findsNothing);
    });
  });

  group('DocumentPropertyPanel — table node', () {
    testWidgets('renders only SpacingEditor and BlockBorderEditor', (tester) async {
      final table = TableNode(
        id: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: [
          [AttributedText('A'), AttributedText('B')],
          [AttributedText('C'), AttributedText('D')],
        ],
      );
      final controller = _controllerFor(
        table,
        position: const TableCellPosition(row: 0, col: 0, offset: 0),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(_panel(controller)));
      await tester.pumpAndSettle();

      expect(find.byType(SpacingEditor), findsOneWidget);
      expect(find.byType(BlockBorderEditor), findsOneWidget);
      // Tables have no text-editing or container-sizing properties.
      expect(find.byType(TextAlignmentEditor), findsNothing);
      expect(find.byType(IndentEditor), findsNothing);
      expect(find.byType(BlockAlignmentEditor), findsNothing);
      expect(find.byType(TextWrapEditor), findsNothing);
    });
  });

  group('DocumentPropertyPanel — no selection', () {
    testWidgets('renders SizedBox.shrink when selection is null', (tester) async {
      final controller = DocumentEditingController(
        document: MutableDocument([
          ParagraphNode(id: 'p1', text: AttributedText('Hello')),
        ]),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(_panel(controller)));
      await tester.pumpAndSettle();

      expect(find.byType(TextAlignmentEditor), findsNothing);
      expect(find.byType(SpacingEditor), findsNothing);
    });
  });

  group('DocumentPropertyPanel — mutation helpers via paragraph', () {
    testWidgets('spacing change fires ReplaceNodeRequest for ParagraphNode', (tester) async {
      final node = ParagraphNode(id: 'p1', text: AttributedText('Hi'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<SpacingEditor>(find.byType(SpacingEditor));
      editor.onSpaceBeforeChanged(8.0);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      final req = captured! as ReplaceNodeRequest;
      expect(req.nodeId, 'p1');
      expect((req.newNode as ParagraphNode).spaceBefore, 8.0);
    });

    testWidgets('spacing change fires ReplaceNodeRequest for ListItemNode', (tester) async {
      final node = ListItemNode(
        id: 'li1',
        text: AttributedText('Item'),
        type: ListItemType.ordered,
      );
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<SpacingEditor>(find.byType(SpacingEditor));
      editor.onSpaceAfterChanged(12.0);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      final req = captured! as ReplaceNodeRequest;
      expect((req.newNode as ListItemNode).spaceAfter, 12.0);
    });

    testWidgets('border change fires ReplaceNodeRequest for ParagraphNode', (tester) async {
      final node = ParagraphNode(id: 'p1', text: AttributedText('Text'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<BlockBorderEditor>(find.byType(BlockBorderEditor));
      editor.onChanged(null);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
    });

    testWidgets('indent change fires ReplaceNodeRequest for ParagraphNode', (tester) async {
      final node = ParagraphNode(id: 'p1', text: AttributedText('Text'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<IndentEditor>(find.byType(IndentEditor));
      editor.onIndentLeftChanged(16.0);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      final req = captured! as ReplaceNodeRequest;
      expect((req.newNode as ParagraphNode).indentLeft, 16.0);
    });
  });

  group('DocumentPropertyPanel — mutation helpers via image', () {
    testWidgets('block-alignment change fires ReplaceNodeRequest for ImageNode', (tester) async {
      final node = ImageNode(id: 'img1', imageUrl: 'https://example.com/x.png');
      final controller = _controllerFor(node, position: const BinaryNodePosition.upstream());
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<BlockAlignmentEditor>(find.byType(BlockAlignmentEditor));
      editor.onChanged(BlockAlignment.center);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
    });

    testWidgets('text-wrap change fires ReplaceNodeRequest for ImageNode', (tester) async {
      final node = ImageNode(id: 'img1', imageUrl: 'https://example.com/x.png');
      final controller = _controllerFor(node, position: const BinaryNodePosition.upstream());
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<TextWrapEditor>(find.byType(TextWrapEditor));
      editor.onChanged(TextWrapMode.wrap);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      final req = captured! as ReplaceNodeRequest;
      expect((req.newNode as ImageNode).textWrap, TextWrapMode.wrap);
    });

    testWidgets('width change fires ReplaceNodeRequest for ImageNode and sets alignment',
        (tester) async {
      final node = ImageNode(id: 'img1', imageUrl: 'https://example.com/x.png');
      final controller = _controllerFor(node, position: const BinaryNodePosition.upstream());
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<BlockDimensionEditor>(find.byType(BlockDimensionEditor));
      editor.onWidthChanged(const BlockDimension.pixels(400));
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      final req = captured! as ReplaceNodeRequest;
      final newNode = req.newNode as ImageNode;
      expect(newNode.width, const BlockDimension.pixels(400));
      // Default alignment is stretch; setting a width should move to start.
      expect(newNode.alignment, BlockAlignment.start);
    });

    testWidgets('height change fires ReplaceNodeRequest for ImageNode', (tester) async {
      final node = ImageNode(id: 'img1', imageUrl: 'https://example.com/x.png');
      final controller = _controllerFor(node, position: const BinaryNodePosition.upstream());
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<BlockDimensionEditor>(find.byType(BlockDimensionEditor));
      editor.onHeightChanged(const BlockDimension.pixels(300));
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      final req = captured! as ReplaceNodeRequest;
      expect((req.newNode as ImageNode).height, const BlockDimension.pixels(300));
    });
  });

  group('DocumentPropertyPanel — mutation helpers via horizontal rule', () {
    testWidgets('spacing change fires ReplaceNodeRequest for HorizontalRuleNode', (tester) async {
      final node = HorizontalRuleNode(id: 'hr1');
      final controller = _controllerFor(node, position: const BinaryNodePosition.upstream());
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<SpacingEditor>(find.byType(SpacingEditor));
      editor.onSpaceBeforeChanged(4.0);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      expect((captured! as ReplaceNodeRequest).newNode, isA<HorizontalRuleNode>());
    });

    testWidgets('block-alignment stretch fires ReplaceNodeRequest clearing dimensions',
        (tester) async {
      final node = HorizontalRuleNode(id: 'hr1');
      final controller = _controllerFor(node, position: const BinaryNodePosition.upstream());
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<BlockAlignmentEditor>(find.byType(BlockAlignmentEditor));
      editor.onChanged(BlockAlignment.stretch);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      final updated = (captured! as ReplaceNodeRequest).newNode as HorizontalRuleNode;
      expect(updated.width, isNull);
      expect(updated.height, isNull);
    });
  });

  group('DocumentPropertyPanel — mutation helpers via code block', () {
    testWidgets('spacing change fires ReplaceNodeRequest for CodeBlockNode', (tester) async {
      final node = CodeBlockNode(id: 'cb1', text: AttributedText('code'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<SpacingEditor>(find.byType(SpacingEditor));
      editor.onSpaceAfterChanged(6.0);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      expect((captured! as ReplaceNodeRequest).newNode, isA<CodeBlockNode>());
    });

    testWidgets('block-alignment stretch fires ReplaceNodeRequest for CodeBlockNode',
        (tester) async {
      final node = CodeBlockNode(id: 'cb1', text: AttributedText('code'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<BlockAlignmentEditor>(find.byType(BlockAlignmentEditor));
      editor.onChanged(BlockAlignment.stretch);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      final updated = (captured! as ReplaceNodeRequest).newNode as CodeBlockNode;
      expect(updated.width, isNull);
    });

    testWidgets('text-wrap change fires ReplaceNodeRequest for CodeBlockNode', (tester) async {
      final node = CodeBlockNode(id: 'cb1', text: AttributedText('code'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<TextWrapEditor>(find.byType(TextWrapEditor));
      editor.onChanged(TextWrapMode.behindText);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
    });

    testWidgets('width change fires ReplaceNodeRequest for CodeBlockNode', (tester) async {
      final node = CodeBlockNode(id: 'cb1', text: AttributedText('code'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<BlockDimensionEditor>(find.byType(BlockDimensionEditor));
      editor.onWidthChanged(const BlockDimension.pixels(500));
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      expect((captured! as ReplaceNodeRequest).newNode, isA<CodeBlockNode>());
    });

    testWidgets('height change fires ReplaceNodeRequest for CodeBlockNode', (tester) async {
      final node = CodeBlockNode(id: 'cb1', text: AttributedText('code'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<BlockDimensionEditor>(find.byType(BlockDimensionEditor));
      editor.onHeightChanged(const BlockDimension.pixels(200));
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
    });
  });

  group('DocumentPropertyPanel — mutation helpers via blockquote', () {
    testWidgets('spacing change fires ReplaceNodeRequest for BlockquoteNode', (tester) async {
      final node = BlockquoteNode(id: 'bq1', text: AttributedText('Quote'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<SpacingEditor>(find.byType(SpacingEditor));
      editor.onSpaceBeforeChanged(10.0);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      expect((captured! as ReplaceNodeRequest).newNode, isA<BlockquoteNode>());
    });

    testWidgets('indent change fires ReplaceNodeRequest for BlockquoteNode', (tester) async {
      final node = BlockquoteNode(id: 'bq1', text: AttributedText('Quote'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<IndentEditor>(find.byType(IndentEditor));
      editor.onIndentRightChanged(24.0);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      expect((captured! as ReplaceNodeRequest).newNode, isA<BlockquoteNode>());
    });

    testWidgets('block-alignment stretch fires ReplaceNodeRequest for BlockquoteNode',
        (tester) async {
      final node = BlockquoteNode(id: 'bq1', text: AttributedText('Quote'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<BlockAlignmentEditor>(find.byType(BlockAlignmentEditor));
      editor.onChanged(BlockAlignment.stretch);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      final updated = (captured! as ReplaceNodeRequest).newNode as BlockquoteNode;
      expect(updated.width, isNull);
    });

    testWidgets('width change fires ReplaceNodeRequest for BlockquoteNode', (tester) async {
      final node = BlockquoteNode(id: 'bq1', text: AttributedText('Quote'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<BlockDimensionEditor>(find.byType(BlockDimensionEditor));
      editor.onWidthChanged(const BlockDimension.pixels(300));
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
    });

    testWidgets('height change fires ReplaceNodeRequest for BlockquoteNode', (tester) async {
      final node = BlockquoteNode(id: 'bq1', text: AttributedText('Quote'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<BlockDimensionEditor>(find.byType(BlockDimensionEditor));
      editor.onHeightChanged(const BlockDimension.pixels(150));
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
    });

    testWidgets('text-wrap change fires ReplaceNodeRequest for BlockquoteNode', (tester) async {
      final node = BlockquoteNode(id: 'bq1', text: AttributedText('Quote'));
      final controller = _controllerFor(node);
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<TextWrapEditor>(find.byType(TextWrapEditor));
      editor.onChanged(TextWrapMode.behindText);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
    });
  });

  group('DocumentPropertyPanel — mutation helpers via table', () {
    testWidgets('spacing change fires ReplaceNodeRequest for TableNode', (tester) async {
      final node = TableNode(
        id: 't1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('A')],
        ],
      );
      final controller = _controllerFor(
        node,
        position: const TableCellPosition(row: 0, col: 0, offset: 0),
      );
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<SpacingEditor>(find.byType(SpacingEditor));
      editor.onSpaceBeforeChanged(5.0);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      expect((captured! as ReplaceNodeRequest).newNode, isA<TableNode>());
    });

    testWidgets('border change fires ReplaceNodeRequest for TableNode', (tester) async {
      final node = TableNode(
        id: 't1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('A')],
        ],
      );
      final controller = _controllerFor(
        node,
        position: const TableCellPosition(row: 0, col: 0, offset: 0),
      );
      addTearDown(controller.dispose);

      EditRequest? captured;
      await tester.pumpWidget(_wrap(_panel(controller, onRequest: (r) => captured = r)));
      await tester.pumpAndSettle();

      final editor = tester.widget<BlockBorderEditor>(find.byType(BlockBorderEditor));
      editor.onChanged(null);
      await tester.pump();

      expect(captured, isA<ReplaceNodeRequest>());
      expect((captured! as ReplaceNodeRequest).newNode, isA<TableNode>());
    });
  });
}

// ---------------------------------------------------------------------------
// Private utilities
// ---------------------------------------------------------------------------

void _noOp(EditRequest _) {}
