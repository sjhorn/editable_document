/// Tests for [DocumentImeSerializer] — bidirectional IME serialization and
/// delta-to-EditRequest mapping.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

void main() {
  group('DocumentImeSerializer', () {
    late DocumentImeSerializer serializer;

    setUp(() {
      serializer = const DocumentImeSerializer();
    });

    // -------------------------------------------------------------------------
    // Mode 1 — single text node selected
    // -------------------------------------------------------------------------

    group('toTextEditingValue — Mode 1 (single text node)', () {
      test('single paragraph, collapsed selection returns full text and caret', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello world'));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 5),
          ),
        );

        final value = serializer.toTextEditingValue(document: doc, selection: selection);

        expect(value.text, equals('Hello world'));
        expect(value.selection, equals(const TextSelection.collapsed(offset: 5)));
        expect(value.composing, equals(TextRange.empty));
      });

      test('single paragraph, expanded selection maps base and extent offsets', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello world'));
        final doc = Document([node]);
        final selection = const DocumentSelection(
          base: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 5),
          ),
        );

        final value = serializer.toTextEditingValue(document: doc, selection: selection);

        expect(value.text, equals('Hello world'));
        expect(
          value.selection,
          equals(const TextSelection(baseOffset: 0, extentOffset: 5)),
        );
      });

      test('selection at start of text produces offset 0 caret', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('abc'));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        );

        final value = serializer.toTextEditingValue(document: doc, selection: selection);

        expect(value.text, equals('abc'));
        expect(value.selection, equals(const TextSelection.collapsed(offset: 0)));
      });

      test('selection at end of text produces offset == text.length caret', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('abc'));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 3),
          ),
        );

        final value = serializer.toTextEditingValue(document: doc, selection: selection);

        expect(value.text, equals('abc'));
        expect(value.selection, equals(const TextSelection.collapsed(offset: 3)));
      });

      test('composing region within a text node is preserved', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('composing'));
        final doc = Document([node]);
        // Collapsed selection at offset 9 (end).
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 9),
          ),
        );

        final value = serializer.toTextEditingValue(
          document: doc,
          selection: selection,
          composingNodeId: 'p1',
          composingBase: 0,
          composingExtent: 9,
        );

        expect(value.text, equals('composing'));
        expect(value.composing, equals(const TextRange(start: 0, end: 9)));
      });

      test('round-trip: serialize then deserialize returns original selection', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Flutter'));
        final doc = Document([node]);
        final originalSelection = const DocumentSelection(
          base: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 1),
          ),
          extent: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 4),
          ),
        );

        final imeValue = serializer.toTextEditingValue(document: doc, selection: originalSelection);
        final recoveredSelection = serializer.toDocumentSelection(
          imeValue: imeValue,
          document: doc,
          serializedNodeId: 'p1',
        );

        expect(recoveredSelection, equals(originalSelection));
      });

      test('round-trip with collapsed selection', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hi'));
        final doc = Document([node]);
        final originalSelection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 2),
          ),
        );

        final imeValue = serializer.toTextEditingValue(document: doc, selection: originalSelection);
        final recoveredSelection = serializer.toDocumentSelection(
          imeValue: imeValue,
          document: doc,
          serializedNodeId: 'p1',
        );

        expect(recoveredSelection, equals(originalSelection));
      });

      test('text node with BinaryNodePosition falls back to Mode 2', () {
        // A TextNode with BinaryNodePosition in the selection should produce
        // a synthetic value, exercising the inner Mode 1 fallback branch.
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello'));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        );

        final value = serializer.toTextEditingValue(document: doc, selection: selection);

        // Falls back to Mode 2 because BinaryNodePosition is not a TextNodePosition.
        expect(value.text, equals('\u200B'));
        expect(value.selection, equals(const TextSelection.collapsed(offset: 1)));
      });

      test('composing region for a different node id is not applied', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('test'));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 4),
          ),
        );

        // composingNodeId is different from the selected node — composing should be empty.
        final value = serializer.toTextEditingValue(
          document: doc,
          selection: selection,
          composingNodeId: 'other-node',
          composingBase: 0,
          composingExtent: 4,
        );

        expect(value.composing, equals(TextRange.empty));
      });
    });

    // -------------------------------------------------------------------------
    // Mode 2 — synthetic (cross-block, non-text node, or null selection)
    // -------------------------------------------------------------------------

    group('toTextEditingValue — Mode 2 (synthetic)', () {
      test('cross-block selection returns synthetic zero-width space value', () {
        final n1 = ParagraphNode(id: 'p1', text: AttributedText('First'));
        final n2 = ParagraphNode(id: 'p2', text: AttributedText('Second'));
        final doc = Document([n1, n2]);
        final selection = const DocumentSelection(
          base: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: 'p2',
            nodePosition: TextNodePosition(offset: 3),
          ),
        );

        final value = serializer.toTextEditingValue(document: doc, selection: selection);

        expect(value.text, equals('\u200B'));
        expect(value.selection, equals(const TextSelection.collapsed(offset: 1)));
      });

      test('non-text node selected returns synthetic value', () {
        final imageNode = ImageNode(id: 'img1', imageUrl: 'https://example.com/img.png');
        final doc = Document([imageNode]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'img1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        );

        final value = serializer.toTextEditingValue(document: doc, selection: selection);

        expect(value.text, equals('\u200B'));
        expect(value.selection, equals(const TextSelection.collapsed(offset: 1)));
      });

      test('null selection returns synthetic value with empty text', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello'));
        final doc = Document([node]);

        final value = serializer.toTextEditingValue(document: doc, selection: null);

        expect(value.text, equals(''));
        expect(value.selection, equals(const TextSelection.collapsed(offset: 0)));
      });

      test('empty document with null selection returns empty text', () {
        final doc = Document();

        final value = serializer.toTextEditingValue(document: doc, selection: null);

        expect(value.text, equals(''));
        expect(value.selection, equals(const TextSelection.collapsed(offset: 0)));
      });
    });

    // -------------------------------------------------------------------------
    // toDocumentSelection
    // -------------------------------------------------------------------------

    group('toDocumentSelection', () {
      test('null serializedNodeId returns null', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello'));
        final doc = Document([node]);
        const imeValue = TextEditingValue(
          text: 'Hello',
          selection: TextSelection.collapsed(offset: 2),
        );

        final result = serializer.toDocumentSelection(
          imeValue: imeValue,
          document: doc,
          serializedNodeId: null,
        );

        expect(result, isNull);
      });

      test('unknown serializedNodeId returns null', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello'));
        final doc = Document([node]);
        const imeValue = TextEditingValue(
          text: 'Hello',
          selection: TextSelection.collapsed(offset: 2),
        );

        final result = serializer.toDocumentSelection(
          imeValue: imeValue,
          document: doc,
          serializedNodeId: 'unknown-id',
        );

        expect(result, isNull);
      });

      test('invalid (negative) IME selection returns null', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello'));
        final doc = Document([node]);
        const imeValue = TextEditingValue(
          text: 'Hello',
          selection: TextSelection(baseOffset: -1, extentOffset: -1),
        );

        final result = serializer.toDocumentSelection(
          imeValue: imeValue,
          document: doc,
          serializedNodeId: 'p1',
        );

        expect(result, isNull);
      });

      test('valid IME selection maps to DocumentSelection', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello world'));
        final doc = Document([node]);
        const imeValue = TextEditingValue(
          text: 'Hello world',
          selection: TextSelection(baseOffset: 2, extentOffset: 7),
        );

        final result = serializer.toDocumentSelection(
          imeValue: imeValue,
          document: doc,
          serializedNodeId: 'p1',
        );

        expect(result, isNotNull);
        expect(
          result!.base,
          equals(
            const DocumentPosition(
              nodeId: 'p1',
              nodePosition: TextNodePosition(offset: 2),
            ),
          ),
        );
        expect(
          result.extent,
          equals(
            const DocumentPosition(
              nodeId: 'p1',
              nodePosition: TextNodePosition(offset: 7),
            ),
          ),
        );
      });
    });

    // -------------------------------------------------------------------------
    // deltaToRequests
    // -------------------------------------------------------------------------

    group('deltaToRequests', () {
      test('empty deltas list returns empty list', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText(''));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        );

        final requests = serializer.deltaToRequests(
          deltas: const [],
          document: doc,
          selection: selection,
        );

        expect(requests, isEmpty);
      });

      test('TextEditingDeltaInsertion produces InsertTextRequest', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText(''));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        );

        final delta = const TextEditingDeltaInsertion(
          oldText: '',
          textInserted: 'H',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        );

        final requests = serializer.deltaToRequests(
          deltas: [delta],
          document: doc,
          selection: selection,
        );

        expect(requests, hasLength(1));
        expect(requests.first, isA<InsertTextRequest>());
        final req = requests.first as InsertTextRequest;
        expect(req.nodeId, equals('p1'));
        expect(req.offset, equals(0));
        expect(req.text.text, equals('H'));
      });

      test('TextEditingDeltaInsertion with newline produces SplitParagraphRequest', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello'));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 5),
          ),
        );

        final delta = const TextEditingDeltaInsertion(
          oldText: 'Hello',
          textInserted: '\n',
          insertionOffset: 5,
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange.empty,
        );

        final requests = serializer.deltaToRequests(
          deltas: [delta],
          document: doc,
          selection: selection,
        );

        expect(requests, hasLength(1));
        expect(requests.first, isA<SplitParagraphRequest>());
        final req = requests.first as SplitParagraphRequest;
        expect(req.nodeId, equals('p1'));
        expect(req.splitOffset, equals(5));
      });

      test('TextEditingDeltaDeletion produces DeleteContentRequest', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello'));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 5),
          ),
        );

        final delta = const TextEditingDeltaDeletion(
          oldText: 'Hello',
          deletedRange: TextRange(start: 4, end: 5),
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange.empty,
        );

        final requests = serializer.deltaToRequests(
          deltas: [delta],
          document: doc,
          selection: selection,
        );

        expect(requests, hasLength(1));
        expect(requests.first, isA<DeleteContentRequest>());
        final req = requests.first as DeleteContentRequest;
        expect(
          req.selection.base,
          equals(
            const DocumentPosition(
              nodeId: 'p1',
              nodePosition: TextNodePosition(offset: 4),
            ),
          ),
        );
        expect(
          req.selection.extent,
          equals(
            const DocumentPosition(
              nodeId: 'p1',
              nodePosition: TextNodePosition(offset: 5),
            ),
          ),
        );
      });

      test('TextEditingDeltaReplacement produces delete + insert requests', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello'));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 5),
          ),
        );

        final delta = const TextEditingDeltaReplacement(
          oldText: 'Hello',
          replacementText: 'Hola',
          replacedRange: TextRange(start: 0, end: 5),
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange.empty,
        );

        final requests = serializer.deltaToRequests(
          deltas: [delta],
          document: doc,
          selection: selection,
        );

        expect(requests, hasLength(2));
        expect(requests[0], isA<DeleteContentRequest>());
        expect(requests[1], isA<InsertTextRequest>());

        final deleteReq = requests[0] as DeleteContentRequest;
        expect(
          deleteReq.selection.base.nodePosition,
          equals(const TextNodePosition(offset: 0)),
        );
        expect(
          deleteReq.selection.extent.nodePosition,
          equals(const TextNodePosition(offset: 5)),
        );

        final insertReq = requests[1] as InsertTextRequest;
        expect(insertReq.nodeId, equals('p1'));
        expect(insertReq.offset, equals(0));
        expect(insertReq.text.text, equals('Hola'));
      });

      test('TextEditingDeltaNonTextUpdate returns empty list', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello'));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 5),
          ),
        );

        final delta = const TextEditingDeltaNonTextUpdate(
          oldText: 'Hello',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange.empty,
        );

        final requests = serializer.deltaToRequests(
          deltas: [delta],
          document: doc,
          selection: selection,
        );

        expect(requests, isEmpty);
      });

      test('multiple deltas produce multiple requests in order', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText(''));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        );

        final deltas = [
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'A',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          ),
          const TextEditingDeltaInsertion(
            oldText: 'A',
            textInserted: 'B',
            insertionOffset: 1,
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
        ];

        final requests = serializer.deltaToRequests(
          deltas: deltas,
          document: doc,
          selection: selection,
        );

        expect(requests, hasLength(2));
        expect(requests[0], isA<InsertTextRequest>());
        expect(requests[1], isA<InsertTextRequest>());
        expect((requests[0] as InsertTextRequest).text.text, equals('A'));
        expect((requests[1] as InsertTextRequest).text.text, equals('B'));
      });

      test('delta with null selection (Mode 2) and insertion at offset 0 is ignored', () {
        // When selection is null we are in Mode 2; insertions at the synthetic
        // offset cannot be mapped to a real node position.
        final node = ParagraphNode(id: 'p1', text: AttributedText(''));
        final doc = Document([node]);

        final delta = const TextEditingDeltaInsertion(
          oldText: '\u200B',
          textInserted: 'X',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        );

        final requests = serializer.deltaToRequests(
          deltas: [delta],
          document: doc,
          selection: null,
        );

        // With no selection we cannot map to a node, so produce empty list.
        expect(requests, isEmpty);
      });

      test('deletion with null selection is ignored', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText('Hello'));
        final doc = Document([node]);

        final delta = const TextEditingDeltaDeletion(
          oldText: '\u200B',
          deletedRange: TextRange(start: 0, end: 1),
          selection: TextSelection.collapsed(offset: 0),
          composing: TextRange.empty,
        );

        final requests = serializer.deltaToRequests(
          deltas: [delta],
          document: doc,
          selection: null,
        );

        expect(requests, isEmpty);
      });

      test('cross-block selection in deltaToRequests returns empty list', () {
        // When the selection spans two nodes, _resolveTargetNodeId returns null
        // and no requests should be produced.
        final n1 = ParagraphNode(id: 'p1', text: AttributedText('First'));
        final n2 = ParagraphNode(id: 'p2', text: AttributedText('Second'));
        final doc = Document([n1, n2]);
        final crossBlockSelection = const DocumentSelection(
          base: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: 'p2',
            nodePosition: TextNodePosition(offset: 3),
          ),
        );

        final delta = const TextEditingDeltaInsertion(
          oldText: '\u200B',
          textInserted: 'X',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        );

        final requests = serializer.deltaToRequests(
          deltas: [delta],
          document: doc,
          selection: crossBlockSelection,
        );

        expect(requests, isEmpty);
      });

      test('non-text node selection in deltaToRequests returns empty list', () {
        // ImageNode is not a TextNode — _resolveTargetNodeId returns null.
        final imageNode = ImageNode(id: 'img1', imageUrl: 'https://example.com/img.png');
        final doc = Document([imageNode]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'img1',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        );

        final delta = const TextEditingDeltaInsertion(
          oldText: '\u200B',
          textInserted: 'X',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        );

        final requests = serializer.deltaToRequests(
          deltas: [delta],
          document: doc,
          selection: selection,
        );

        expect(requests, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // Edge cases
    // -------------------------------------------------------------------------

    group('edge cases', () {
      test('empty document with null selection gives empty TextEditingValue', () {
        final doc = Document();
        final value = serializer.toTextEditingValue(document: doc, selection: null);

        expect(value.text, equals(''));
        expect(value.selection, equals(const TextSelection.collapsed(offset: 0)));
      });

      test('empty paragraph node serializes to empty text', () {
        final node = ParagraphNode(id: 'p1', text: AttributedText(''));
        final doc = Document([node]);
        final selection = const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        );

        final value = serializer.toTextEditingValue(document: doc, selection: selection);

        expect(value.text, equals(''));
        expect(value.selection, equals(const TextSelection.collapsed(offset: 0)));
      });

      test('deltaToRequests with null selection and NonTextUpdate returns empty', () {
        final doc = Document();

        final delta = const TextEditingDeltaNonTextUpdate(
          oldText: '\u200B',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        );

        final requests = serializer.deltaToRequests(
          deltas: [delta],
          document: doc,
          selection: null,
        );

        expect(requests, isEmpty);
      });
    });
  });
}
