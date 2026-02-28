/// Tests for [UndoableEditor] — undo/redo history management.
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MutableDocument _twoParaDoc() => MutableDocument([
      ParagraphNode(id: 'p1', text: AttributedText('Hello world')),
      ParagraphNode(id: 'p2', text: AttributedText('Second paragraph')),
    ]);

EditContext _ctx(MutableDocument doc) => EditContext(
      document: doc,
      controller: DocumentEditingController(document: doc),
    );

UndoableEditor _editor(MutableDocument doc, {int maxUndoLevels = 100}) => UndoableEditor(
      editContext: _ctx(doc),
      maxUndoLevels: maxUndoLevels,
    );

/// A [EditListener] that collects every event batch it receives.
class _CapturingListener implements EditListener {
  final List<List<DocumentChangeEvent>> batches = [];

  @override
  void onEdit(List<DocumentChangeEvent> changes) => batches.add(List.unmodifiable(changes));
}

void main() {
  // =========================================================================
  // canUndo / canRedo initial state
  // =========================================================================

  group('UndoableEditor — initial state', () {
    test('1. canUndo is false initially', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      expect(editor.canUndo, isFalse);
      editor.dispose();
    });

    test('2. canRedo is false initially', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      expect(editor.canRedo, isFalse);
      editor.dispose();
    });

    test('3. canUndo is true after submit', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));

      expect(editor.canUndo, isTrue);
      editor.dispose();
    });

    test('4. canRedo is false after submit (no undo yet)', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));

      expect(editor.canRedo, isFalse);
      editor.dispose();
    });
  });

  // =========================================================================
  // undo — state transitions
  // =========================================================================

  group('UndoableEditor — canUndo/canRedo transitions', () {
    test('1. canRedo is true after undo', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      editor.undo();

      expect(editor.canRedo, isTrue);
      editor.dispose();
    });

    test('2. canUndo is false after undoing all operations', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      editor.undo();

      expect(editor.canUndo, isFalse);
      editor.dispose();
    });

    test('3. canRedo is false after redo', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      editor.undo();
      editor.redo();

      expect(editor.canRedo, isFalse);
      editor.dispose();
    });
  });

  // =========================================================================
  // undo — reverses each request type
  // =========================================================================

  group('UndoableEditor.undo — reverses InsertTextRequest', () {
    test('1. text is restored to pre-insertion state', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 5, text: AttributedText('!!!')));
      // Text is now 'Hello!!! world'
      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello!!! world');

      editor.undo();

      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello world');
      editor.dispose();
    });
  });

  group('UndoableEditor.undo — reverses DeleteContentRequest', () {
    test('1. deleted text is restored', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 5)),
      );

      editor.submit(DeleteContentRequest(selection: sel));
      expect((doc.nodeById('p1') as TextNode).text.text, ' world');

      editor.undo();

      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello world');
      editor.dispose();
    });
  });

  group('UndoableEditor.undo — reverses SplitParagraphRequest', () {
    test('1. nodes merge back after undo', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(const SplitParagraphRequest(nodeId: 'p1', splitOffset: 5));
      expect(doc.nodeCount, 3);

      editor.undo();

      expect(doc.nodeCount, 2);
      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello world');
      editor.dispose();
    });
  });

  group('UndoableEditor.undo — reverses MergeNodeRequest', () {
    test('1. nodes split back after undo', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(const MergeNodeRequest(firstNodeId: 'p1', secondNodeId: 'p2'));
      expect(doc.nodeCount, 1);

      editor.undo();

      expect(doc.nodeCount, 2);
      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello world');
      expect((doc.nodeById('p2') as TextNode).text.text, 'Second paragraph');
      editor.dispose();
    });
  });

  group('UndoableEditor.undo — reverses ChangeBlockTypeRequest', () {
    test('1. block type is restored', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(
        const ChangeBlockTypeRequest(nodeId: 'p1', newBlockType: ParagraphBlockType.header1),
      );
      expect((doc.nodeById('p1') as ParagraphNode).blockType, ParagraphBlockType.header1);

      editor.undo();

      expect((doc.nodeById('p1') as ParagraphNode).blockType, ParagraphBlockType.paragraph);
      editor.dispose();
    });
  });

  group('UndoableEditor.undo — reverses ApplyAttributionRequest', () {
    test('1. attributions are removed after undo', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 4)),
      );

      editor.submit(ApplyAttributionRequest(selection: sel, attribution: NamedAttribution.bold));
      expect(
        (doc.nodeById('p1') as TextNode).text.hasAttributionAt(0, NamedAttribution.bold),
        isTrue,
      );

      editor.undo();

      expect(
        (doc.nodeById('p1') as TextNode).text.hasAttributionAt(0, NamedAttribution.bold),
        isFalse,
      );
      editor.dispose();
    });
  });

  group('UndoableEditor.undo — reverses RemoveAttributionRequest', () {
    test('1. attributions are re-applied after undo', () {
      final boldText = AttributedText('Hello world').applyAttribution(NamedAttribution.bold, 0, 10);
      final doc = MutableDocument([ParagraphNode(id: 'p1', text: boldText)]);
      final editor = UndoableEditor(editContext: _ctx(doc));
      final sel = const DocumentSelection(
        base: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
        extent: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 4)),
      );

      editor.submit(RemoveAttributionRequest(selection: sel, attribution: NamedAttribution.bold));
      expect(
        (doc.nodeById('p1') as TextNode).text.hasAttributionAt(0, NamedAttribution.bold),
        isFalse,
      );

      editor.undo();

      expect(
        (doc.nodeById('p1') as TextNode).text.hasAttributionAt(0, NamedAttribution.bold),
        isTrue,
      );
      editor.dispose();
    });
  });

  group('UndoableEditor.undo — reverses MoveNodeRequest', () {
    test('1. node moves back to original position', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(const MoveNodeRequest(nodeId: 'p2', newIndex: 0));
      expect(doc.nodeAt(0).id, 'p2');

      editor.undo();

      expect(doc.nodeAt(0).id, 'p1');
      expect(doc.nodeAt(1).id, 'p2');
      editor.dispose();
    });
  });

  group('UndoableEditor.undo — reverses ReplaceNodeRequest', () {
    test('1. old node is restored', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);
      final newNode = ParagraphNode(id: 'p1', text: AttributedText('Replaced'));

      editor.submit(ReplaceNodeRequest(nodeId: 'p1', newNode: newNode));
      expect((doc.nodeById('p1') as TextNode).text.text, 'Replaced');

      editor.undo();

      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello world');
      editor.dispose();
    });
  });

  // =========================================================================
  // redo
  // =========================================================================

  group('UndoableEditor.redo', () {
    test('1. redo re-applies an undone InsertTextRequest', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 5, text: AttributedText('!!!')));
      editor.undo();
      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello world');

      editor.redo();

      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello!!! world');
      editor.dispose();
    });

    test('2. redo stack is cleared on new submit', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 5, text: AttributedText('!!!')));
      editor.undo();
      expect(editor.canRedo, isTrue);

      // New submit invalidates redo stack.
      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));

      expect(editor.canRedo, isFalse);
      editor.dispose();
    });

    test('3. redo pushes back onto undo stack (canUndo is true after redo)', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      editor.undo();
      expect(editor.canUndo, isFalse);

      editor.redo();

      expect(editor.canUndo, isTrue);
      editor.dispose();
    });
  });

  // =========================================================================
  // Multiple undo/redo cycles
  // =========================================================================

  group('UndoableEditor — multiple undo/redo cycles', () {
    test('1. multiple consecutive undos restore successive states', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 5, text: AttributedText('A')));
      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 6, text: AttributedText('B')));
      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 7, text: AttributedText('C')));
      // Text is now 'HelloABC world'
      expect((doc.nodeById('p1') as TextNode).text.text, 'HelloABC world');

      editor.undo(); // undo C
      expect((doc.nodeById('p1') as TextNode).text.text, 'HelloAB world');

      editor.undo(); // undo B
      expect((doc.nodeById('p1') as TextNode).text.text, 'HelloA world');

      editor.undo(); // undo A
      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello world');

      editor.dispose();
    });

    test('2. undo then redo then undo again works correctly', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      editor.undo();
      editor.redo();
      editor.undo();

      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello world');
      expect(editor.canUndo, isFalse);
      expect(editor.canRedo, isTrue);
      editor.dispose();
    });

    test('3. alternating undo/redo preserves document integrity', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('A')));
      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 1, text: AttributedText('B')));

      editor.undo();
      editor.undo();
      expect((doc.nodeById('p1') as TextNode).text.text, 'Hello world');

      editor.redo();
      editor.redo();
      expect((doc.nodeById('p1') as TextNode).text.text, 'ABHello world');

      editor.dispose();
    });
  });

  // =========================================================================
  // Error cases
  // =========================================================================

  group('UndoableEditor — error states', () {
    test('1. undo throws StateError when stack is empty', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      expect(() => editor.undo(), throwsStateError);
      editor.dispose();
    });

    test('2. redo throws StateError when stack is empty', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      expect(() => editor.redo(), throwsStateError);
      editor.dispose();
    });

    test('3. undo throws after all operations have been undone', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      editor.undo();

      expect(() => editor.undo(), throwsStateError);
      editor.dispose();
    });

    test('4. redo throws after all undone operations have been redone', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      editor.undo();
      editor.redo();

      expect(() => editor.redo(), throwsStateError);
      editor.dispose();
    });
  });

  // =========================================================================
  // clearHistory
  // =========================================================================

  group('UndoableEditor.clearHistory', () {
    test('1. clears undo stack', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      expect(editor.canUndo, isTrue);

      editor.clearHistory();

      expect(editor.canUndo, isFalse);
      editor.dispose();
    });

    test('2. clears redo stack', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      editor.undo();
      expect(editor.canRedo, isTrue);

      editor.clearHistory();

      expect(editor.canRedo, isFalse);
      editor.dispose();
    });

    test('3. document state is preserved after clearHistory', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      editor.clearHistory();

      // Document mutation from submit() is still there.
      expect((doc.nodeById('p1') as TextNode).text.text, 'XHello world');
      editor.dispose();
    });
  });

  // =========================================================================
  // maxUndoLevels
  // =========================================================================

  group('UndoableEditor — maxUndoLevels', () {
    test('1. undo stack does not exceed maxUndoLevels', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc, maxUndoLevels: 3);

      // Submit 5 inserts; only last 3 should be in the undo stack.
      for (var i = 0; i < 5; i++) {
        editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('$i')));
      }

      // Can undo exactly 3 times.
      editor.undo();
      editor.undo();
      editor.undo();
      expect(editor.canUndo, isFalse);
      editor.dispose();
    });

    test('2. oldest entries are evicted when limit is reached', () {
      final doc = _twoParaDoc();
      final editor = _editor(doc, maxUndoLevels: 2);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('A')));
      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 1, text: AttributedText('B')));
      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 2, text: AttributedText('C')));
      // At this point undo stack holds B and C (A was evicted).

      editor.undo(); // undo C
      editor.undo(); // undo B
      expect(editor.canUndo, isFalse); // A was evicted

      editor.dispose();
    });
  });

  // =========================================================================
  // Selection restore
  // =========================================================================

  group('UndoableEditor — selection restore on undo', () {
    test('1. selection is restored to pre-submit state after undo', () {
      final doc = _twoParaDoc();
      final ctx = _ctx(doc);
      final editor = UndoableEditor(editContext: ctx);

      // Establish a known selection before the operation.
      final initialSel = const DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: 'p1', nodePosition: TextNodePosition(offset: 0)),
      );
      ctx.controller.setSelection(initialSel);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      // After insert selection moved to offset 1.
      expect(ctx.controller.selection?.base.nodePosition, const TextNodePosition(offset: 1));

      editor.undo();

      expect(ctx.controller.selection, initialSel);
      editor.dispose();
    });
  });

  // =========================================================================
  // Listener notifications on undo and redo
  // =========================================================================

  group('UndoableEditor — listener notifications', () {
    test('1. listeners are notified on undo', () {
      final doc = _twoParaDoc();
      final listener = _CapturingListener();
      final editor = UndoableEditor(editContext: _ctx(doc), listeners: [listener]);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      final batchCountAfterSubmit = listener.batches.length;

      editor.undo();

      expect(listener.batches.length, greaterThan(batchCountAfterSubmit));
      editor.dispose();
    });

    test('2. listeners are notified on redo', () {
      final doc = _twoParaDoc();
      final listener = _CapturingListener();
      final editor = UndoableEditor(editContext: _ctx(doc), listeners: [listener]);

      editor.submit(InsertTextRequest(nodeId: 'p1', offset: 0, text: AttributedText('X')));
      editor.undo();
      final batchCountAfterUndo = listener.batches.length;

      editor.redo();

      expect(listener.batches.length, greaterThan(batchCountAfterUndo));
      editor.dispose();
    });
  });
}
