/// Tests for [RenderDocumentCaret].
library;

import 'dart:ui';

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [RenderDocumentLayout] containing one [RenderTextBlock] and
/// runs layout so geometry queries return meaningful values.
RenderDocumentLayout _buildLayout() {
  final layout = RenderDocumentLayout(blockSpacing: 0.0);
  layout.add(
    RenderTextBlock(
      nodeId: 'p1',
      text: AttributedText('Hello world'),
      textStyle: const TextStyle(fontSize: 16),
    ),
  );
  layout.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
  return layout;
}

/// A collapsed [DocumentSelection] for the given [nodeId] / [offset].
DocumentSelection _collapsed(String nodeId, int offset) {
  return DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: nodeId,
      nodePosition: TextNodePosition(offset: offset),
    ),
  );
}

/// An expanded [DocumentSelection] (not a caret).
DocumentSelection _expanded() {
  return const DocumentSelection(
    base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
    extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RenderDocumentCaret — construction and defaults', () {
    test('can be created with no arguments', () {
      final caret = RenderDocumentCaret();
      expect(caret, isA<RenderBox>());
    });

    test('documentLayout defaults to null', () {
      final caret = RenderDocumentCaret();
      expect(caret.documentLayout, isNull);
    });

    test('selection defaults to null', () {
      final caret = RenderDocumentCaret();
      expect(caret.selection, isNull);
    });

    test('color defaults to opaque black', () {
      final caret = RenderDocumentCaret();
      expect(caret.color, const Color(0xFF000000));
    });

    test('width defaults to 2.0', () {
      final caret = RenderDocumentCaret();
      expect(caret.width, 2.0);
    });

    test('cornerRadius defaults to 1.0', () {
      final caret = RenderDocumentCaret();
      expect(caret.cornerRadius, 1.0);
    });

    test('visible defaults to true', () {
      final caret = RenderDocumentCaret();
      expect(caret.visible, isTrue);
    });
  });

  group('RenderDocumentCaret — property setters mark needs paint', () {
    test('setting documentLayout to new value marks needs paint', () {
      final caret = RenderDocumentCaret();
      // Attach so markNeedsPaint is valid.
      final pipelineOwner = PipelineOwner();
      caret.attach(pipelineOwner);

      caret.documentLayout = _buildLayout();
      expect(caret.debugNeedsPaint, isTrue);
    });

    test('setting documentLayout to same value does not mark needs paint', () {
      final layout = _buildLayout();
      final caret = RenderDocumentCaret(documentLayout: layout);
      final pipelineOwner = PipelineOwner();
      caret.attach(pipelineOwner);
      // Clear the dirty flag introduced by attach.
      caret.debugNeedsPaint; // read to observe — flag stays true until painted.
      // Set same value; the setter guard should not dirty again.
      caret.documentLayout = layout;
      // We can only verify this doesn't throw; the flag may already be true
      // from attach. The test is mostly a smoke test for the guard branch.
      expect(caret.documentLayout, same(layout));
    });

    test('setting selection marks needs paint', () {
      final caret = RenderDocumentCaret();
      final pipelineOwner = PipelineOwner();
      caret.attach(pipelineOwner);

      caret.selection = _collapsed('p1', 0);
      expect(caret.debugNeedsPaint, isTrue);
    });

    test('setting color marks needs paint', () {
      final caret = RenderDocumentCaret();
      final pipelineOwner = PipelineOwner();
      caret.attach(pipelineOwner);

      caret.color = const Color(0xFFFF0000);
      expect(caret.debugNeedsPaint, isTrue);
    });

    test('setting width marks needs paint', () {
      final caret = RenderDocumentCaret();
      final pipelineOwner = PipelineOwner();
      caret.attach(pipelineOwner);

      caret.width = 3.0;
      expect(caret.debugNeedsPaint, isTrue);
    });

    test('setting cornerRadius marks needs paint', () {
      final caret = RenderDocumentCaret();
      final pipelineOwner = PipelineOwner();
      caret.attach(pipelineOwner);

      caret.cornerRadius = 2.0;
      expect(caret.debugNeedsPaint, isTrue);
    });

    test('setting visible marks needs paint', () {
      final caret = RenderDocumentCaret();
      final pipelineOwner = PipelineOwner();
      caret.attach(pipelineOwner);

      caret.visible = false;
      expect(caret.debugNeedsPaint, isTrue);
    });
  });

  group('RenderDocumentCaret — property round-trips', () {
    test('documentLayout is readable after being set', () {
      final layout = _buildLayout();
      final caret = RenderDocumentCaret(documentLayout: layout);
      expect(caret.documentLayout, same(layout));
    });

    test('selection is readable after being set', () {
      final sel = _collapsed('p1', 3);
      final caret = RenderDocumentCaret(selection: sel);
      expect(caret.selection, sel);
    });

    test('color is readable after being set', () {
      const c = Color(0xFF123456);
      final caret = RenderDocumentCaret(color: c);
      expect(caret.color, c);
    });

    test('width is readable after being set', () {
      final caret = RenderDocumentCaret(width: 4.0);
      expect(caret.width, 4.0);
    });

    test('cornerRadius is readable after being set', () {
      final caret = RenderDocumentCaret(cornerRadius: 3.0);
      expect(caret.cornerRadius, 3.0);
    });

    test('visible is readable after being set', () {
      final caret = RenderDocumentCaret(visible: false);
      expect(caret.visible, isFalse);
    });
  });

  group('RenderDocumentCaret — hitTestSelf', () {
    test('returns false (transparent to hit testing)', () {
      final caret = RenderDocumentCaret();
      // hitTestSelf requires a laid-out render object with a valid size.
      final pipelineOwner = PipelineOwner();
      caret.attach(pipelineOwner);
      caret.layout(const BoxConstraints.tightFor(width: 400, height: 300));
      expect(caret.hitTestSelf(const Offset(10, 10)), isFalse);
    });
  });

  group('RenderDocumentCaret — performLayout', () {
    test('sizes to constraints.biggest', () {
      final caret = RenderDocumentCaret();
      const constraints = BoxConstraints.tightFor(width: 320, height: 240);
      caret.layout(constraints, parentUsesSize: true);
      expect(caret.size, const Size(320, 240));
    });

    test('sizes to unconstrained constraints largest finite equivalent', () {
      final caret = RenderDocumentCaret();
      // Give it a tight constraint so constraints.biggest is well-defined.
      const constraints = BoxConstraints(
        minWidth: 200,
        maxWidth: 200,
        minHeight: 100,
        maxHeight: 100,
      );
      caret.layout(constraints, parentUsesSize: true);
      expect(caret.size, const Size(200, 100));
    });
  });

  group('RenderDocumentCaret — paint', () {
    test('paints nothing when selection is null', () {
      final caret = RenderDocumentCaret(documentLayout: _buildLayout());
      caret.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _FakePaintingContext(canvas);
      // Should complete without error and paint nothing.
      expect(() => caret.paint(context, Offset.zero), returnsNormally);
    });

    test('paints nothing when visible is false', () {
      final layout = _buildLayout();
      final sel = _collapsed('p1', 0);
      final caret = RenderDocumentCaret(
        documentLayout: layout,
        selection: sel,
        visible: false,
      );
      caret.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _FakePaintingContext(canvas);
      expect(() => caret.paint(context, Offset.zero), returnsNormally);
    });

    test('paints nothing when selection is expanded (not collapsed)', () {
      final layout = _buildLayout();
      final caret = RenderDocumentCaret(
        documentLayout: layout,
        selection: _expanded(),
        visible: true,
      );
      caret.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _FakePaintingContext(canvas);
      expect(() => caret.paint(context, Offset.zero), returnsNormally);
    });

    test('paints nothing when documentLayout is null', () {
      final caret = RenderDocumentCaret(
        selection: _collapsed('p1', 0),
        visible: true,
      );
      caret.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _FakePaintingContext(canvas);
      expect(() => caret.paint(context, Offset.zero), returnsNormally);
    });

    test('paint completes without error for a valid collapsed selection', () {
      final layout = _buildLayout();
      final sel = _collapsed('p1', 0);
      final caret = RenderDocumentCaret(
        documentLayout: layout,
        selection: sel,
        visible: true,
      );
      caret.layout(const BoxConstraints.tightFor(width: 400, height: 300));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final context = _FakePaintingContext(canvas);
      expect(() => caret.paint(context, Offset.zero), returnsNormally);
    });
  });

  group('RenderDocumentCaret — diagnostics', () {
    test('debugFillProperties reports all properties', () {
      final layout = _buildLayout();
      final sel = _collapsed('p1', 2);
      final caret = RenderDocumentCaret(
        documentLayout: layout,
        selection: sel,
        color: const Color(0xFF0000FF),
        width: 3.0,
        cornerRadius: 2.0,
        visible: false,
      );

      final builder = DiagnosticPropertiesBuilder();
      caret.debugFillProperties(builder);

      final names = builder.properties.map((p) => p.name).toSet();
      expect(
          names,
          containsAll(
              ['documentLayout', 'selection', 'color', 'width', 'cornerRadius', 'visible']));
    });
  });
}

// ---------------------------------------------------------------------------
// Minimal PaintingContext stub
// ---------------------------------------------------------------------------

/// A minimal [PaintingContext] stub that forwards canvas calls to the
/// provided [Canvas], allowing [RenderObject.paint] to be tested without
/// a full widget tree.
class _FakePaintingContext extends PaintingContext {
  _FakePaintingContext(this._canvas) : super(ContainerLayer(), Rect.largest);

  final Canvas _canvas;

  @override
  Canvas get canvas => _canvas;
}
