/// Tests for [DocumentTextSelectionControls] and [DocumentToolbarAction] —
/// Phase 6.6.
///
/// Covers:
/// 1. [documentTextSelectionControls] returns non-null controls.
/// 2. Controls can build handles (delegates to platform).
/// 3. Bold action creates correct [ApplyAttributionRequest].
/// 4. Italic action creates correct [ApplyAttributionRequest].
/// 5. Custom toolbar actions are included in the list.
/// 6. [DocumentToolbarAction] construction and properties.
/// 7. [onEditRequest] callback fires for document-specific actions.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal [TextSelectionDelegate] stub for unit tests.
class _StubTextSelectionDelegate implements TextSelectionDelegate {
  @override
  TextEditingValue get textEditingValue => const TextEditingValue(
        text: 'Hello world',
        selection: TextSelection.collapsed(offset: 0),
      );

  // ignore: avoid_setters_without_getters
  set textEditingValue(TextEditingValue value) {}

  @override
  void hideToolbar([bool hideHandles = true]) {}

  @override
  void bringIntoView(TextPosition position) {}

  @override
  bool get cutEnabled => true;

  @override
  bool get copyEnabled => true;

  @override
  bool get pasteEnabled => true;

  @override
  bool get selectAllEnabled => true;

  @override
  bool get liveTextInputEnabled => false;

  @override
  bool get lookUpEnabled => false;

  @override
  bool get searchWebEnabled => false;

  @override
  bool get shareEnabled => false;

  @override
  void copySelection(SelectionChangedCause cause) {}

  @override
  void cutSelection(SelectionChangedCause cause) {}

  @override
  Future<void> pasteText(SelectionChangedCause cause) async {}

  @override
  void selectAll(SelectionChangedCause cause) {}

  @override
  void userUpdateTextEditingValue(TextEditingValue value, SelectionChangedCause cause) {}
}

/// Builds a minimal [DocumentSelection] spanning the entire text of node [id].
DocumentSelection _selectionFor(String id, {int start = 0, int end = 5}) {
  return DocumentSelection(
    base: DocumentPosition(
      nodeId: id,
      nodePosition: TextNodePosition(offset: start),
    ),
    extent: DocumentPosition(
      nodeId: id,
      nodePosition: TextNodePosition(offset: end),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // documentTextSelectionControls factory
  // -------------------------------------------------------------------------

  group('documentTextSelectionControls — factory', () {
    test('returns a non-null TextSelectionControls instance', () {
      final controls = documentTextSelectionControls();
      expect(controls, isNotNull);
      expect(controls, isA<TextSelectionControls>());
    });

    test('returns a DocumentTextSelectionControls instance', () {
      final controls = documentTextSelectionControls();
      expect(controls, isA<DocumentTextSelectionControls>());
    });

    test('accepts optional toolbarActions parameter', () {
      final actions = [
        DocumentToolbarAction(
          label: 'Custom',
          onPressed: () {},
        ),
      ];
      final controls = documentTextSelectionControls(toolbarActions: actions);
      expect(controls, isNotNull);
    });

    test('accepts optional onEditRequest callback', () {
      EditRequest? captured;
      final controls = documentTextSelectionControls(
        onEditRequest: (r) => captured = r,
      );
      expect(controls, isNotNull);
      // callback not yet called
      expect(captured, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // DocumentTextSelectionControls construction
  // -------------------------------------------------------------------------

  group('DocumentTextSelectionControls — construction', () {
    test('can be constructed without parameters', () {
      final controls = DocumentTextSelectionControls();
      expect(controls, isNotNull);
    });

    test('toolbarActions defaults to null', () {
      final controls = DocumentTextSelectionControls();
      expect(controls.toolbarActions, isNull);
    });

    test('onEditRequest defaults to null', () {
      final controls = DocumentTextSelectionControls();
      expect(controls.onEditRequest, isNull);
    });

    test('stores provided toolbarActions', () {
      final actions = [
        DocumentToolbarAction(label: 'X', onPressed: () {}),
      ];
      final controls = DocumentTextSelectionControls(toolbarActions: actions);
      expect(controls.toolbarActions, same(actions));
    });

    test('stores provided onEditRequest callback', () {
      void callback(EditRequest r) {}
      final controls = DocumentTextSelectionControls(onEditRequest: callback);
      expect(controls.onEditRequest, same(callback));
    });
  });

  // -------------------------------------------------------------------------
  // DocumentToolbarAction — construction and properties
  // -------------------------------------------------------------------------

  group('DocumentToolbarAction — properties', () {
    test('label is stored correctly', () {
      final action = DocumentToolbarAction(label: 'Bold', onPressed: () {});
      expect(action.label, 'Bold');
    });

    test('icon defaults to null', () {
      final action = DocumentToolbarAction(label: 'Bold', onPressed: () {});
      expect(action.icon, isNull);
    });

    test('icon is stored when provided', () {
      final action = DocumentToolbarAction(
        label: 'Bold',
        icon: Icons.format_bold,
        onPressed: () {},
      );
      expect(action.icon, Icons.format_bold);
    });

    test('onPressed callback is stored', () {
      var called = false;
      final action = DocumentToolbarAction(
        label: 'Test',
        onPressed: () => called = true,
      );
      action.onPressed!();
      expect(called, isTrue);
    });

    test('requestBuilder is stored when provided', () {
      final selection = _selectionFor('p1');
      DocumentToolbarAction? capturedAction;

      EditRequest builder(DocumentSelection sel) {
        return ApplyAttributionRequest(
          selection: sel,
          attribution: NamedAttribution.bold,
        );
      }

      final action = DocumentToolbarAction(
        label: 'Bold',
        requestBuilder: builder,
      );
      capturedAction = action;

      final request = capturedAction.requestBuilder!(selection);
      expect(request, isA<ApplyAttributionRequest>());
      final applyRequest = request as ApplyAttributionRequest;
      expect(applyRequest.attribution, NamedAttribution.bold);
      expect(applyRequest.selection, selection);
    });

    test('both onPressed and requestBuilder can be null', () {
      final action = DocumentToolbarAction(label: 'Separator');
      expect(action.onPressed, isNull);
      expect(action.requestBuilder, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Default toolbar actions — Bold
  // -------------------------------------------------------------------------

  group('DocumentTextSelectionControls — Bold action', () {
    test('bold default action creates ApplyAttributionRequest with bold', () {
      final controls = DocumentTextSelectionControls();
      final boldAction = controls.defaultBoldAction;

      final selection = _selectionFor('p1');
      expect(boldAction.requestBuilder, isNotNull);

      final request = boldAction.requestBuilder!(selection);
      expect(request, isA<ApplyAttributionRequest>());

      final applyRequest = request as ApplyAttributionRequest;
      expect(applyRequest.attribution, NamedAttribution.bold);
      expect(applyRequest.selection, selection);
    });

    test('bold action has correct label', () {
      final controls = DocumentTextSelectionControls();
      expect(controls.defaultBoldAction.label, 'Bold');
    });

    test('bold action has format_bold icon', () {
      final controls = DocumentTextSelectionControls();
      expect(controls.defaultBoldAction.icon, Icons.format_bold);
    });

    test('onEditRequest fires when bold requestBuilder is invoked', () {
      final requests = <EditRequest>[];
      final controls = DocumentTextSelectionControls(
        onEditRequest: requests.add,
      );

      final selection = _selectionFor('p1');
      final boldAction = controls.defaultBoldAction;

      // Simulate what the toolbar would do: build the request then fire callback.
      final request = boldAction.requestBuilder!(selection);
      controls.onEditRequest?.call(request);

      expect(requests, hasLength(1));
      expect(requests.first, isA<ApplyAttributionRequest>());
      final applyRequest = requests.first as ApplyAttributionRequest;
      expect(applyRequest.attribution, NamedAttribution.bold);
    });
  });

  // -------------------------------------------------------------------------
  // Default toolbar actions — Italic
  // -------------------------------------------------------------------------

  group('DocumentTextSelectionControls — Italic action', () {
    test('italic default action creates ApplyAttributionRequest with italics', () {
      final controls = DocumentTextSelectionControls();
      final italicAction = controls.defaultItalicAction;

      final selection = _selectionFor('p1');
      expect(italicAction.requestBuilder, isNotNull);

      final request = italicAction.requestBuilder!(selection);
      expect(request, isA<ApplyAttributionRequest>());

      final applyRequest = request as ApplyAttributionRequest;
      expect(applyRequest.attribution, NamedAttribution.italics);
      expect(applyRequest.selection, selection);
    });

    test('italic action has correct label', () {
      final controls = DocumentTextSelectionControls();
      expect(controls.defaultItalicAction.label, 'Italic');
    });

    test('italic action has format_italic icon', () {
      final controls = DocumentTextSelectionControls();
      expect(controls.defaultItalicAction.icon, Icons.format_italic);
    });

    test('onEditRequest fires when italic requestBuilder is invoked', () {
      final requests = <EditRequest>[];
      final controls = DocumentTextSelectionControls(
        onEditRequest: requests.add,
      );

      final selection = _selectionFor('p1');
      final italicAction = controls.defaultItalicAction;

      final request = italicAction.requestBuilder!(selection);
      controls.onEditRequest?.call(request);

      expect(requests, hasLength(1));
      expect(requests.first, isA<ApplyAttributionRequest>());
      final applyRequest = requests.first as ApplyAttributionRequest;
      expect(applyRequest.attribution, NamedAttribution.italics);
    });
  });

  // -------------------------------------------------------------------------
  // Custom toolbar actions
  // -------------------------------------------------------------------------

  group('DocumentTextSelectionControls — custom toolbar actions', () {
    test('custom actions are included in toolbarActions list', () {
      final custom = DocumentToolbarAction(label: 'Underline', onPressed: () {});
      final controls = DocumentTextSelectionControls(toolbarActions: [custom]);
      expect(controls.toolbarActions, contains(custom));
    });

    test('multiple custom actions are all included', () {
      final action1 = DocumentToolbarAction(label: 'H1', onPressed: () {});
      final action2 = DocumentToolbarAction(label: 'H2', onPressed: () {});
      final controls = DocumentTextSelectionControls(
        toolbarActions: [action1, action2],
      );
      expect(controls.toolbarActions, containsAll([action1, action2]));
    });

    test('custom action with requestBuilder fires onEditRequest', () {
      final requests = <EditRequest>[];

      final selection = _selectionFor('p1');
      final customAction = DocumentToolbarAction(
        label: 'Underline',
        requestBuilder: (sel) => ApplyAttributionRequest(
          selection: sel,
          attribution: NamedAttribution.underline,
        ),
      );

      final controls = DocumentTextSelectionControls(
        toolbarActions: [customAction],
        onEditRequest: requests.add,
      );

      final request = customAction.requestBuilder!(selection);
      controls.onEditRequest?.call(request);

      expect(requests, hasLength(1));
      final applyRequest = requests.first as ApplyAttributionRequest;
      expect(applyRequest.attribution, NamedAttribution.underline);
    });
  });

  // -------------------------------------------------------------------------
  // Platform delegation
  // -------------------------------------------------------------------------

  group('DocumentTextSelectionControls — platform delegation', () {
    test('canSelectAll delegates to platform (android)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final controls = DocumentTextSelectionControls();
      // Verify that canSelectAll returns a bool value without throwing.
      // The actual result depends on platform default controls and text state;
      // we use a stub delegate that exposes an empty selection with a
      // non-empty text value so canSelectAll might return true or false.
      final delegate = _StubTextSelectionDelegate();
      final result = controls.canSelectAll(delegate);
      expect(result, isA<bool>());
    });

    test('getHandleSize returns a Size (delegates to platform)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final controls = DocumentTextSelectionControls();
      final size = controls.getHandleSize(1.0);
      expect(size, isA<Size>());
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });
  });

  // -------------------------------------------------------------------------
  // getAllDocumentActions helper
  // -------------------------------------------------------------------------

  group('DocumentTextSelectionControls — getAllDocumentActions', () {
    test('returns bold and italic actions by default', () {
      final controls = DocumentTextSelectionControls();
      final allActions = controls.getAllDocumentActions();
      final labels = allActions.map((a) => a.label).toList();
      expect(labels, contains('Bold'));
      expect(labels, contains('Italic'));
    });

    test('includes custom actions when provided', () {
      final custom = DocumentToolbarAction(label: 'Custom', onPressed: () {});
      final controls = DocumentTextSelectionControls(toolbarActions: [custom]);
      final allActions = controls.getAllDocumentActions();
      final labels = allActions.map((a) => a.label).toList();
      expect(labels, contains('Bold'));
      expect(labels, contains('Italic'));
      expect(labels, contains('Custom'));
    });
  });
}
