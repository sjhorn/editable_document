/// Tests for [SliverEditableDocument] — Phase 7.
///
/// Covers rendering inside [CustomScrollView], scrolling, parameter forwarding,
/// and composition with other slivers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [MutableDocument] with a single paragraph of [text].
MutableDocument _makeDocument({String text = 'Hello'}) {
  return MutableDocument([
    ParagraphNode(id: 'p1', text: AttributedText(text)),
  ]);
}

/// Creates a [DocumentEditingController] with a single paragraph of [text].
DocumentEditingController _makeController({String text = 'Hello'}) {
  return DocumentEditingController(document: _makeDocument(text: text));
}

/// Creates a [DocumentEditingController] with [count] paragraph nodes so the
/// document is tall enough to scroll.
DocumentEditingController _makeTallController({int count = 40}) {
  final nodes = List.generate(
    count,
    (i) => ParagraphNode(id: 'p$i', text: AttributedText('Paragraph $i')),
  );
  return DocumentEditingController(document: MutableDocument(nodes));
}

/// Wraps [child] in [MaterialApp] for full widget environment.
Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Construction / basic rendering
  // -------------------------------------------------------------------------

  group('SliverEditableDocument — construction', () {
    testWidgets('builds without error inside CustomScrollView', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(SliverEditableDocument), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders an EditableDocument in the tree', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(EditableDocument), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a SliverToBoxAdapter in the tree', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(SliverToBoxAdapter), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('default parameters are correct', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ],
          ),
        ),
      );

      final widget = tester.widget<SliverEditableDocument>(find.byType(SliverEditableDocument));
      expect(widget.readOnly, isFalse);
      expect(widget.autofocus, isFalse);
      expect(widget.textAlign, TextAlign.start);
      expect(widget.blockSpacing, 12.0);
      expect(widget.textInputAction, TextInputAction.newline);
      expect(widget.keyboardType, TextInputType.multiline);
      expect(widget.scrollPadding, const EdgeInsets.all(20.0));
    });
  });

  // -------------------------------------------------------------------------
  // Scrolling
  // -------------------------------------------------------------------------

  group('SliverEditableDocument — scrolling', () {
    testWidgets('tall document can be scrolled inside CustomScrollView', (tester) async {
      final controller = _makeTallController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ],
          ),
        ),
      );

      // Verify initial state — EditableDocument is rendered.
      expect(find.byType(EditableDocument), findsOneWidget);

      // Scroll down.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      // The view has scrolled; no exceptions.
      expect(tester.takeException(), isNull);
    });

    testWidgets('scroll position changes after drag', (tester) async {
      final controller = _makeTallController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ],
          ),
        ),
      );

      expect(scrollController.offset, 0.0);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(scrollController.offset, greaterThan(0));
    });
  });

  // -------------------------------------------------------------------------
  // Parameter forwarding
  // -------------------------------------------------------------------------

  group('SliverEditableDocument — parameter forwarding', () {
    testWidgets('controller is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.controller, same(controller));
    });

    testWidgets('focusNode is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.focusNode, same(focusNode));
    });

    testWidgets('readOnly is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                readOnly: true,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.readOnly, isTrue);
    });

    testWidgets('autofocus is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.autofocus, isTrue);
    });

    testWidgets('textAlign is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.textAlign, TextAlign.center);
    });

    testWidgets('textDirection is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.textDirection, TextDirection.rtl);
    });

    testWidgets('blockSpacing is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                blockSpacing: 24.0,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.blockSpacing, 24.0);
    });

    testWidgets('style is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      const style = TextStyle(fontSize: 18);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                style: style,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.style, style);
    });

    testWidgets('stylesheet is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final sheet = {'body': const TextStyle(fontSize: 14)};

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                stylesheet: sheet,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.stylesheet, same(sheet));
    });

    testWidgets('componentBuilders are forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final builders = [const ParagraphComponentBuilder()];

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                componentBuilders: builders,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.componentBuilders, same(builders));
    });

    testWidgets('textInputAction is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.textInputAction, TextInputAction.done);
    });

    testWidgets('keyboardType is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.text,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.keyboardType, TextInputType.text);
    });

    testWidgets('scrollPadding is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      const padding = EdgeInsets.symmetric(vertical: 10);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                scrollPadding: padding,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.scrollPadding, padding);
    });

    testWidgets('onChanged callback is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      void onChanged(String value) {}

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.onChanged, same(onChanged));
    });

    testWidgets('onSelectionChanged callback is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final selectionEvents = <DocumentSelection?>[];

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                onSelectionChanged: selectionEvents.add,
              ),
            ],
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

      expect(selectionEvents, hasLength(1));
      expect(selectionEvents.first, isNotNull);
    });

    testWidgets('editor is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final editor = UndoableEditor(
        editContext: EditContext(
          document: controller.document,
          controller: controller,
        ),
      );

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                editor: editor,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.editor, same(editor));
    });

    testWidgets('layoutKey is forwarded to EditableDocument', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                layoutKey: layoutKey,
              ),
            ],
          ),
        ),
      );

      final editable = tester.widget<EditableDocument>(find.byType(EditableDocument));
      expect(editable.layoutKey, same(layoutKey));
    });
  });

  // -------------------------------------------------------------------------
  // Composition with other slivers
  // -------------------------------------------------------------------------

  group('SliverEditableDocument — composition with other slivers', () {
    testWidgets('works alongside SliverAppBar', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              const SliverAppBar(title: Text('My Document')),
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(SliverEditableDocument), findsOneWidget);
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('works between SliverAppBar and SliverList', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              const SliverAppBar(title: Text('My Document')),
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  const ListTile(title: Text('Item 1')),
                  const ListTile(title: Text('Item 2')),
                ]),
              ),
            ],
          ),
        ),
      );

      expect(find.byType(SliverEditableDocument), findsOneWidget);
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.byType(SliverList), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('works before another SliverToBoxAdapter', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
              ),
              const SliverToBoxAdapter(
                child: Text('Footer'),
              ),
            ],
          ),
        ),
      );

      expect(find.byType(SliverEditableDocument), findsOneWidget);
      expect(find.text('Footer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('multiple SliverEditableDocuments can coexist', (tester) async {
      final controller1 = _makeController(text: 'Document 1');
      final controller2 = _makeController(text: 'Document 2');
      final focusNode1 = FocusNode();
      final focusNode2 = FocusNode();
      addTearDown(focusNode1.dispose);
      addTearDown(focusNode2.dispose);
      addTearDown(controller1.dispose);
      addTearDown(controller2.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller1,
                focusNode: focusNode1,
              ),
              SliverEditableDocument(
                controller: controller2,
                focusNode: focusNode2,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(SliverEditableDocument), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // debugFillProperties
  // -------------------------------------------------------------------------

  group('SliverEditableDocument — debugFillProperties', () {
    testWidgets('does not throw during diagnostics collection', (tester) async {
      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CustomScrollView(
            slivers: [
              SliverEditableDocument(
                controller: controller,
                focusNode: focusNode,
                readOnly: false,
                autofocus: false,
                textAlign: TextAlign.start,
                blockSpacing: 16.0,
              ),
            ],
          ),
        ),
      );

      final element = tester.element(find.byType(SliverEditableDocument));
      final diagnostics = element.toDiagnosticsNode().toStringDeep();
      expect(diagnostics, isNotEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
