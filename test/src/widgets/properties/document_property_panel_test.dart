/// Tests for [DocumentPropertyPanel].
library;

import 'package:editable_document/src/model/attributed_text.dart';
import 'package:editable_document/src/model/document_editing_controller.dart';
import 'package:editable_document/src/model/document_position.dart';
import 'package:editable_document/src/model/document_selection.dart';
import 'package:editable_document/src/model/edit_request.dart';
import 'package:editable_document/src/model/image_node.dart';
import 'package:editable_document/src/model/mutable_document.dart';
import 'package:editable_document/src/model/node_position.dart';
import 'package:editable_document/src/model/paragraph_node.dart';
import 'package:editable_document/src/widgets/properties/document_property_panel.dart';
import 'package:editable_document/src/widgets/properties/text_alignment_editor.dart';
import 'package:editable_document/src/widgets/properties/block_alignment_editor.dart';
import 'package:editable_document/src/widgets/properties/image_properties_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DocumentEditingController _controllerWithParagraph() {
  final doc = MutableDocument([
    ParagraphNode(
      id: 'p1',
      text: AttributedText('Hello'),
    ),
  ]);
  return DocumentEditingController(
    document: doc,
    selection: const DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: 'p1',
        nodePosition: TextNodePosition(offset: 0),
      ),
    ),
  );
}

DocumentEditingController _controllerWithImage() {
  final doc = MutableDocument([
    ImageNode(
      id: 'img1',
      imageUrl: 'https://example.com/img.png',
    ),
  ]);
  return DocumentEditingController(
    document: doc,
    selection: const DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: 'img1',
        nodePosition: BinaryNodePosition.upstream(),
      ),
    ),
  );
}

DocumentEditingController _controllerNoSelection() {
  final doc = MutableDocument([
    ParagraphNode(id: 'p1', text: AttributedText('Hello')),
  ]);
  return DocumentEditingController(document: doc);
}

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('DocumentPropertyPanel', () {
    testWidgets('shows TextAlignmentEditor for ParagraphNode', (tester) async {
      final controller = _controllerWithParagraph();
      await tester.pumpWidget(
        _wrap(
          DocumentPropertyPanel(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      expect(find.byType(TextAlignmentEditor), findsOneWidget);
    });

    testWidgets('shows BlockAlignmentEditor for ImageNode', (tester) async {
      final controller = _controllerWithImage();
      await tester.pumpWidget(
        _wrap(
          DocumentPropertyPanel(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      expect(find.byType(BlockAlignmentEditor), findsOneWidget);
    });

    testWidgets('shows ImagePropertiesEditor for ImageNode', (tester) async {
      final controller = _controllerWithImage();
      await tester.pumpWidget(
        _wrap(
          DocumentPropertyPanel(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      expect(find.byType(ImagePropertiesEditor), findsOneWidget);
    });

    testWidgets('shows image URL in ImagePropertiesEditor', (tester) async {
      final controller = _controllerWithImage();
      await tester.pumpWidget(
        _wrap(
          DocumentPropertyPanel(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      final editor = tester.widget<ImagePropertiesEditor>(
        find.byType(ImagePropertiesEditor),
      );
      expect(editor.imageUrl, 'https://example.com/img.png');
    });

    testWidgets('shows nothing meaningful when no selection', (tester) async {
      final controller = _controllerNoSelection();
      await tester.pumpWidget(
        _wrap(
          DocumentPropertyPanel(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      // No property editors should be shown.
      expect(find.byType(TextAlignmentEditor), findsNothing);
      expect(find.byType(BlockAlignmentEditor), findsNothing);
      expect(find.byType(ImagePropertiesEditor), findsNothing);
    });

    testWidgets('fires ChangeTextAlignRequest when text align changes', (tester) async {
      final controller = _controllerWithParagraph();
      EditRequest? request;
      await tester.pumpWidget(
        _wrap(
          DocumentPropertyPanel(
            controller: controller,
            requestHandler: (r) => request = r,
          ),
        ),
      );

      // Tap center alignment (index 1).
      final buttons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
      await tester.tap(find.byWidget(buttons[1]));
      await tester.pump();

      expect(request, isA<ChangeTextAlignRequest>());
      final req = request! as ChangeTextAlignRequest;
      expect(req.nodeId, 'p1');
      expect(req.newTextAlign, TextAlign.center);
    });

    testWidgets('rebuilds when controller selection changes', (tester) async {
      final doc = MutableDocument([
        ParagraphNode(id: 'p1', text: AttributedText('Hello')),
        ImageNode(id: 'img1', imageUrl: 'https://x.com/img.png'),
      ]);
      final controller = DocumentEditingController(document: doc);

      await tester.pumpWidget(
        _wrap(
          DocumentPropertyPanel(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      );

      // Initially no selection → no editors.
      expect(find.byType(TextAlignmentEditor), findsNothing);

      // Set selection to paragraph.
      controller.setSelection(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TextAlignmentEditor), findsOneWidget);
    });
  });
}
