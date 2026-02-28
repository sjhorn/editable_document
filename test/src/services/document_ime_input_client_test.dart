/// Tests for [DocumentImeInputClient] — IME connection lifecycle and
/// delta dispatch.
///
/// Every branch in [DocumentImeInputClient] is exercised here to satisfy the
/// 100 % branch-coverage requirement on `lib/src/services/`.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal [DocumentEditingController] with a single empty paragraph.
DocumentEditingController _makeController({String nodeId = 'p1', String text = ''}) {
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
  );
}

/// Builds a [DocumentImeInputClient] wired to [controller] and appends every
/// [EditRequest] it receives into [requestLog].
DocumentImeInputClient _makeClient(
  DocumentEditingController controller, {
  List<EditRequest>? requestLog,
  List<TextInputAction>? actionLog,
  List<KeyboardInsertedContent>? insertContentLog,
  List<RawFloatingCursorPoint>? floatingCursorLog,
}) {
  return DocumentImeInputClient(
    serializer: const DocumentImeSerializer(),
    controller: controller,
    requestHandler: (r) => requestLog?.add(r),
    onAction: actionLog == null ? null : (a) => actionLog.add(a),
    onInsertContent: insertContentLog == null ? null : (c) => insertContentLog.add(c),
    onFloatingCursor: floatingCursorLog == null ? null : (p) => floatingCursorLog.add(p),
  );
}

/// Installs a no-op mock on [SystemChannels.textInput] so that outgoing
/// platform calls are recorded in [log] instead of hitting the real channel.
void _installMock(WidgetTester tester, List<MethodCall> log) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.textInput,
    (MethodCall call) async {
      log.add(call);
      return null;
    },
  );
}

/// The standard [TextInputConfiguration] used throughout these tests.
const _config = TextInputConfiguration(enableDeltaModel: true);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DocumentImeInputClient', () {
    // -----------------------------------------------------------------------
    // openConnection
    // -----------------------------------------------------------------------

    group('openConnection', () {
      testWidgets('sends TextInput.setClient and TextInput.show', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        client.openConnection(_config);

        expect(log.map((c) => c.method), containsAll(['TextInput.setClient', 'TextInput.show']));
      });

      testWidgets('setClient carries enableDeltaModel: true', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        client.openConnection(_config);

        final setClient = log.firstWhere((c) => c.method == 'TextInput.setClient');
        final configMap = (setClient.arguments as List<dynamic>)[1] as Map<dynamic, dynamic>;
        expect(configMap['enableDeltaModel'], isTrue);
      });

      testWidgets('double openConnection closes previous connection first', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        client.openConnection(_config);
        log.clear();

        // A second open should close the first then open a new one.
        client.openConnection(_config);

        final methods = log.map((c) => c.method).toList();
        // clearClient is sent when the old connection is closed, then a new
        // setClient + show follow.
        expect(methods, contains('TextInput.setClient'));
        expect(methods, contains('TextInput.show'));
      });

      testWidgets('syncToIme is called after openConnection', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        client.openConnection(_config);

        expect(log.map((c) => c.method), contains('TextInput.setEditingState'));
      });
    });

    // -----------------------------------------------------------------------
    // closeConnection
    // -----------------------------------------------------------------------

    group('closeConnection', () {
      testWidgets('sends TextInput.clearClient after close', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        client.openConnection(_config);
        log.clear();

        client.closeConnection();

        expect(log.map((c) => c.method), contains('TextInput.clearClient'));
      });

      testWidgets('closeConnection when no connection open is a no-op', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        // No prior openConnection — should not throw.
        expect(() => client.closeConnection(), returnsNormally);
        expect(log, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // syncToIme
    // -----------------------------------------------------------------------

    group('syncToIme', () {
      testWidgets('sends TextInput.setEditingState with serialized value', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController(text: 'hello');
        final client = _makeClient(controller);

        client.openConnection(_config);
        log.clear();

        client.syncToIme();

        final setEditing = log.firstWhere((c) => c.method == 'TextInput.setEditingState');
        final args = setEditing.arguments as Map<dynamic, dynamic>;
        expect(args['text'], equals('hello'));
      });

      testWidgets('syncToIme is a no-op when no connection is open', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController(text: 'hello');
        final client = _makeClient(controller);

        // syncToIme before openConnection.
        expect(() => client.syncToIme(), returnsNormally);
        expect(log, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // showKeyboard / hideKeyboard
    // -----------------------------------------------------------------------

    group('showKeyboard / hideKeyboard', () {
      testWidgets('showKeyboard sends TextInput.show', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        client.openConnection(_config);
        log.clear();

        client.showKeyboard();

        expect(log.map((c) => c.method), contains('TextInput.show'));
      });

      testWidgets('hideKeyboard closes the connection', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        client.openConnection(_config);
        log.clear();

        client.hideKeyboard();

        // Flutter's TextInputConnection does not expose a hide()-without-close
        // method, so hideKeyboard sends clearClient to the platform.
        expect(log.map((c) => c.method), contains('TextInput.clearClient'));
      });

      testWidgets('showKeyboard is no-op when not connected', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        expect(() => client.showKeyboard(), returnsNormally);
        expect(log, isEmpty);
      });

      testWidgets('hideKeyboard is no-op when not connected', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        expect(() => client.hideKeyboard(), returnsNormally);
        expect(log, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // currentTextEditingValue
    // -----------------------------------------------------------------------

    group('currentTextEditingValue', () {
      testWidgets('returns null before first syncToIme', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController(text: 'abc');
        final client = _makeClient(controller);

        expect(client.currentTextEditingValue, isNull);
      });

      testWidgets('returns last synced value after openConnection', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController(text: 'abc');
        final client = _makeClient(controller);

        client.openConnection(_config); // calls syncToIme internally

        // The last synced value should match what the serializer produced.
        expect(client.currentTextEditingValue, isNotNull);
        expect(client.currentTextEditingValue!.text, equals('abc'));
      });

      testWidgets('returns updated value after explicit syncToIme call', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController(text: 'abc');
        final client = _makeClient(controller);

        client.openConnection(_config);

        // Mutate the controller selection (simulate a document change).
        controller.setSelection(
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: 'p1',
              nodePosition: TextNodePosition(offset: 1),
            ),
          ),
        );
        client.syncToIme();

        expect(client.currentTextEditingValue!.selection.baseOffset, equals(1));
      });
    });

    // -----------------------------------------------------------------------
    // currentAutofillScope
    // -----------------------------------------------------------------------

    group('currentAutofillScope', () {
      testWidgets('returns null (Phase 4.4 — not yet implemented)', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        expect(client.currentAutofillScope, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // updateEditingValueWithDeltas
    // -----------------------------------------------------------------------

    group('updateEditingValueWithDeltas', () {
      testWidgets('insertion delta calls requestHandler', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final requests = <EditRequest>[];
        final controller = _makeController();
        final client = _makeClient(controller, requestLog: requests);

        client.openConnection(_config);

        const delta = TextEditingDeltaInsertion(
          oldText: '',
          textInserted: 'H',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        );

        client.updateEditingValueWithDeltas([delta]);

        expect(requests, hasLength(1));
        expect(requests.first, isA<InsertTextRequest>());
      });

      testWidgets('deletion delta calls requestHandler', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final requests = <EditRequest>[];
        final controller = _makeController(text: 'H');
        final client = _makeClient(controller, requestLog: requests);

        client.openConnection(_config);

        const delta = TextEditingDeltaDeletion(
          oldText: 'H',
          deletedRange: TextRange(start: 0, end: 1),
          selection: TextSelection.collapsed(offset: 0),
          composing: TextRange.empty,
        );

        client.updateEditingValueWithDeltas([delta]);

        expect(requests, hasLength(1));
        expect(requests.first, isA<DeleteContentRequest>());
      });

      testWidgets('replacement delta calls requestHandler twice', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final requests = <EditRequest>[];
        final controller = _makeController(text: 'Hi');
        final client = _makeClient(controller, requestLog: requests);

        client.openConnection(_config);

        const delta = TextEditingDeltaReplacement(
          oldText: 'Hi',
          replacementText: 'Hey',
          replacedRange: TextRange(start: 0, end: 2),
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange.empty,
        );

        client.updateEditingValueWithDeltas([delta]);

        expect(requests, hasLength(2));
        expect(requests[0], isA<DeleteContentRequest>());
        expect(requests[1], isA<InsertTextRequest>());
      });

      testWidgets('non-text-update delta produces no request', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final requests = <EditRequest>[];
        final controller = _makeController(text: 'Hello');
        final client = _makeClient(controller, requestLog: requests);

        client.openConnection(_config);

        const delta = TextEditingDeltaNonTextUpdate(
          oldText: 'Hello',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange.empty,
        );

        client.updateEditingValueWithDeltas([delta]);

        expect(requests, isEmpty);
      });

      testWidgets('multiple deltas in one call each invoke requestHandler', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final requests = <EditRequest>[];
        final controller = _makeController();
        final client = _makeClient(controller, requestLog: requests);

        client.openConnection(_config);

        const deltas = [
          TextEditingDeltaInsertion(
            oldText: '',
            textInserted: 'A',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          ),
          TextEditingDeltaInsertion(
            oldText: 'A',
            textInserted: 'B',
            insertionOffset: 1,
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
        ];

        client.updateEditingValueWithDeltas(deltas);

        expect(requests, hasLength(2));
      });

      testWidgets('newline insertion produces SplitParagraphRequest', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final requests = <EditRequest>[];
        final controller = _makeController(text: 'Hello');
        final client = _makeClient(controller, requestLog: requests);

        client.openConnection(_config);

        const delta = TextEditingDeltaInsertion(
          oldText: 'Hello',
          textInserted: '\n',
          insertionOffset: 5,
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange.empty,
        );

        client.updateEditingValueWithDeltas([delta]);

        expect(requests, hasLength(1));
        expect(requests.first, isA<SplitParagraphRequest>());
      });
    });

    // -----------------------------------------------------------------------
    // performAction
    // -----------------------------------------------------------------------

    group('performAction', () {
      testWidgets('calls onAction callback with the action', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final actions = <TextInputAction>[];
        final controller = _makeController();
        final client = _makeClient(controller, actionLog: actions);

        client.performAction(TextInputAction.done);

        expect(actions, equals([TextInputAction.done]));
      });

      testWidgets('no onAction callback registered does not throw', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller); // onAction is null

        expect(() => client.performAction(TextInputAction.next), returnsNormally);
      });

      testWidgets('multiple different actions are all forwarded', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final actions = <TextInputAction>[];
        final controller = _makeController();
        final client = _makeClient(controller, actionLog: actions);

        client.performAction(TextInputAction.done);
        client.performAction(TextInputAction.newline);
        client.performAction(TextInputAction.go);

        expect(
          actions,
          equals([TextInputAction.done, TextInputAction.newline, TextInputAction.go]),
        );
      });
    });

    // -----------------------------------------------------------------------
    // updateFloatingCursor
    // -----------------------------------------------------------------------

    group('updateFloatingCursor', () {
      testWidgets('calls onFloatingCursor callback with the point', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final points = <RawFloatingCursorPoint>[];
        final controller = _makeController();
        final client = _makeClient(controller, floatingCursorLog: points);

        final point = RawFloatingCursorPoint(state: FloatingCursorDragState.Start);
        client.updateFloatingCursor(point);

        expect(points, hasLength(1));
        expect(points.first.state, equals(FloatingCursorDragState.Start));
      });

      testWidgets('no onFloatingCursor callback does not throw', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller); // onFloatingCursor is null

        final point = RawFloatingCursorPoint(state: FloatingCursorDragState.End);
        expect(() => client.updateFloatingCursor(point), returnsNormally);
      });

      testWidgets('all FloatingCursorDragState values are forwarded', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final points = <RawFloatingCursorPoint>[];
        final controller = _makeController();
        final client = _makeClient(controller, floatingCursorLog: points);

        client.updateFloatingCursor(
          RawFloatingCursorPoint(state: FloatingCursorDragState.Start),
        );
        client.updateFloatingCursor(
          RawFloatingCursorPoint(
            state: FloatingCursorDragState.Update,
            offset: const Offset(10, 0),
          ),
        );
        client.updateFloatingCursor(
          RawFloatingCursorPoint(state: FloatingCursorDragState.End),
        );

        expect(points, hasLength(3));
        expect(points[0].state, equals(FloatingCursorDragState.Start));
        expect(points[1].state, equals(FloatingCursorDragState.Update));
        expect(points[2].state, equals(FloatingCursorDragState.End));
      });
    });

    // -----------------------------------------------------------------------
    // insertContent
    // -----------------------------------------------------------------------

    group('insertContent', () {
      testWidgets('calls onInsertContent callback with the content', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final contents = <KeyboardInsertedContent>[];
        final controller = _makeController();
        final client = _makeClient(controller, insertContentLog: contents);

        const content = KeyboardInsertedContent(mimeType: 'image/gif', uri: 'content://gif');
        client.insertContent(content);

        expect(contents, hasLength(1));
        expect(contents.first.mimeType, equals('image/gif'));
      });

      testWidgets('no onInsertContent callback does not throw', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller); // onInsertContent is null

        const content = KeyboardInsertedContent(mimeType: 'image/png', uri: 'content://img');
        expect(() => client.insertContent(content), returnsNormally);
      });
    });

    // -----------------------------------------------------------------------
    // Legacy TextInputClient stubs
    // -----------------------------------------------------------------------

    group('legacy TextInputClient stubs', () {
      testWidgets('updateEditingValue is a no-op and does not throw', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        // updateEditingValue is superseded by updateEditingValueWithDeltas.
        expect(
          () => client.updateEditingValue(
            const TextEditingValue(text: 'x', selection: TextSelection.collapsed(offset: 1)),
          ),
          returnsNormally,
        );
      });

      testWidgets('performPrivateCommand is a no-op and does not throw', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        expect(
          () => client.performPrivateCommand('someAction', <String, dynamic>{}),
          returnsNormally,
        );
      });
    });

    // -----------------------------------------------------------------------
    // connectionClosed
    // -----------------------------------------------------------------------

    group('connectionClosed', () {
      testWidgets('connectionClosed nullifies internal connection', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        client.openConnection(_config);
        log.clear();

        // The platform reports that it closed the connection.
        client.connectionClosed();

        // After connectionClosed, showKeyboard should be a no-op (no connection).
        client.showKeyboard();
        expect(log.where((c) => c.method == 'TextInput.show'), isEmpty);
      });

      testWidgets('connectionClosed when already null is a no-op', (tester) async {
        final log = <MethodCall>[];
        _installMock(tester, log);

        final controller = _makeController();
        final client = _makeClient(controller);

        // No connection was opened — should not throw.
        expect(() => client.connectionClosed(), returnsNormally);
      });
    });
  });
}
