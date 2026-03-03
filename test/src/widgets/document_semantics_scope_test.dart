/// Tests for [DocumentSemanticsScope].
///
/// Covers:
/// - [DocumentSemanticsScope.maybeOf] returning null when no scope is present.
/// - Providing [isFocused] and [isReadOnly] to descendants.
/// - [updateShouldNotify] returning true when values change.
/// - [updateShouldNotify] returning false when values are the same.
/// - [EditableDocument] passing focus state through [DocumentSemanticsScope]
///   so that [RenderTextBlock] children pick up [isFocused].
/// - [EditableDocument.readOnly] flowing to [RenderTextBlock.isReadOnly].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Reads the [DocumentSemanticsScope] from a [BuildContext] and surfaces the
/// values via [ValueNotifier]s so tests can assert on them after build.
class _ScopeReader extends StatelessWidget {
  const _ScopeReader({required this.onScope});

  final void Function(DocumentSemanticsScope? scope) onScope;

  @override
  Widget build(BuildContext context) {
    onScope(DocumentSemanticsScope.maybeOf(context));
    return const SizedBox.shrink();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        ObjectFlagProperty<void Function(DocumentSemanticsScope? scope)>.has('onScope', onScope));
  }
}

/// Installs a no-op mock on [SystemChannels.textInput] so the IME channel
/// does not throw during [EditableDocument] tests.
void _installTextInputMock(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.textInput,
    (MethodCall call) async => null,
  );
}

/// Builds a minimal [DocumentEditingController] with a single paragraph.
DocumentEditingController _makeController({String text = 'Hello'}) {
  final doc = MutableDocument([
    ParagraphNode(id: 'p1', text: AttributedText(text)),
  ]);
  return DocumentEditingController(document: doc);
}

/// Wraps [child] in [MaterialApp] + [Scaffold] for a complete widget env.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // maybeOf — null when absent
  // -------------------------------------------------------------------------

  group('DocumentSemanticsScope.maybeOf', () {
    testWidgets('returns null when no scope is in the tree', (tester) async {
      DocumentSemanticsScope? captured;

      await tester.pumpWidget(
        _wrap(_ScopeReader(onScope: (s) => captured = s)),
      );

      expect(captured, isNull);
    });

    testWidgets('returns the scope instance when present in the tree', (tester) async {
      DocumentSemanticsScope? captured;

      await tester.pumpWidget(
        _wrap(
          DocumentSemanticsScope(
            isFocused: true,
            isReadOnly: false,
            child: _ScopeReader(onScope: (s) => captured = s),
          ),
        ),
      );

      expect(captured, isNotNull);
      expect(captured!.isFocused, isTrue);
      expect(captured!.isReadOnly, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // isFocused / isReadOnly values
  // -------------------------------------------------------------------------

  group('DocumentSemanticsScope — value propagation', () {
    testWidgets('provides isFocused=false and isReadOnly=false to descendants', (tester) async {
      DocumentSemanticsScope? captured;

      await tester.pumpWidget(
        _wrap(
          DocumentSemanticsScope(
            isFocused: false,
            isReadOnly: false,
            child: _ScopeReader(onScope: (s) => captured = s),
          ),
        ),
      );

      expect(captured!.isFocused, isFalse);
      expect(captured!.isReadOnly, isFalse);
    });

    testWidgets('provides isFocused=true and isReadOnly=true to descendants', (tester) async {
      DocumentSemanticsScope? captured;

      await tester.pumpWidget(
        _wrap(
          DocumentSemanticsScope(
            isFocused: true,
            isReadOnly: true,
            child: _ScopeReader(onScope: (s) => captured = s),
          ),
        ),
      );

      expect(captured!.isFocused, isTrue);
      expect(captured!.isReadOnly, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // updateShouldNotify
  // -------------------------------------------------------------------------

  group('DocumentSemanticsScope.updateShouldNotify', () {
    test('returns false when both isFocused and isReadOnly are unchanged', () {
      const a = DocumentSemanticsScope(
        isFocused: false,
        isReadOnly: false,
        child: SizedBox(),
      );
      const b = DocumentSemanticsScope(
        isFocused: false,
        isReadOnly: false,
        child: SizedBox(),
      );

      expect(a.updateShouldNotify(b), isFalse);
    });

    test('returns true when isFocused changes', () {
      const a = DocumentSemanticsScope(
        isFocused: true,
        isReadOnly: false,
        child: SizedBox(),
      );
      const b = DocumentSemanticsScope(
        isFocused: false,
        isReadOnly: false,
        child: SizedBox(),
      );

      expect(a.updateShouldNotify(b), isTrue);
    });

    test('returns true when isReadOnly changes', () {
      const a = DocumentSemanticsScope(
        isFocused: false,
        isReadOnly: true,
        child: SizedBox(),
      );
      const b = DocumentSemanticsScope(
        isFocused: false,
        isReadOnly: false,
        child: SizedBox(),
      );

      expect(a.updateShouldNotify(b), isTrue);
    });

    test('returns true when both isFocused and isReadOnly change', () {
      const a = DocumentSemanticsScope(
        isFocused: true,
        isReadOnly: true,
        child: SizedBox(),
      );
      const b = DocumentSemanticsScope(
        isFocused: false,
        isReadOnly: false,
        child: SizedBox(),
      );

      expect(a.updateShouldNotify(b), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // EditableDocument — focus flows to RenderTextBlock.isFocused
  // -------------------------------------------------------------------------

  group('EditableDocument — semantics scope wiring', () {
    testWidgets('RenderTextBlock.isFocused is true after EditableDocument gains focus',
        (tester) async {
      _installTextInputMock(tester);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            layoutKey: layoutKey,
          ),
        ),
      );

      // Before focusing: all text blocks should report isFocused = false.
      final renderLayout = layoutKey.currentState!.renderObject!;
      RenderDocumentBlock? child = renderLayout.firstChild;
      while (child != null) {
        if (child is RenderTextBlock) {
          expect(child.isFocused, isFalse, reason: 'expected isFocused=false before focus');
        }
        child = renderLayout.childAfter(child);
      }

      // Request focus.
      focusNode.requestFocus();
      await tester.pump();

      // After focusing: all text blocks should report isFocused = true.
      child = renderLayout.firstChild;
      while (child != null) {
        if (child is RenderTextBlock) {
          expect(child.isFocused, isTrue, reason: 'expected isFocused=true after focus');
        }
        child = renderLayout.childAfter(child);
      }
    });

    testWidgets('RenderTextBlock.isFocused returns to false when EditableDocument loses focus',
        (tester) async {
      _installTextInputMock(tester);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            layoutKey: layoutKey,
          ),
        ),
      );

      // Gain focus then lose it. pumpAndSettle ensures the focus system and
      // inherited-widget notifications have fully propagated.
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      focusNode.unfocus();
      await tester.pumpAndSettle();

      final renderLayout = layoutKey.currentState!.renderObject!;
      RenderDocumentBlock? child = renderLayout.firstChild;
      while (child != null) {
        if (child is RenderTextBlock) {
          expect(
            child.isFocused,
            isFalse,
            reason: 'expected isFocused=false after losing focus',
          );
        }
        child = renderLayout.childAfter(child);
      }
    });

    testWidgets('RenderTextBlock.isReadOnly is true when EditableDocument.readOnly is true',
        (tester) async {
      _installTextInputMock(tester);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            layoutKey: layoutKey,
            readOnly: true,
          ),
        ),
      );

      final renderLayout = layoutKey.currentState!.renderObject!;
      RenderDocumentBlock? child = renderLayout.firstChild;
      while (child != null) {
        if (child is RenderTextBlock) {
          expect(
            child.isReadOnly,
            isTrue,
            reason: 'expected isReadOnly=true when EditableDocument.readOnly=true',
          );
        }
        child = renderLayout.childAfter(child);
      }
    });

    testWidgets('RenderTextBlock.isReadOnly is false when EditableDocument.readOnly is false',
        (tester) async {
      _installTextInputMock(tester);

      final controller = _makeController();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      addTearDown(controller.dispose);

      final layoutKey = GlobalKey<DocumentLayoutState>();

      await tester.pumpWidget(
        _wrap(
          EditableDocument(
            controller: controller,
            focusNode: focusNode,
            layoutKey: layoutKey,
            readOnly: false,
          ),
        ),
      );

      final renderLayout = layoutKey.currentState!.renderObject!;
      RenderDocumentBlock? child = renderLayout.firstChild;
      while (child != null) {
        if (child is RenderTextBlock) {
          expect(
            child.isReadOnly,
            isFalse,
            reason: 'expected isReadOnly=false when EditableDocument.readOnly=false',
          );
        }
        child = renderLayout.childAfter(child);
      }
    });
  });
}
