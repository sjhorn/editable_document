/// Tests for [DocumentAutofillClient] — autofill support for single-text-node
/// documents.
///
/// Every branch in [DocumentAutofillClient] is exercised here to satisfy the
/// 100 % branch-coverage requirement on `lib/src/services/`.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [DocumentEditingController] with a single [ParagraphNode].
DocumentEditingController _makeController({
  String nodeId = 'p1',
  String text = '',
  List<String>? autofillHints,
}) {
  final doc = MutableDocument([
    ParagraphNode(id: nodeId, text: AttributedText(text)),
  ]);
  return DocumentEditingController(
    document: doc,
    selection: DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: nodeId,
        nodePosition: TextNodePosition(offset: text.length),
      ),
    ),
    autofillHints: autofillHints,
  );
}

/// Builds a [DocumentAutofillClient] wired to [controller].
DocumentAutofillClient _makeAutofillClient(
  DocumentEditingController controller, {
  List<EditRequest>? requestLog,
}) {
  return DocumentAutofillClient(
    controller: controller,
    serializer: const DocumentImeSerializer(),
    requestHandler: (r) => requestLog?.add(r),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DocumentAutofillClient', () {
    // -----------------------------------------------------------------------
    // enabled
    // -----------------------------------------------------------------------

    group('enabled', () {
      test('returns false when autofillHints is null', () {
        final controller = _makeController(autofillHints: null);
        final client = _makeAutofillClient(controller);
        expect(client.enabled, isFalse);
      });

      test('returns false when autofillHints is empty', () {
        final controller = _makeController(autofillHints: []);
        final client = _makeAutofillClient(controller);
        expect(client.enabled, isFalse);
      });

      test('returns false when document has multiple nodes', () {
        final doc = MutableDocument([
          ParagraphNode(id: 'p1', text: AttributedText('First')),
          ParagraphNode(id: 'p2', text: AttributedText('Second')),
        ]);
        final controller = DocumentEditingController(
          document: doc,
          autofillHints: [AutofillHints.email],
        );
        final client = _makeAutofillClient(controller);
        expect(client.enabled, isFalse);
      });

      test('returns false when single node is not a TextNode (ImageNode)', () {
        final doc = MutableDocument([
          ImageNode(id: 'img1', imageUrl: 'https://example.com/photo.jpg'),
        ]);
        final controller = DocumentEditingController(
          document: doc,
          autofillHints: [AutofillHints.email],
        );
        final client = _makeAutofillClient(controller);
        expect(client.enabled, isFalse);
      });

      test('returns true for single TextNode with non-empty hints', () {
        final controller = _makeController(autofillHints: [AutofillHints.email]);
        final client = _makeAutofillClient(controller);
        expect(client.enabled, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // textInputConfiguration
    // -----------------------------------------------------------------------

    group('textInputConfiguration', () {
      test('returns disabled config when not enabled (null hints)', () {
        final controller = _makeController(autofillHints: null);
        final client = _makeAutofillClient(controller);
        final config = client.textInputConfiguration;
        expect(config.autofillConfiguration, equals(AutofillConfiguration.disabled));
      });

      test('returns disabled config when not enabled (empty hints)', () {
        final controller = _makeController(autofillHints: []);
        final client = _makeAutofillClient(controller);
        final config = client.textInputConfiguration;
        expect(config.autofillConfiguration, equals(AutofillConfiguration.disabled));
      });

      test('returns valid AutofillConfiguration when enabled', () {
        final controller = _makeController(
          text: 'user@example.com',
          autofillHints: [AutofillHints.email],
        );
        final client = _makeAutofillClient(controller);
        final config = client.textInputConfiguration;

        expect(config.autofillConfiguration, isNot(equals(AutofillConfiguration.disabled)));
        expect(
          config.autofillConfiguration.uniqueIdentifier,
          equals(client.autofillId),
        );
        expect(
          config.autofillConfiguration.autofillHints,
          equals([AutofillHints.email]),
        );
        expect(
          config.autofillConfiguration.currentEditingValue.text,
          equals('user@example.com'),
        );
      });
    });

    // -----------------------------------------------------------------------
    // autofillId
    // -----------------------------------------------------------------------

    group('autofillId', () {
      test('contains the hashCode as a string', () {
        final controller = _makeController();
        final client = _makeAutofillClient(controller);
        expect(client.autofillId, contains(client.hashCode.toString()));
      });

      test('is a stable non-empty string', () {
        final controller = _makeController();
        final client = _makeAutofillClient(controller);
        expect(client.autofillId, isNotEmpty);
        expect(client.autofillId, equals(client.autofillId));
      });
    });

    // -----------------------------------------------------------------------
    // autofill
    // -----------------------------------------------------------------------

    group('autofill', () {
      test('is a no-op when not enabled (null hints)', () {
        final requests = <EditRequest>[];
        final controller = _makeController(text: 'original', autofillHints: null);
        final client = _makeAutofillClient(controller, requestLog: requests);

        client.autofill(
          const TextEditingValue(
            text: 'autofilled',
            selection: TextSelection.collapsed(offset: 10),
          ),
        );

        expect(requests, isEmpty);
      });

      test('is a no-op when not enabled (multiple nodes)', () {
        final requests = <EditRequest>[];
        final doc = MutableDocument([
          ParagraphNode(id: 'p1', text: AttributedText('First')),
          ParagraphNode(id: 'p2', text: AttributedText('Second')),
        ]);
        final controller = DocumentEditingController(
          document: doc,
          autofillHints: [AutofillHints.email],
        );
        final client = _makeAutofillClient(controller, requestLog: requests);

        client.autofill(
          const TextEditingValue(
            text: 'autofilled',
            selection: TextSelection.collapsed(offset: 10),
          ),
        );

        expect(requests, isEmpty);
      });

      test('replaces existing text: delete then insert', () {
        final requests = <EditRequest>[];
        final controller = _makeController(
          text: 'old text',
          autofillHints: [AutofillHints.email],
        );
        final client = _makeAutofillClient(controller, requestLog: requests);

        client.autofill(
          const TextEditingValue(
            text: 'new@example.com',
            selection: TextSelection.collapsed(offset: 15),
          ),
        );

        expect(requests, hasLength(2));
        expect(requests[0], isA<DeleteContentRequest>());
        expect(requests[1], isA<InsertTextRequest>());

        final insert = requests[1] as InsertTextRequest;
        expect(insert.text.text, equals('new@example.com'));
        expect(insert.offset, equals(0));
      });

      test('handles empty current text (insert only, no delete)', () {
        final requests = <EditRequest>[];
        final controller = _makeController(
          text: '',
          autofillHints: [AutofillHints.email],
        );
        final client = _makeAutofillClient(controller, requestLog: requests);

        client.autofill(
          const TextEditingValue(
            text: 'hello@example.com',
            selection: TextSelection.collapsed(offset: 17),
          ),
        );

        // No delete (current text is empty), just an insert.
        expect(requests, hasLength(1));
        expect(requests.first, isA<InsertTextRequest>());

        final insert = requests.first as InsertTextRequest;
        expect(insert.text.text, equals('hello@example.com'));
      });

      test('handles empty new text (delete only, no insert)', () {
        final requests = <EditRequest>[];
        final controller = _makeController(
          text: 'to be deleted',
          autofillHints: [AutofillHints.email],
        );
        final client = _makeAutofillClient(controller, requestLog: requests);

        client.autofill(
          const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          ),
        );

        // Delete the old text, no insert needed.
        expect(requests, hasLength(1));
        expect(requests.first, isA<DeleteContentRequest>());
      });

      test('same text updates selection only (no EditRequests)', () {
        final requests = <EditRequest>[];
        final controller = _makeController(
          text: 'same text',
          autofillHints: [AutofillHints.email],
        );
        final client = _makeAutofillClient(controller, requestLog: requests);

        client.autofill(
          const TextEditingValue(
            text: 'same text',
            selection: TextSelection(baseOffset: 2, extentOffset: 5),
          ),
        );

        // No requests for text mutation — text hasn't changed.
        expect(requests, isEmpty);

        // But the controller selection should be updated.
        final sel = controller.selection;
        expect(sel, isNotNull);
        expect(sel!.base.nodePosition, isA<TextNodePosition>());
        expect((sel.base.nodePosition as TextNodePosition).offset, equals(2));
        expect((sel.extent.nodePosition as TextNodePosition).offset, equals(5));
      });

      test('updates selection after replacing text', () {
        final requests = <EditRequest>[];
        final controller = _makeController(
          text: 'old',
          autofillHints: [AutofillHints.password],
        );
        final client = _makeAutofillClient(controller, requestLog: requests);

        client.autofill(
          const TextEditingValue(
            text: 'newpassword',
            selection: TextSelection.collapsed(offset: 11),
          ),
        );

        // Verify selection was updated after the text replacement.
        final sel = controller.selection;
        expect(sel, isNotNull);
        expect((sel!.base.nodePosition as TextNodePosition).offset, equals(11));
        expect((sel.extent.nodePosition as TextNodePosition).offset, equals(11));
      });
    });
  });
}
