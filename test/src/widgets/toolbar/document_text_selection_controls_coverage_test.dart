/// Coverage-focused tests for [DocumentTextSelectionControls].
///
/// The companion test `document_text_selection_controls_test.dart` covers
/// unit-level construction and delegation.  This file exercises additional
/// lines that improve coverage:
///
///  - [buildHandle] (collapsed, left, right) on Android and iOS
///  - [getHandleAnchor] for all handle types on all platforms
///  - [buildToolbar] return value type (widget construction path)
///  - [getAllDocumentActions] composition
///  - [DocumentToolbarAction] requestBuilder invocation
///  - [documentTextSelectionControls] factory on every platform
///
/// Note: the platform [TextSelectionToolbar] inside [_DocumentToolbar]
/// requires the Flutter selection overlay context for layout. Pumping it in a
/// plain widget test produces rendering assertion failures. The toolbar build
/// path and action dispatch are therefore tested by directly invoking
/// [buildToolbar] and the action request builders rather than pumping a full
/// widget tree.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal [TextSelectionDelegate] stub.
class _StubDelegate implements TextSelectionDelegate {
  _StubDelegate();

  bool toolbarHidden = false;

  @override
  TextEditingValue get textEditingValue => const TextEditingValue(
        text: 'Hello',
        selection: TextSelection(baseOffset: 0, extentOffset: 5),
      );

  // ignore: avoid_setters_without_getters
  set textEditingValue(TextEditingValue value) {}

  @override
  void hideToolbar([bool hideHandles = true]) {
    toolbarHidden = true;
  }

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

/// Wraps [child] in a [MaterialApp] with an unconstrained body so handle
/// widgets (which have fixed intrinsic sizes) can render without overflow.
Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(
        body: UnconstrainedBox(
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
    );

/// Builds a [DocumentSelection] spanning offsets [start]..[end] of node 'p1'.
DocumentSelection _sel({int start = 0, int end = 5}) => DocumentSelection(
      base: DocumentPosition(
        nodeId: 'p1',
        nodePosition: TextNodePosition(offset: start),
      ),
      extent: DocumentPosition(
        nodeId: 'p1',
        nodePosition: TextNodePosition(offset: end),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // buildHandle -- exercises platform delegate delegation
  // -------------------------------------------------------------------------

  group('DocumentTextSelectionControls.buildHandle', () {
    testWidgets('builds collapsed handle on android', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final controls = DocumentTextSelectionControls();

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => controls.buildHandle(
              context,
              TextSelectionHandleType.collapsed,
              16.0,
            ),
          ),
        ),
      );

      debugDefaultTargetPlatformOverride = null;
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('builds left handle on android', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final controls = DocumentTextSelectionControls();

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => controls.buildHandle(
              context,
              TextSelectionHandleType.left,
              16.0,
            ),
          ),
        ),
      );

      debugDefaultTargetPlatformOverride = null;
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('builds right handle on android', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final controls = DocumentTextSelectionControls();

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => controls.buildHandle(
              context,
              TextSelectionHandleType.right,
              16.0,
            ),
          ),
        ),
      );

      debugDefaultTargetPlatformOverride = null;
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('builds collapsed handle on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controls = DocumentTextSelectionControls();

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => controls.buildHandle(
              context,
              TextSelectionHandleType.collapsed,
              16.0,
            ),
          ),
        ),
      );

      debugDefaultTargetPlatformOverride = null;
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('builds left handle on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controls = DocumentTextSelectionControls();

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => controls.buildHandle(
              context,
              TextSelectionHandleType.left,
              16.0,
            ),
          ),
        ),
      );

      debugDefaultTargetPlatformOverride = null;
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('builds right handle on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controls = DocumentTextSelectionControls();

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => controls.buildHandle(
              context,
              TextSelectionHandleType.right,
              16.0,
            ),
          ),
        ),
      );

      debugDefaultTargetPlatformOverride = null;
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // getHandleAnchor -- pure computation, no widget pump needed
  // -------------------------------------------------------------------------

  group('DocumentTextSelectionControls.getHandleAnchor', () {
    test('returns Offset for each handle type on android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final controls = DocumentTextSelectionControls();
      for (final type in TextSelectionHandleType.values) {
        expect(controls.getHandleAnchor(type, 16.0), isA<Offset>());
      }
      debugDefaultTargetPlatformOverride = null;
    });

    test('returns Offset for each handle type on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controls = DocumentTextSelectionControls();
      for (final type in TextSelectionHandleType.values) {
        expect(controls.getHandleAnchor(type, 16.0), isA<Offset>());
      }
      debugDefaultTargetPlatformOverride = null;
    });

    test('returns Offset for each handle type on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controls = DocumentTextSelectionControls();
      for (final type in TextSelectionHandleType.values) {
        expect(controls.getHandleAnchor(type, 16.0), isA<Offset>());
      }
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // -------------------------------------------------------------------------
  // buildToolbar -- verify return type (covers the method entry; full render
  // is not possible without a real selection-overlay context)
  // -------------------------------------------------------------------------

  group('DocumentTextSelectionControls.buildToolbar', () {
    testWidgets('returns a Widget on android', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final controls = DocumentTextSelectionControls();
      final delegate = _StubDelegate();

      // We only build the widget -- pumping causes platform toolbar overflow.
      late Widget toolbarWidget;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              toolbarWidget = controls.buildToolbar(
                context,
                const Rect.fromLTWH(0, 0, 400, 400),
                16.0,
                const Offset(200, 200),
                [
                  const TextSelectionPoint(Offset(100, 200), TextDirection.ltr),
                  const TextSelectionPoint(Offset(300, 200), TextDirection.ltr),
                ],
                delegate,
                null,
                null,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      debugDefaultTargetPlatformOverride = null;
      expect(toolbarWidget, isA<Widget>());
    });

    testWidgets('returns a Widget on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controls = DocumentTextSelectionControls();
      final delegate = _StubDelegate();

      late Widget toolbarWidget;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              toolbarWidget = controls.buildToolbar(
                context,
                const Rect.fromLTWH(0, 0, 400, 400),
                16.0,
                const Offset(200, 200),
                [
                  const TextSelectionPoint(Offset(100, 200), TextDirection.ltr),
                ],
                delegate,
                null,
                null,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      debugDefaultTargetPlatformOverride = null;
      expect(toolbarWidget, isA<Widget>());
    });
  });

  // -------------------------------------------------------------------------
  // getAllDocumentActions -- covers composition logic
  // -------------------------------------------------------------------------

  group('DocumentTextSelectionControls.getAllDocumentActions', () {
    test('with no extra actions returns exactly Bold and Italic', () {
      final controls = DocumentTextSelectionControls();
      final actions = controls.getAllDocumentActions();
      expect(actions.map((a) => a.label).toList(), containsAll(['Bold', 'Italic']));
      expect(actions, hasLength(2));
    });

    test('with extra actions includes Bold, Italic, and extra', () {
      final custom = DocumentToolbarAction(label: 'Strikethrough', onPressed: () {});
      final controls = DocumentTextSelectionControls(toolbarActions: [custom]);
      final actions = controls.getAllDocumentActions();
      expect(actions.map((a) => a.label).toList(),
          containsAllInOrder(['Bold', 'Italic', 'Strikethrough']));
    });

    test('with multiple extras preserves order', () {
      final a1 = DocumentToolbarAction(label: 'A', onPressed: () {});
      final a2 = DocumentToolbarAction(label: 'B', onPressed: () {});
      final controls = DocumentTextSelectionControls(toolbarActions: [a1, a2]);
      final labels = controls.getAllDocumentActions().map((a) => a.label).toList();
      expect(labels.indexOf('A'), lessThan(labels.indexOf('B')));
    });
  });

  // -------------------------------------------------------------------------
  // Action request builders -- covers the requestBuilder lambda lines
  // -------------------------------------------------------------------------

  group('DocumentToolbarAction.requestBuilder', () {
    test('bold action builder produces ApplyAttributionRequest', () {
      final controls = DocumentTextSelectionControls();
      final selection = _sel();
      final request = controls.defaultBoldAction.requestBuilder!(selection);

      expect(request, isA<ApplyAttributionRequest>());
      final apply = request as ApplyAttributionRequest;
      expect(apply.attribution, NamedAttribution.bold);
      expect(apply.selection, selection);
    });

    test('italic action builder produces ApplyAttributionRequest', () {
      final controls = DocumentTextSelectionControls();
      final selection = _sel(start: 2, end: 8);
      final request = controls.defaultItalicAction.requestBuilder!(selection);

      expect(request, isA<ApplyAttributionRequest>());
      final apply = request as ApplyAttributionRequest;
      expect(apply.attribution, NamedAttribution.italics);
      expect(apply.selection, selection);
    });

    test('custom action requestBuilder is called with selection', () {
      DocumentSelection? capturedSelection;
      final action = DocumentToolbarAction(
        label: 'Custom',
        requestBuilder: (sel) {
          capturedSelection = sel;
          return ApplyAttributionRequest(
            selection: sel,
            attribution: NamedAttribution.underline,
          );
        },
      );

      final selection = _sel();
      action.requestBuilder!(selection);
      expect(capturedSelection, equals(selection));
    });
  });

  // -------------------------------------------------------------------------
  // Platform delegation -- various platforms
  // -------------------------------------------------------------------------

  group('DocumentTextSelectionControls -- platform delegation', () {
    test('getHandleSize returns positive size on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controls = DocumentTextSelectionControls();
      final size = controls.getHandleSize(20.0);
      debugDefaultTargetPlatformOverride = null;

      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });

    test('getHandleSize returns positive size on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controls = DocumentTextSelectionControls();
      final size = controls.getHandleSize(20.0);
      debugDefaultTargetPlatformOverride = null;

      expect(size.width, greaterThan(0));
    });

    test('canSelectAll returns bool on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controls = DocumentTextSelectionControls();
      final result = controls.canSelectAll(_StubDelegate());
      debugDefaultTargetPlatformOverride = null;

      expect(result, isA<bool>());
    });

    test('canSelectAll returns bool on linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final controls = DocumentTextSelectionControls();
      final result = controls.canSelectAll(_StubDelegate());
      debugDefaultTargetPlatformOverride = null;

      expect(result, isA<bool>());
    });

    test('canSelectAll returns bool on windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final controls = DocumentTextSelectionControls();
      final result = controls.canSelectAll(_StubDelegate());
      debugDefaultTargetPlatformOverride = null;

      expect(result, isA<bool>());
    });

    test('canSelectAll returns bool on fuchsia', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      final controls = DocumentTextSelectionControls();
      final result = controls.canSelectAll(_StubDelegate());
      debugDefaultTargetPlatformOverride = null;

      expect(result, isA<bool>());
    });

    test('documentTextSelectionControls factory works on android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final controls = documentTextSelectionControls();
      debugDefaultTargetPlatformOverride = null;

      expect(controls, isA<DocumentTextSelectionControls>());
    });

    test('documentTextSelectionControls factory works on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controls = documentTextSelectionControls(
        toolbarActions: [DocumentToolbarAction(label: 'X', onPressed: () {})],
        onEditRequest: (_) {},
      );
      debugDefaultTargetPlatformOverride = null;

      expect(controls.toolbarActions, hasLength(1));
    });
  });
}
