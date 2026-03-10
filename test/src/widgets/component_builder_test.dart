/// Tests for [ComponentBuilder], [ComponentViewModel], [ComponentContext],
/// and the six default builder implementations.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// A minimal [ComponentViewModel] for testing.
class _FakeViewModel extends ComponentViewModel {
  const _FakeViewModel({
    required super.nodeId,
    // ignore: unused_element_parameter
    super.nodeSelection,
    super.isSelected = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FakeViewModel &&
          other.nodeId == nodeId &&
          other.nodeSelection == nodeSelection &&
          other.isSelected == isSelected;

  @override
  int get hashCode => Object.hash(nodeId, nodeSelection, isSelected);
}

/// A minimal [ComponentBuilder] that handles [_FakeViewModel].
class _FakeComponentBuilder extends ComponentBuilder {
  const _FakeComponentBuilder();

  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) => null;

  @override
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context) {
    if (viewModel is _FakeViewModel) {
      return const SizedBox.shrink();
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Helpers to build model fixtures
// ---------------------------------------------------------------------------

ParagraphNode _paragraph({String id = 'p1', String text = 'Hello'}) =>
    ParagraphNode(id: id, text: AttributedText(text));

ListItemNode _listItem({String id = 'li1', String text = 'Item'}) =>
    ListItemNode(id: id, text: AttributedText(text));

ImageNode _image({String id = 'img1'}) =>
    ImageNode(id: id, imageUrl: 'https://example.com/img.png');

CodeBlockNode _codeBlock({String id = 'cb1', String text = 'void main() {}'}) =>
    CodeBlockNode(id: id, text: AttributedText(text));

// ignore: unused_element_parameter
HorizontalRuleNode _rule({String id = 'hr1'}) => HorizontalRuleNode(id: id);

BlockquoteNode _blockquote({String id = 'bq1', String text = 'To be or not to be'}) =>
    BlockquoteNode(id: id, text: AttributedText(text));

Document _doc(List<DocumentNode> nodes) => Document(nodes);

ComponentContext _ctx(Document doc) =>
    ComponentContext(document: doc, selection: null, stylesheet: null);

// ---------------------------------------------------------------------------
// ComponentViewModel tests
// ---------------------------------------------------------------------------

void main() {
  group('ComponentViewModel', () {
    test('stores nodeId, nodeSelection, isSelected', () {
      const vm = _FakeViewModel(nodeId: 'n1', isSelected: true);
      expect(vm.nodeId, 'n1');
      expect(vm.nodeSelection, isNull);
      expect(vm.isSelected, isTrue);
    });

    test('equality — same values are equal', () {
      const a = _FakeViewModel(nodeId: 'n1');
      const b = _FakeViewModel(nodeId: 'n1');
      expect(a, equals(b));
    });

    test('equality — different nodeId are not equal', () {
      const a = _FakeViewModel(nodeId: 'n1');
      const b = _FakeViewModel(nodeId: 'n2');
      expect(a, isNot(equals(b)));
    });

    test('equality — different isSelected are not equal', () {
      const a = _FakeViewModel(nodeId: 'n1', isSelected: false);
      const b = _FakeViewModel(nodeId: 'n1', isSelected: true);
      expect(a, isNot(equals(b)));
    });
  });

  // -------------------------------------------------------------------------
  // ComponentContext tests
  // -------------------------------------------------------------------------

  group('ComponentContext', () {
    test('stores document, selection, and stylesheet', () {
      final doc = _doc([_paragraph()]);
      const selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
      );
      final sheet = {'body': const TextStyle(fontSize: 14)};

      final ctx = ComponentContext(document: doc, selection: selection, stylesheet: sheet);

      expect(ctx.document, same(doc));
      expect(ctx.selection, same(selection));
      expect(ctx.stylesheet, same(sheet));
    });

    test('selection and stylesheet may be null', () {
      final doc = _doc([]);
      final ctx = ComponentContext(document: doc, selection: null, stylesheet: null);
      expect(ctx.selection, isNull);
      expect(ctx.stylesheet, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // ComponentBuilder protocol tests
  // -------------------------------------------------------------------------

  group('ComponentBuilder protocol', () {
    test('createComponent returns widget for handled viewModel', () {
      const builder = _FakeComponentBuilder();
      final doc = _doc([]);
      final ctx = ComponentContext(document: doc, selection: null, stylesheet: null);
      const vm = _FakeViewModel(nodeId: 'n1');

      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNotNull);
    });

    test('createComponent returns null for unhandled viewModel', () {
      const builder = _FakeComponentBuilder();
      final doc = _doc([_paragraph()]);
      final ctx = _ctx(doc);

      // ParagraphComponentViewModel is not handled by _FakeComponentBuilder.
      final vm = ParagraphComponentViewModel(
        nodeId: 'p1',
        text: AttributedText('Hello'),
        blockType: ParagraphBlockType.paragraph,
        textStyle: const TextStyle(),
      );
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // ParagraphComponentBuilder
  // -------------------------------------------------------------------------

  group('ParagraphComponentBuilder', () {
    const builder = ParagraphComponentBuilder();

    test('createViewModel returns non-null for ParagraphNode', () {
      final doc = _doc([_paragraph()]);
      final vm = builder.createViewModel(doc, _paragraph());
      expect(vm, isNotNull);
      expect(vm, isA<ParagraphComponentViewModel>());
    });

    test('createViewModel returns null for non-ParagraphNode', () {
      final doc = _doc([_listItem()]);
      final vm = builder.createViewModel(doc, _listItem());
      expect(vm, isNull);
    });

    test('createComponent returns non-null for ParagraphComponentViewModel', () {
      final doc = _doc([_paragraph()]);
      final ctx = _ctx(doc);
      final vm = ParagraphComponentViewModel(
        nodeId: 'p1',
        text: AttributedText('Hello'),
        blockType: ParagraphBlockType.paragraph,
        textStyle: const TextStyle(),
      );
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNotNull);
    });

    test('createComponent returns null for unhandled viewModel', () {
      final doc = _doc([]);
      final ctx = _ctx(doc);
      const vm = _FakeViewModel(nodeId: 'n1');
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNull);
    });

    testWidgets('created widget renders in a widget tree', (WidgetTester tester) async {
      final node = _paragraph(text: 'Flutter');
      final doc = _doc([node]);

      final builder = const ParagraphComponentBuilder();
      final vm = builder.createViewModel(doc, node) as ParagraphComponentViewModel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.createComponent(vm, _ctx(doc))!,
          ),
        ),
      );
      // Should not throw.
    });
  });

  // -------------------------------------------------------------------------
  // ListItemComponentBuilder
  // -------------------------------------------------------------------------

  group('ListItemComponentBuilder', () {
    const builder = ListItemComponentBuilder();

    test('createViewModel returns non-null for ListItemNode', () {
      final doc = _doc([_listItem()]);
      final vm = builder.createViewModel(doc, _listItem());
      expect(vm, isNotNull);
      expect(vm, isA<ListItemComponentViewModel>());
    });

    test('createViewModel returns null for non-ListItemNode', () {
      final doc = _doc([_paragraph()]);
      final vm = builder.createViewModel(doc, _paragraph());
      expect(vm, isNull);
    });

    test('ordinalIndex is computed correctly for ordered items', () {
      final nodes = [
        ListItemNode(id: 'a', text: AttributedText('A'), type: ListItemType.ordered),
        ListItemNode(id: 'b', text: AttributedText('B'), type: ListItemType.ordered),
        ListItemNode(id: 'c', text: AttributedText('C'), type: ListItemType.ordered),
      ];
      final doc = _doc(nodes);

      final vmA = builder.createViewModel(doc, nodes[0]) as ListItemComponentViewModel;
      final vmB = builder.createViewModel(doc, nodes[1]) as ListItemComponentViewModel;
      final vmC = builder.createViewModel(doc, nodes[2]) as ListItemComponentViewModel;

      expect(vmA.ordinalIndex, 1);
      expect(vmB.ordinalIndex, 2);
      expect(vmC.ordinalIndex, 3);
    });

    test('ordinalIndex resets after a non-list-item node', () {
      final nodes = [
        ListItemNode(id: 'a', text: AttributedText('A'), type: ListItemType.ordered),
        ParagraphNode(id: 'p', text: AttributedText('break')),
        ListItemNode(id: 'b', text: AttributedText('B'), type: ListItemType.ordered),
      ];
      final doc = _doc(nodes);

      final vmA = builder.createViewModel(doc, nodes[0]) as ListItemComponentViewModel;
      final vmB = builder.createViewModel(doc, nodes[2]) as ListItemComponentViewModel;

      expect(vmA.ordinalIndex, 1);
      expect(vmB.ordinalIndex, 1);
    });

    test('nested sub-list restarts numbering after returning to parent level', () {
      // Document:
      //   ordered indent=0  "First"      → ordinal 1
      //   ordered indent=1  "Nested-A"   → ordinal 1
      //   ordered indent=0  "Second"     → ordinal 2
      //   ordered indent=1  "Nested-C"   → ordinal 1  (NOT 2)
      final nodes = [
        ListItemNode(id: 'a', text: AttributedText('First'), type: ListItemType.ordered, indent: 0),
        ListItemNode(
          id: 'b',
          text: AttributedText('Nested-A'),
          type: ListItemType.ordered,
          indent: 1,
        ),
        ListItemNode(
          id: 'c',
          text: AttributedText('Second'),
          type: ListItemType.ordered,
          indent: 0,
        ),
        ListItemNode(
          id: 'd',
          text: AttributedText('Nested-C'),
          type: ListItemType.ordered,
          indent: 1,
        ),
      ];
      final doc = _doc(nodes);

      final vmD = builder.createViewModel(doc, nodes[3]) as ListItemComponentViewModel;

      // After the parent-level "Second" (indent=0), the indent=1 sub-list
      // must restart at 1.
      expect(vmD.ordinalIndex, 1);
    });

    test('deep nesting does not break parent-level run', () {
      // Document:
      //   ordered indent=1  "A"    → ordinal 1
      //   ordered indent=2  "deep" → ordinal 1
      //   ordered indent=1  "B"    → ordinal 2  (indent=2 item must NOT break indent=1 run)
      final nodes = [
        ListItemNode(id: 'a', text: AttributedText('A'), type: ListItemType.ordered, indent: 1),
        ListItemNode(
          id: 'deep',
          text: AttributedText('deep'),
          type: ListItemType.ordered,
          indent: 2,
        ),
        ListItemNode(id: 'b', text: AttributedText('B'), type: ListItemType.ordered, indent: 1),
      ];
      final doc = _doc(nodes);

      final vmB = builder.createViewModel(doc, nodes[2]) as ListItemComponentViewModel;

      // Children (deeper indent) must not break the parent run.
      expect(vmB.ordinalIndex, 2);
    });

    test('unordered item at same level resets ordered numbering', () {
      // Document:
      //   ordered   indent=1  "A"      → ordinal 1
      //   unordered indent=1  "bullet" → (unordered, ignored for ordinal)
      //   ordered   indent=1  "B"      → ordinal 1  (same-level bullet resets)
      final nodes = [
        ListItemNode(id: 'a', text: AttributedText('A'), type: ListItemType.ordered, indent: 1),
        ListItemNode(
          id: 'bullet',
          text: AttributedText('bullet'),
          type: ListItemType.unordered,
          indent: 1,
        ),
        ListItemNode(id: 'b', text: AttributedText('B'), type: ListItemType.ordered, indent: 1),
      ];
      final doc = _doc(nodes);

      final vmB = builder.createViewModel(doc, nodes[2]) as ListItemComponentViewModel;

      // The unordered item at the same indent level resets the ordered run.
      expect(vmB.ordinalIndex, 1);
    });

    test('createComponent returns non-null for ListItemComponentViewModel', () {
      final doc = _doc([_listItem()]);
      final ctx = _ctx(doc);
      final vm = ListItemComponentViewModel(
        nodeId: 'li1',
        text: AttributedText('Item'),
        type: ListItemType.unordered,
        indent: 0,
        ordinalIndex: 1,
        textStyle: const TextStyle(),
      );
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNotNull);
    });

    test('createComponent returns null for unhandled viewModel', () {
      final doc = _doc([]);
      final ctx = _ctx(doc);
      const vm = _FakeViewModel(nodeId: 'n1');
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // ImageComponentBuilder
  // -------------------------------------------------------------------------

  group('ImageComponentBuilder', () {
    const builder = ImageComponentBuilder();

    test('createViewModel returns non-null for ImageNode', () {
      final doc = _doc([_image()]);
      final vm = builder.createViewModel(doc, _image());
      expect(vm, isNotNull);
      expect(vm, isA<ImageComponentViewModel>());
    });

    test('createViewModel returns null for non-ImageNode', () {
      final doc = _doc([_paragraph()]);
      final vm = builder.createViewModel(doc, _paragraph());
      expect(vm, isNull);
    });

    test('createViewModel copies alignment and textWrap from ImageNode', () {
      final node = ImageNode(
        id: 'img1',
        imageUrl: 'https://example.com/img.png',
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as ImageComponentViewModel;
      expect(vm.alignment, BlockAlignment.center);
      expect(vm.textWrap, TextWrapMode.wrap);
    });

    test('createViewModel defaults alignment to stretch and textWrap to none', () {
      final doc = _doc([_image()]);
      final vm = builder.createViewModel(doc, _image()) as ImageComponentViewModel;
      expect(vm.alignment, BlockAlignment.stretch);
      expect(vm.textWrap, TextWrapMode.none);
    });

    test('createComponent returns non-null for ImageComponentViewModel', () {
      final doc = _doc([_image()]);
      final ctx = _ctx(doc);
      const vm = ImageComponentViewModel(
        nodeId: 'img1',
        imageUrl: 'https://example.com/img.png',
        altText: null,
        imageWidth: null,
        imageHeight: null,
      );
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNotNull);
    });

    test('createComponent returns null for unhandled viewModel', () {
      final doc = _doc([]);
      final ctx = _ctx(doc);
      const vm = _FakeViewModel(nodeId: 'n1');
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNull);
    });

    test('ImageComponentViewModel equality includes alignment and textWrap', () {
      const a = ImageComponentViewModel(
        nodeId: 'img1',
        imageUrl: 'https://example.com/img.png',
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      const b = ImageComponentViewModel(
        nodeId: 'img1',
        imageUrl: 'https://example.com/img.png',
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      const c = ImageComponentViewModel(
        nodeId: 'img1',
        imageUrl: 'https://example.com/img.png',
        alignment: BlockAlignment.start,
        textWrap: TextWrapMode.none,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('ImageComponentViewModel hashCode includes alignment and textWrap', () {
      const a = ImageComponentViewModel(
        nodeId: 'img1',
        imageUrl: 'https://example.com/img.png',
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      const b = ImageComponentViewModel(
        nodeId: 'img1',
        imageUrl: 'https://example.com/img.png',
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    testWidgets('ImageComponentBuilder created widget renders in a widget tree',
        (WidgetTester tester) async {
      final node = _image();
      final doc = _doc([node]);

      const builder = ImageComponentBuilder();
      final vm = builder.createViewModel(doc, node) as ImageComponentViewModel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.createComponent(vm, _ctx(doc))!,
          ),
        ),
      );
      // Should not throw.
    });
  });

  // -------------------------------------------------------------------------
  // CodeBlockComponentBuilder
  // -------------------------------------------------------------------------

  group('CodeBlockComponentBuilder', () {
    const builder = CodeBlockComponentBuilder();

    test('createViewModel returns non-null for CodeBlockNode', () {
      final doc = _doc([_codeBlock()]);
      final vm = builder.createViewModel(doc, _codeBlock());
      expect(vm, isNotNull);
      expect(vm, isA<CodeBlockComponentViewModel>());
    });

    test('createViewModel returns null for non-CodeBlockNode', () {
      final doc = _doc([_paragraph()]);
      final vm = builder.createViewModel(doc, _paragraph());
      expect(vm, isNull);
    });

    test('createViewModel copies width, height, alignment, textWrap from CodeBlockNode', () {
      final node = CodeBlockNode(
        id: 'cb1',
        text: AttributedText('code'),
        width: 400.0,
        height: 200.0,
        alignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
      );
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as CodeBlockComponentViewModel;
      expect(vm.width, 400.0);
      expect(vm.height, 200.0);
      expect(vm.alignment, BlockAlignment.end);
      expect(vm.textWrap, TextWrapMode.wrap);
    });

    test('createViewModel defaults width, height to null and alignment to stretch', () {
      final doc = _doc([_codeBlock()]);
      final vm = builder.createViewModel(doc, _codeBlock()) as CodeBlockComponentViewModel;
      expect(vm.width, isNull);
      expect(vm.height, isNull);
      expect(vm.alignment, BlockAlignment.stretch);
      expect(vm.textWrap, TextWrapMode.none);
    });

    test('createComponent returns non-null for CodeBlockComponentViewModel', () {
      final doc = _doc([_codeBlock()]);
      final ctx = _ctx(doc);
      final vm = CodeBlockComponentViewModel(
        nodeId: 'cb1',
        text: AttributedText('void main() {}'),
        textStyle: const TextStyle(),
      );
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNotNull);
    });

    test('createComponent returns null for unhandled viewModel', () {
      final doc = _doc([]);
      final ctx = _ctx(doc);
      const vm = _FakeViewModel(nodeId: 'n1');
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNull);
    });

    test('CodeBlockComponentViewModel equality includes width, height, alignment, textWrap', () {
      final a = CodeBlockComponentViewModel(
        nodeId: 'cb1',
        text: AttributedText('code'),
        textStyle: const TextStyle(),
        width: 400.0,
        height: 200.0,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final b = CodeBlockComponentViewModel(
        nodeId: 'cb1',
        text: AttributedText('code'),
        textStyle: const TextStyle(),
        width: 400.0,
        height: 200.0,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final c = CodeBlockComponentViewModel(
        nodeId: 'cb1',
        text: AttributedText('code'),
        textStyle: const TextStyle(),
        width: 300.0,
        alignment: BlockAlignment.start,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('CodeBlockComponentViewModel hashCode includes width, height, alignment, textWrap', () {
      final a = CodeBlockComponentViewModel(
        nodeId: 'cb1',
        text: AttributedText('code'),
        textStyle: const TextStyle(),
        width: 400.0,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final b = CodeBlockComponentViewModel(
        nodeId: 'cb1',
        text: AttributedText('code'),
        textStyle: const TextStyle(),
        width: 400.0,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // -------------------------------------------------------------------------
  // HorizontalRuleComponentBuilder
  // -------------------------------------------------------------------------

  group('HorizontalRuleComponentBuilder', () {
    const builder = HorizontalRuleComponentBuilder();

    test('createViewModel returns non-null for HorizontalRuleNode', () {
      final doc = _doc([_rule()]);
      final vm = builder.createViewModel(doc, _rule());
      expect(vm, isNotNull);
      expect(vm, isA<HorizontalRuleComponentViewModel>());
    });

    test('createViewModel returns null for non-HorizontalRuleNode', () {
      final doc = _doc([_paragraph()]);
      final vm = builder.createViewModel(doc, _paragraph());
      expect(vm, isNull);
    });

    test('createViewModel copies alignment from HorizontalRuleNode', () {
      final node = HorizontalRuleNode(id: 'hr1', alignment: BlockAlignment.center);
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as HorizontalRuleComponentViewModel;
      expect(vm.alignment, BlockAlignment.center);
    });

    test('createViewModel defaults alignment to stretch', () {
      final doc = _doc([_rule()]);
      final vm = builder.createViewModel(doc, _rule()) as HorizontalRuleComponentViewModel;
      expect(vm.alignment, BlockAlignment.stretch);
    });

    test('createComponent returns non-null for HorizontalRuleComponentViewModel', () {
      final doc = _doc([_rule()]);
      final ctx = _ctx(doc);
      const vm = HorizontalRuleComponentViewModel(nodeId: 'hr1');
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNotNull);
    });

    test('createComponent returns null for unhandled viewModel', () {
      final doc = _doc([]);
      final ctx = _ctx(doc);
      const vm = _FakeViewModel(nodeId: 'n1');
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNull);
    });

    test('HorizontalRuleComponentViewModel equality includes alignment', () {
      const a = HorizontalRuleComponentViewModel(
        nodeId: 'hr1',
        alignment: BlockAlignment.center,
      );
      const b = HorizontalRuleComponentViewModel(
        nodeId: 'hr1',
        alignment: BlockAlignment.center,
      );
      const c = HorizontalRuleComponentViewModel(
        nodeId: 'hr1',
        alignment: BlockAlignment.start,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('HorizontalRuleComponentViewModel hashCode includes alignment', () {
      const a = HorizontalRuleComponentViewModel(
        nodeId: 'hr1',
        alignment: BlockAlignment.center,
      );
      const b = HorizontalRuleComponentViewModel(
        nodeId: 'hr1',
        alignment: BlockAlignment.center,
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // -------------------------------------------------------------------------
  // BlockquoteComponentBuilder
  // -------------------------------------------------------------------------

  group('BlockquoteComponentBuilder', () {
    const builder = BlockquoteComponentBuilder();

    test('createViewModel returns non-null for BlockquoteNode', () {
      final doc = _doc([_blockquote()]);
      final vm = builder.createViewModel(doc, _blockquote());
      expect(vm, isNotNull);
      expect(vm, isA<BlockquoteComponentViewModel>());
    });

    test('createViewModel returns null for non-BlockquoteNode', () {
      final doc = _doc([_paragraph()]);
      final vm = builder.createViewModel(doc, _paragraph());
      expect(vm, isNull);
    });

    test('createViewModel returns null for CodeBlockNode', () {
      final doc = _doc([_codeBlock()]);
      final vm = builder.createViewModel(doc, _codeBlock());
      expect(vm, isNull);
    });

    test('createViewModel copies text, width, height, alignment, textWrap from BlockquoteNode', () {
      final node = BlockquoteNode(
        id: 'bq1',
        text: AttributedText('To be or not to be'),
        width: 500.0,
        height: 100.0,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final doc = _doc([node]);
      final vm = builder.createViewModel(doc, node) as BlockquoteComponentViewModel;
      expect(vm.text.text, 'To be or not to be');
      expect(vm.width, 500.0);
      expect(vm.height, 100.0);
      expect(vm.alignment, BlockAlignment.center);
      expect(vm.textWrap, TextWrapMode.wrap);
    });

    test('createViewModel defaults width, height to null and alignment to stretch', () {
      final doc = _doc([_blockquote()]);
      final vm = builder.createViewModel(doc, _blockquote()) as BlockquoteComponentViewModel;
      expect(vm.width, isNull);
      expect(vm.height, isNull);
      expect(vm.alignment, BlockAlignment.stretch);
      expect(vm.textWrap, TextWrapMode.none);
    });

    test('createComponent returns non-null for BlockquoteComponentViewModel', () {
      final doc = _doc([_blockquote()]);
      final ctx = _ctx(doc);
      final vm = BlockquoteComponentViewModel(
        nodeId: 'bq1',
        text: AttributedText('To be or not to be'),
        textStyle: const TextStyle(),
      );
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNotNull);
    });

    test('createComponent returns null for unhandled viewModel', () {
      final doc = _doc([]);
      final ctx = _ctx(doc);
      const vm = _FakeViewModel(nodeId: 'n1');
      final widget = builder.createComponent(vm, ctx);
      expect(widget, isNull);
    });

    test('BlockquoteComponentViewModel equality and hashCode', () {
      final a = BlockquoteComponentViewModel(
        nodeId: 'bq1',
        text: AttributedText('quote'),
        textStyle: const TextStyle(),
        width: 500.0,
        height: 100.0,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final b = BlockquoteComponentViewModel(
        nodeId: 'bq1',
        text: AttributedText('quote'),
        textStyle: const TextStyle(),
        width: 500.0,
        height: 100.0,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final c = BlockquoteComponentViewModel(
        nodeId: 'bq1',
        text: AttributedText('different'),
        textStyle: const TextStyle(),
        alignment: BlockAlignment.start,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    testWidgets('BlockquoteComponentBuilder created widget renders in a widget tree',
        (WidgetTester tester) async {
      final node = _blockquote();
      final doc = _doc([node]);

      const builder = BlockquoteComponentBuilder();
      final vm = builder.createViewModel(doc, node) as BlockquoteComponentViewModel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.createComponent(vm, _ctx(doc))!,
          ),
        ),
      );
      // Should not throw.
    });
  });

  // -------------------------------------------------------------------------
  // defaultComponentBuilders priority — first non-null wins
  // -------------------------------------------------------------------------

  group('defaultComponentBuilders', () {
    test('list contains all six default builders', () {
      expect(defaultComponentBuilders, hasLength(6));
      expect(defaultComponentBuilders[0], isA<ParagraphComponentBuilder>());
      expect(defaultComponentBuilders[1], isA<ListItemComponentBuilder>());
      expect(defaultComponentBuilders[2], isA<ImageComponentBuilder>());
      expect(defaultComponentBuilders[3], isA<CodeBlockComponentBuilder>());
      expect(defaultComponentBuilders[4], isA<BlockquoteComponentBuilder>());
      expect(defaultComponentBuilders[5], isA<HorizontalRuleComponentBuilder>());
    });

    test('defaultComponentBuilders includes BlockquoteComponentBuilder', () {
      final hasBlockquoteBuilder =
          defaultComponentBuilders.any((b) => b is BlockquoteComponentBuilder);
      expect(hasBlockquoteBuilder, isTrue);
    });

    test('custom builder prepended takes priority over default', () {
      // A custom builder that always returns a non-null sentinel for ParagraphNode.
      final custom = _ParagraphOverrideBuilder();
      final builders = [custom, ...defaultComponentBuilders];

      final doc = _doc([_paragraph()]);
      final node = _paragraph();

      // Try builders in order — first non-null wins.
      ComponentViewModel? vm;
      for (final b in builders) {
        vm = b.createViewModel(doc, node);
        if (vm != null) break;
      }

      expect(vm, isA<_CustomParagraphViewModel>());
    });

    test('resolveViewModel returns first non-null across builders', () {
      final doc = _doc([_paragraph(), _listItem(), _image(), _blockquote()]);

      // Paragraph should be handled by ParagraphComponentBuilder.
      final paraVm = resolveViewModel(defaultComponentBuilders, doc, _paragraph());
      expect(paraVm, isA<ParagraphComponentViewModel>());

      // ListItem should be handled by ListItemComponentBuilder.
      final listVm = resolveViewModel(defaultComponentBuilders, doc, _listItem());
      expect(listVm, isA<ListItemComponentViewModel>());

      // Image should be handled by ImageComponentBuilder.
      final imgVm = resolveViewModel(defaultComponentBuilders, doc, _image());
      expect(imgVm, isA<ImageComponentViewModel>());

      // Blockquote should be handled by BlockquoteComponentBuilder.
      final bqVm = resolveViewModel(defaultComponentBuilders, doc, _blockquote());
      expect(bqVm, isA<BlockquoteComponentViewModel>());

      // Unknown node type should return null.
      final unknownVm = resolveViewModel(defaultComponentBuilders, doc, _UnknownNode());
      expect(unknownVm, isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Test-only helpers
// ---------------------------------------------------------------------------

class _CustomParagraphViewModel extends ComponentViewModel {
  const _CustomParagraphViewModel({required super.nodeId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _CustomParagraphViewModel && other.nodeId == nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

class _ParagraphOverrideBuilder extends ComponentBuilder {
  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is ParagraphNode) return _CustomParagraphViewModel(nodeId: node.id);
    return null;
  }

  @override
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context) {
    if (viewModel is _CustomParagraphViewModel) return const SizedBox.shrink();
    return null;
  }
}

class _UnknownNode extends DocumentNode {
  _UnknownNode() : super(id: 'unknown');

  @override
  DocumentNode copyWith({String? id, Map<String, dynamic>? metadata}) => _UnknownNode();

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => id.hashCode;
}
