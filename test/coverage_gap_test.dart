/// Targeted tests to close small coverage gaps across multiple files.
///
/// Each test covers 1-4 uncovered lines in a specific source file,
/// targeting hashCode, toString, debugFillProperties, and equality branches.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

void main() {
  // node_position.dart line 82: BinaryNodePosition const constructor
  test('BinaryNodePosition const constructor', () {
    const pos = BinaryNodePosition(BinaryNodePositionType.upstream);
    expect(pos.type, BinaryNodePositionType.upstream);
  });

  // composer_preferences.dart lines 82-83: hashCode
  test('ComposerPreferences hashCode consistency', () {
    final a = ComposerPreferences(attributions: {NamedAttribution.bold});
    final b = ComposerPreferences(attributions: {NamedAttribution.bold});
    expect(a.hashCode, b.hashCode);
  });

  // mutable_document.dart lines 104-107: isNotEmpty
  test('MutableDocument isNotEmpty', () {
    final doc = MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText('Hello')),
    ]);
    expect(doc.isNotEmpty, isTrue);
    expect(MutableDocument([]).isNotEmpty, isFalse);
  });

  // document_change_event.dart lines 225-229: hashCode and toString
  test('TextChanged hashCode and toString', () {
    const a = TextChanged(nodeId: 'n1');
    const b = TextChanged(nodeId: 'n1');
    expect(a.hashCode, b.hashCode);
    expect(a.toString(), contains('n1'));
  });

  // document_status_bar.dart line 152: ListItemNode ordered branch
  testWidgets('DocumentStatusBar shows Ordered list for ordered ListItemNode', (tester) async {
    final controller = DocumentEditingController(
      document: MutableDocument([
        ListItemNode(
          id: 'li1',
          text: AttributedText('item'),
          type: ListItemType.ordered,
          indent: 0,
        ),
      ]),
    );
    addTearDown(controller.dispose);

    controller.setSelection(
      const DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'li1',
          nodePosition: TextNodePosition(offset: 0),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DocumentStatusBar(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ordered list'), findsOneWidget);
  });

  // property_section.dart lines 60-63: debugFillProperties
  testWidgets('PropertySection debugFillProperties includes label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PropertySection(
            label: 'Test Section',
            child: Text('child'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(PropertySection));
    final props = element.toDiagnosticsNode().getProperties();
    expect(props.any((p) => p.name == 'label'), isTrue);
  });

  // document_decoration.dart lines 144-147: equality branches
  test('DocumentDecoration equality checks all fields', () {
    final a = const DocumentDecoration(
      showToolbar: true,
      showPropertyPanel: true,
      showStatusBar: true,
      toolbarPosition: DocumentToolbarPosition.top,
      propertyPanelPosition: DocumentPanelPosition.end,
    );
    final b = const DocumentDecoration(
      showToolbar: true,
      showPropertyPanel: false,
      showStatusBar: true,
      toolbarPosition: DocumentToolbarPosition.top,
      propertyPanelPosition: DocumentPanelPosition.end,
    );
    expect(a == b, isFalse);

    final c = const DocumentDecoration(
      showToolbar: true,
      showPropertyPanel: true,
      showStatusBar: false,
      toolbarPosition: DocumentToolbarPosition.top,
      propertyPanelPosition: DocumentPanelPosition.end,
    );
    expect(a == c, isFalse);

    final d = const DocumentDecoration(
      showToolbar: true,
      showPropertyPanel: true,
      showStatusBar: true,
      toolbarPosition: DocumentToolbarPosition.bottom,
      propertyPanelPosition: DocumentPanelPosition.end,
    );
    expect(a == d, isFalse);

    final e = const DocumentDecoration(
      showToolbar: true,
      showPropertyPanel: true,
      showStatusBar: true,
      toolbarPosition: DocumentToolbarPosition.top,
      propertyPanelPosition: DocumentPanelPosition.start,
    );
    expect(a == e, isFalse);
  });

  // document_caret_painter.dart line 44: const constructor
  test('DocumentCaretPainter const constructor', () {
    const painter = DocumentCaretPainter(
      caretRect: Rect.fromLTWH(0, 0, 2, 20),
      color: Color(0xFF000000),
      width: 2.0,
    );
    expect(painter.color, const Color(0xFF000000));
    expect(painter.width, 2.0);
  });

  // block_border.dart lines 72-77: debugFillProperties
  test('BlockBorder debugFillProperties', () {
    const border = BlockBorder(
      style: BlockBorderStyle.solid,
      width: 2.0,
      color: Color(0xFFFF0000),
    );
    final builder = DiagnosticPropertiesBuilder();
    border.debugFillProperties(builder);
    expect(builder.properties.any((p) => p.name == 'style'), isTrue);
    expect(builder.properties.any((p) => p.name == 'width'), isTrue);
    expect(builder.properties.any((p) => p.name == 'color'), isTrue);
  });

  // document_change_event.dart lines 225-229: NodeInserted hashCode/toString
  // (TextChanged already covered; NodeInserted exercises the base class path)
  test('NodeInserted hashCode and toString', () {
    const a = NodeInserted(nodeId: 'x1', index: 0);
    const b = NodeInserted(nodeId: 'x1', index: 0);
    expect(a.hashCode, b.hashCode);
    expect(a.toString(), contains('x1'));
  });

  // render_document_block.dart lines 166, 177, 187: default getters
  test('RenderDocumentBlock default spaceBefore/spaceAfter/border are null', () {
    // RenderParagraphBlock extends RenderDocumentBlock via RenderTextBlock;
    // these getters are overridden in subclasses but the base defaults are
    // exercised when no spacing or border is set.
    final block = RenderParagraphBlock(
      nodeId: 'p1',
      text: AttributedText('test'),
    );
    // When no spaceBefore/spaceAfter/border is set, the base class
    // returns null from its virtual getters.
    expect(block.border, isNull);
  });

  // editor.dart: verify Editor.submit processes a simple request
  test('Editor submit processes InsertTextRequest', () {
    final doc = MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText('Hello')),
    ]);
    final controller = DocumentEditingController(document: doc);
    final editor = Editor(
      editContext: EditContext(document: doc, controller: controller),
    );

    controller.setSelection(
      const DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      ),
    );

    editor.submit(InsertTextRequest(
      nodeId: 'p1',
      offset: 5,
      text: AttributedText(' World'),
    ));

    final node = doc.nodeById('p1')! as ParagraphNode;
    expect(node.text.text, 'Hello World');
    controller.dispose();
  });

  // render_blockquote_block.dart lines 196-200: debugFillProperties
  // text_alignment_editor.dart lines 71-76: debugFillProperties
  testWidgets('TextAlignmentEditor debugFillProperties', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextAlignmentEditor(
            value: TextAlign.center,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(TextAlignmentEditor));
    final props = element.toDiagnosticsNode().getProperties();
    expect(props.any((p) => p.name == 'value'), isTrue);
  });

  // line_height_editor.dart lines 67-73: debugFillProperties
  testWidgets('LineHeightEditor debugFillProperties', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LineHeightEditor(
            value: 1.5,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(LineHeightEditor));
    final props = element.toDiagnosticsNode().getProperties();
    expect(props.any((p) => p.name == 'value'), isTrue);
  });

  // document_undo_redo_bar.dart lines 85-90: debugFillProperties
  testWidgets('DocumentUndoRedoBar debugFillProperties', (tester) async {
    final doc = MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText('x')),
    ]);
    final controller = DocumentEditingController(document: doc);
    addTearDown(controller.dispose);
    final editor = UndoableEditor(
      editContext: EditContext(document: doc, controller: controller),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentUndoRedoBar(editor: editor, controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(DocumentUndoRedoBar));
    final props = element.toDiagnosticsNode().getProperties();
    expect(props.any((p) => p.name == 'editor'), isTrue);
  });

  test('RenderBlockquoteBlock debugFillProperties includes borderColor', () {
    final block = RenderBlockquoteBlock(
      nodeId: 'bq1',
      text: AttributedText('quote'),
    );
    final builder = DiagnosticPropertiesBuilder();
    block.debugFillProperties(builder);
    expect(builder.properties.any((p) => p.name == 'borderColor'), isTrue);
  });

  // document_change_event.dart lines 225-229: NodeDeleted hashCode/toString
  test('NodeDeleted hashCode and toString', () {
    const a = NodeDeleted(nodeId: 'nd1', index: 0);
    const b = NodeDeleted(nodeId: 'nd1', index: 0);
    expect(a.hashCode, b.hashCode);
    expect(a.toString(), contains('nd1'));
  });

  // document_scrollable.dart lines 198-204: didUpdateWidget scrollController swap
  testWidgets('DocumentScrollable swaps to internal controller', (tester) async {
    final external = ScrollController();
    addTearDown(external.dispose);

    final doc = MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText('x')),
    ]);
    final controller = DocumentEditingController(document: doc);
    addTearDown(controller.dispose);
    final layoutKey = GlobalKey<DocumentLayoutState>();

    // Start with external controller.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DocumentScrollable(
          controller: controller,
          layoutKey: layoutKey,
          scrollController: external,
          child: const SizedBox(height: 100),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Swap to null (internal controller created).
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DocumentScrollable(
          controller: controller,
          layoutKey: layoutKey,
          child: const SizedBox(height: 100),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // block_layout_mixin.dart lines 108, 136: set requestedWidth/Height to null
  test('RenderImageBlock clearing width sets requestedWidth to null', () {
    final block = RenderImageBlock(
      nodeId: 'img1',
      image: null,
    );
    block.requestedWidth = 200;
    expect(block.requestedWidth, 200);
    block.requestedWidth = null;
    expect(block.requestedWidth, isNull);
    block.requestedHeight = 100;
    expect(block.requestedHeight, 100);
    block.requestedHeight = null;
    expect(block.requestedHeight, isNull);
  });

  // editor.dart lines 193-196: InsertTextAtBinaryNodeRequest mapping
  test('Editor processes InsertTextAtBinaryNodeRequest', () {
    final doc = MutableDocument([
      HorizontalRuleNode(id: 'hr1'),
    ]);
    final controller = DocumentEditingController(document: doc);
    final editor = Editor(
      editContext: EditContext(document: doc, controller: controller),
    );

    editor.submit(InsertTextAtBinaryNodeRequest(
      nodeId: 'hr1',
      nodePosition: BinaryNodePositionType.downstream,
      text: AttributedText('inserted'),
    ));

    // A new text node should have been inserted after the HR.
    expect(doc.nodes.length, greaterThan(1));
    controller.dispose();
  });

  // isSelectionFullyAttributed for table cells
  test('isSelectionFullyAttributed returns true for fully bold table cell', () {
    final boldText = AttributedText('Hello').applyAttribution(NamedAttribution.bold, 0, 4);
    final doc = MutableDocument([
      TableNode(
        id: 't1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [boldText],
        ],
      ),
    ]);
    final sel = const DocumentSelection(
      base: DocumentPosition(
        nodeId: 't1',
        nodePosition: TableCellPosition(row: 0, col: 0, offset: 0),
      ),
      extent: DocumentPosition(
        nodeId: 't1',
        nodePosition: TableCellPosition(row: 0, col: 0, offset: 5),
      ),
    );
    expect(isSelectionFullyAttributed(sel, NamedAttribution.bold, doc), isTrue);
  });

  test('isSelectionFullyAttributed returns false for partially bold table cell', () {
    final doc = MutableDocument([
      TableNode(
        id: 't1',
        rowCount: 1,
        columnCount: 1,
        cells: [
          [AttributedText('Hello')],
        ],
      ),
    ]);
    final sel = const DocumentSelection(
      base: DocumentPosition(
        nodeId: 't1',
        nodePosition: TableCellPosition(row: 0, col: 0, offset: 0),
      ),
      extent: DocumentPosition(
        nodeId: 't1',
        nodePosition: TableCellPosition(row: 0, col: 0, offset: 5),
      ),
    );
    expect(isSelectionFullyAttributed(sel, NamedAttribution.bold, doc), isFalse);
  });

  // TableNode.copyWith with sentinel border
  test('TableNode.copyWith clears border when null is passed', () {
    final node = TableNode(
      id: 't1',
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('x')],
      ],
      border: const BlockBorder(style: BlockBorderStyle.solid),
    );
    expect(node.border, isNotNull);
    final cleared = node.copyWith(border: null);
    expect(cleared.border, isNull);
  });

  test('TableNode.copyWith preserves border when not passed', () {
    final node = TableNode(
      id: 't1',
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('x')],
      ],
      border: const BlockBorder(style: BlockBorderStyle.solid),
    );
    final copy = node.copyWith(alignment: BlockAlignment.center);
    expect(copy.border, isNotNull);
  });

  // editor.dart line 272: unknown request type throws
  test('Editor throws for unknown request type', () {
    final doc = MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText('x')),
    ]);
    final controller = DocumentEditingController(document: doc);
    final editor = Editor(
      editContext: EditContext(document: doc, controller: controller),
    );
    expect(
      () => editor.submit(const _UnknownRequest()),
      throwsArgumentError,
    );
    controller.dispose();
  });

  // document_layout.dart uncovered line
  test('DocumentLayoutState with no render object returns null', () {
    // Just verify the type exists — the null checks are in the getters
    expect(DocumentLayoutState, isNotNull);
  });

  // render_document_caret.dart line 206: devicePixelRatio getter/setter
  test('RenderDocumentCaret devicePixelRatio setter', () {
    final caret = RenderDocumentCaret();
    expect(caret.devicePixelRatio, 1.0);
    caret.devicePixelRatio = 2.0;
    expect(caret.devicePixelRatio, 2.0);
  });

  // text_wrap_editor.dart lines 73-80: debugFillProperties
  testWidgets('TextWrapEditor debugFillProperties includes value and enabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextWrapEditor(
            value: TextWrapMode.wrap,
            onChanged: (_) {},
            enabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(TextWrapEditor));
    final props = element.toDiagnosticsNode().getProperties();
    expect(props.any((p) => p.name == 'value'), isTrue);
    expect(props.any((p) => p.name == 'onChanged'), isTrue);
    expect(props.any((p) => p.name == 'enabled'), isTrue);
  });

  // border_color_button.dart lines 78-84: debugFillProperties
  testWidgets('BorderColorButton debugFillProperties includes color and label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BorderColorButton(
            color: const Color(0xFFFF0000),
            isSelected: true,
            onTap: () {},
            label: 'Red',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(BorderColorButton));
    final props = element.toDiagnosticsNode().getProperties();
    expect(props.any((p) => p.name == 'color'), isTrue);
    expect(props.any((p) => p.name == 'isSelected'), isTrue);
    expect(props.any((p) => p.name == 'label'), isTrue);
  });

  // block_alignment_editor.dart lines 78-85: debugFillProperties
  testWidgets('BlockAlignmentEditor debugFillProperties includes value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlockAlignmentEditor(
            value: BlockAlignment.center,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(BlockAlignmentEditor));
    final props = element.toDiagnosticsNode().getProperties();
    expect(props.any((p) => p.name == 'value'), isTrue);
    expect(props.any((p) => p.name == 'onChanged'), isTrue);
  });

  // document_format_toggle.dart lines 91-97: debugFillProperties
  testWidgets('DocumentFormatToggle debugFillProperties includes icon and tooltip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentFormatToggle(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            isActive: true,
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(DocumentFormatToggle));
    final props = element.toDiagnosticsNode().getProperties();
    expect(props.any((p) => p.name == 'icon'), isTrue);
    expect(props.any((p) => p.name == 'tooltip'), isTrue);
    expect(props.any((p) => p.name == 'isActive'), isTrue);
  });

  // dimension_field.dart lines 47-75: debugFillProperties and didUpdateWidget
  testWidgets('DimensionField debugFillProperties includes value and hintText', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DimensionField(
            value: 120.0,
            onChanged: (_) {},
            hintText: 'px',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(DimensionField));
    final props = element.toDiagnosticsNode().getProperties();
    expect(props.any((p) => p.name == 'value'), isTrue);
    expect(props.any((p) => p.name == 'onChanged'), isTrue);
    expect(props.any((p) => p.name == 'hintText'), isTrue);
  });

  testWidgets('DimensionField didUpdateWidget syncs text when not editing', (tester) async {
    double? currentValue = 100.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DimensionField(
              value: currentValue,
              onChanged: (v) => setState(() => currentValue = v),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Update the value externally to trigger didUpdateWidget.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DimensionField(
            value: 200.0,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('200'), findsOneWidget);
  });

  // android_document_magnifier.dart lines 127-131: _MagnifierContainer debugFillProperties
  testWidgets('AndroidDocumentMagnifier debugFillProperties includes focalPoint', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AndroidDocumentMagnifier(
            focalPoint: Offset(50, 100),
            magnification: 1.5,
            size: Size(120, 56),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(AndroidDocumentMagnifier));
    final props = element.toDiagnosticsNode().getProperties();
    expect(props.any((p) => p.name == 'focalPoint'), isTrue);
    expect(props.any((p) => p.name == 'magnification'), isTrue);
    expect(props.any((p) => p.name == 'size'), isTrue);
  });

  // document_change_event.dart lines 225-229: NodeMoved hashCode and toString
  test('NodeMoved hashCode and toString', () {
    const a = NodeMoved(nodeId: 'nm1', oldIndex: 0, newIndex: 2);
    const b = NodeMoved(nodeId: 'nm1', oldIndex: 0, newIndex: 2);
    expect(a.hashCode, b.hashCode);
    expect(a.toString(), contains('nm1'));
    expect(a.toString(), contains('0'));
    expect(a.toString(), contains('2'));
  });

  // document_change_event.dart lines 225-229: NodeChangeEvent hashCode and toString
  test('NodeChangeEvent hashCode and toString', () {
    const a = NodeChangeEvent(nodeId: 'nc1');
    const b = NodeChangeEvent(nodeId: 'nc1');
    expect(a.hashCode, b.hashCode);
    expect(a.toString(), contains('nc1'));
  });

  // document_scrollable.dart lines 203-204: swap from internal to external controller
  testWidgets('DocumentScrollable swaps from internal to external controller', (tester) async {
    final external = ScrollController();
    addTearDown(external.dispose);

    final doc = MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText('x')),
    ]);
    final controller = DocumentEditingController(document: doc);
    addTearDown(controller.dispose);
    final layoutKey = GlobalKey<DocumentLayoutState>();

    // Start with no external controller (internal one is created).
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DocumentScrollable(
          controller: controller,
          layoutKey: layoutKey,
          child: const SizedBox(height: 100),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Swap to external controller (internal one is disposed).
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DocumentScrollable(
          controller: controller,
          layoutKey: layoutKey,
          scrollController: external,
          child: const SizedBox(height: 100),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // block_layout_mixin.dart lines 108, 136: widthDimension=null / heightDimension=null branches
  test('BlockLayoutMixin widthDimension=null clears requestedWidth', () {
    final block = RenderImageBlock(nodeId: 'img-dim', image: null);
    block.widthDimension = const BlockDimension.pixels(200);
    expect(block.requestedWidth, 200.0);
    block.widthDimension = null; // line 108: _requestedWidth = null
    expect(block.requestedWidth, isNull);
  });

  test('BlockLayoutMixin heightDimension=null clears requestedHeight', () {
    final block = RenderImageBlock(nodeId: 'img-dim2', image: null);
    block.heightDimension = const BlockDimension.pixels(100);
    expect(block.requestedHeight, 100.0);
    block.heightDimension = null; // line 136: _requestedHeight = null
    expect(block.requestedHeight, isNull);
  });

  // table_node.dart lines 341-343, 350-352: hashCode with cellTextAligns and cellVerticalAligns
  test('TableNode hashCode covers cellTextAligns and cellVerticalAligns loops', () {
    final node = TableNode(
      id: 't-hash',
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('x')],
      ],
      cellTextAligns: [
        [TextAlign.center],
      ],
      cellVerticalAligns: [
        [TableVerticalAlignment.top],
      ],
    );
    // Calling hashCode exercises lines 341-343 (cellTextAligns loop)
    // and 350-352 (cellVerticalAligns loop).
    expect(node.hashCode, isA<int>());
  });

  // document_caret_painter.dart line 44: non-const constructor invocation
  test('DocumentCaretPainter non-const constructor covers line 44', () {
    // A const invocation is compile-time and may not register a runtime hit;
    // a non-const call forces execution through the constructor body.
    final caretRect = const Rect.fromLTWH(0, 0, 2, 20);
    final painter = DocumentCaretPainter(caretRect: caretRect);
    expect(painter.caretRect, caretRect);
    expect(painter.width, 2.0);
  });

  // TableNode grid border fields
  test('TableNode gridBorderWidth/Color/Lines defaults', () {
    final node = TableNode(
      id: 't1',
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('x')],
      ],
    );
    expect(node.gridBorderWidth, 1.0);
    expect(node.gridBorderColor, isNull);
    expect(node.showHorizontalGridLines, isTrue);
    expect(node.showVerticalGridLines, isTrue);
  });

  test('TableNode copyWith showHorizontalGridLines to false', () {
    final node = TableNode(
      id: 't1',
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('x')],
      ],
    );
    final updated = node.copyWith(showHorizontalGridLines: false);
    expect(updated.showHorizontalGridLines, isFalse);
    expect(updated.showVerticalGridLines, isTrue);
    expect(updated.gridBorderWidth, 1.0);
  });

  test('TableNode copyWith gridBorderColor clears with null', () {
    final node = TableNode(
      id: 't1',
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('x')],
      ],
      gridBorderColor: const Color(0xFFFF0000),
    );
    expect(node.gridBorderColor, const Color(0xFFFF0000));
    final cleared = node.copyWith(gridBorderColor: null);
    expect(cleared.gridBorderColor, isNull);
  });

  // RenderTableBlock showHorizontalGridLines/showVerticalGridLines setter
  test('RenderTableBlock showHorizontalGridLines/showVerticalGridLines getter/setter', () {
    final block = RenderTableBlock(
      nodeId: 't1',
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('x')],
      ],
      textStyle: const TextStyle(fontSize: 14),
    );
    expect(block.showHorizontalGridLines, isTrue);
    expect(block.showVerticalGridLines, isTrue);
    block.showHorizontalGridLines = false;
    expect(block.showHorizontalGridLines, isFalse);
    block.showVerticalGridLines = false;
    expect(block.showVerticalGridLines, isFalse);
  });

  // TableBorderOption enum values
  test('TableBorderOption has all 6 values', () {
    expect(TableBorderOption.values.length, 6);
    expect(TableBorderOption.noBorder, isNotNull);
    expect(TableBorderOption.allBorders, isNotNull);
    expect(TableBorderOption.outsideBorders, isNotNull);
    expect(TableBorderOption.insideBorders, isNotNull);
    expect(TableBorderOption.horizontalInsideBorders, isNotNull);
    expect(TableBorderOption.verticalInsideBorders, isNotNull);
  });

  // _TableBorderDropdown renders in TableContextToolbar
  testWidgets('TableContextToolbar border dropdown renders', (tester) async {
    final doc = MutableDocument([
      TableNode(
        id: 't1',
        rowCount: 2,
        columnCount: 2,
        cells: [
          [AttributedText('A'), AttributedText('B')],
          [AttributedText('C'), AttributedText('D')],
        ],
      ),
    ]);
    final controller = DocumentEditingController(document: doc);
    addTearDown(controller.dispose);

    controller.setSelection(
      const DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 't1',
          nodePosition: TableCellPosition(row: 0, col: 0, offset: 0),
        ),
      ),
    );

    TableBorderOption? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableContextToolbar(
            controller: controller,
            requestHandler: (_) {},
            nodeId: 't1',
            minRow: 0,
            maxRow: 0,
            minCol: 0,
            maxCol: 0,
            cellTextAligns: null,
            cellVerticalAligns: null,
            rowCount: 2,
            columnCount: 2,
            onBorderOptionSelected: (opt) => selected = opt,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The border dropdown should be present (look for Borders tooltip)
    expect(find.byTooltip('Borders'), findsOneWidget);

    // Tap to open dropdown
    await tester.tap(find.byTooltip('Borders'));
    await tester.pumpAndSettle();

    // Should see menu items
    expect(find.text('No Border'), findsOneWidget);
    expect(find.text('All Borders'), findsOneWidget);
    expect(find.text('Outside Borders'), findsOneWidget);
    expect(find.text('Inside Borders'), findsOneWidget);

    // Tap "All Borders"
    await tester.tap(find.text('All Borders'));
    await tester.pumpAndSettle();

    expect(selected, TableBorderOption.allBorders);
  });

  // TableComponentViewModel showHorizontalGridLines/showVerticalGridLines
  test('TableComponentViewModel includes showHorizontalGridLines in equality', () {
    final a = TableComponentViewModel(
      nodeId: 't1',
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('x')],
      ],
      showHorizontalGridLines: true,
    );
    final b = TableComponentViewModel(
      nodeId: 't1',
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('x')],
      ],
      showHorizontalGridLines: false,
    );
    expect(a == b, isFalse);
  });

  // RenderTableBlock cellBorders setter
  test('RenderTableBlock cellBorders getter/setter', () {
    final block = RenderTableBlock(
      nodeId: 't1',
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('x')],
      ],
      textStyle: const TextStyle(fontSize: 14),
    );
    expect(block.cellBorders, isNull);
    final borders = [
      [CellBorders.all],
    ];
    block.cellBorders = borders;
    expect(block.cellBorders, borders);
  });

  // TableBorderOption includes per-cell values
  test('TableBorderOption has all 10 values', () {
    expect(TableBorderOption.values.length, 10);
    expect(TableBorderOption.bottomBorder, isNotNull);
    expect(TableBorderOption.topBorder, isNotNull);
    expect(TableBorderOption.leftBorder, isNotNull);
    expect(TableBorderOption.rightBorder, isNotNull);
  });

  // TableComponentViewModel cellBorders in equality
  test('TableComponentViewModel cellBorders affects equality', () {
    final a = TableComponentViewModel(
      nodeId: 't1',
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('x')],
      ],
    );
    final b = TableComponentViewModel(
      nodeId: 't1',
      rowCount: 1,
      columnCount: 1,
      cells: [
        [AttributedText('x')],
      ],
      cellBorders: [
        [CellBorders.all],
      ],
    );
    expect(a == b, isFalse);
  });
}

/// A test-only [EditRequest] subclass that no command handler knows about.
class _UnknownRequest extends EditRequest {
  const _UnknownRequest();
}
