/// Document editing [Action]s for the editable_document package.
///
/// Maps Flutter's built-in [Intent] classes (from `DefaultTextEditingShortcuts`)
/// and this package's own document-specific intents to document editing
/// operations.
///
/// ## Usage
///
/// The public surface of this file is:
///
/// * [DocumentEditingDelegate] — abstract interface that [EditableDocumentState]
///   implements.
/// * [createDocumentEditingActions] — factory that builds the full
///   `Map<Type, Action<Intent>>` passed to the [Actions] widget.
/// * [isSelectionFullyAttributed] — helper for toggle-attribution logic.
library;

import 'package:flutter/widgets.dart';

import '../model/attribution.dart';
import '../model/document.dart';
import '../model/document_selection.dart';
import '../model/node_position.dart';
import '../model/table_node.dart';
import '../model/text_node.dart';
import 'document_editing_intents.dart';

// ---------------------------------------------------------------------------
// DocumentEditingDelegate
// ---------------------------------------------------------------------------

/// Abstract interface that provides document editing operations to [Action]s.
///
/// [EditableDocumentState] implements this interface. The [Action] objects in
/// this file hold a `DocumentEditingDelegate Function()` getter and call
/// methods on the delegate, keeping the actions independent of the concrete
/// state class and breaking the circular import between
/// `document_editing_actions.dart` and `editable_document.dart`.
abstract class DocumentEditingDelegate {
  /// Moves the caret one character forward or backward.
  void moveByCharacter({required bool forward, required bool extend});

  /// Moves the caret to the next or previous word boundary.
  void moveByWord({required bool forward, required bool extend});

  /// Moves the caret to the visual line start or end.
  void moveToLineStartOrEnd({required bool forward, required bool extend});

  /// Moves the caret one visual line up or down.
  void moveVertically({required bool forward, required bool extend});

  /// Moves the caret to the very start or end of the document.
  void moveToDocumentStartOrEnd({required bool forward, required bool extend});

  /// Moves the caret to the start or end of the current node.
  void moveToNodeStartOrEnd({required bool forward, required bool extend});

  /// Moves the caret one viewport height up or down.
  void moveByPage({required bool forward, required bool extend});

  /// Moves the caret to the start of the current node (Home key).
  void moveHome({required bool extend});

  /// Moves the caret to the end of the current node (End key).
  void moveEnd({required bool extend});

  /// Collapses the current selection to its extent.
  void collapseSelection();

  /// Deletes the character at the caret (forward delete).
  void deleteForward();

  /// Deletes the character before the caret (backspace).
  void deleteBackward();

  /// Handles the Tab key.
  void handleTab();

  /// Handles the Shift+Tab key combination.
  void handleShiftTab();

  /// Handles the Enter key.
  void handleEnter();

  /// Handles Shift+Enter.
  void handleShiftEnter();

  /// Copies the selected text to the clipboard.
  void copySelection();

  /// Cuts the selected text to the clipboard.
  void cutSelection();

  /// Pastes text from the clipboard.
  void pasteClipboard();

  /// Selects all content in the document.
  void selectAll();

  /// Toggles [attribution] on the current selection.
  void toggleAttribution(Attribution attribution);
}

// ---------------------------------------------------------------------------
// Flutter built-in intent actions
// ---------------------------------------------------------------------------

/// Action for [ExtendSelectionByCharacterIntent] — Left/Right arrow.
class _MoveByCharacterAction extends ContextAction<ExtendSelectionByCharacterIntent> {
  _MoveByCharacterAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(ExtendSelectionByCharacterIntent intent, [BuildContext? context]) {
    _getDelegate().moveByCharacter(
      forward: intent.forward,
      extend: !intent.collapseSelection,
    );
  }
}

/// Action for [ExtendSelectionToNextWordBoundaryIntent] — word-modifier +
/// Left/Right.
class _MoveByWordAction extends ContextAction<ExtendSelectionToNextWordBoundaryIntent> {
  _MoveByWordAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(ExtendSelectionToNextWordBoundaryIntent intent, [BuildContext? context]) {
    _getDelegate().moveByWord(
      forward: intent.forward,
      extend: !intent.collapseSelection,
    );
  }
}

/// Action for [ExtendSelectionToLineBreakIntent] — line-modifier + Left/Right.
class _MoveToLineStartOrEndAction extends ContextAction<ExtendSelectionToLineBreakIntent> {
  _MoveToLineStartOrEndAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(ExtendSelectionToLineBreakIntent intent, [BuildContext? context]) {
    _getDelegate().moveToLineStartOrEnd(
      forward: intent.forward,
      extend: !intent.collapseSelection,
    );
  }
}

/// Action for [ExtendSelectionVerticallyToAdjacentLineIntent] — Up/Down arrow.
class _MoveVerticallyAction extends ContextAction<ExtendSelectionVerticallyToAdjacentLineIntent> {
  _MoveVerticallyAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(
    ExtendSelectionVerticallyToAdjacentLineIntent intent, [
    BuildContext? context,
  ]) {
    _getDelegate().moveVertically(
      forward: intent.forward,
      extend: !intent.collapseSelection,
    );
  }
}

/// Action for [ExtendSelectionToDocumentBoundaryIntent] — line-modifier +
/// Up/Down.
class _MoveToDocumentStartOrEndAction
    extends ContextAction<ExtendSelectionToDocumentBoundaryIntent> {
  _MoveToDocumentStartOrEndAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(
    ExtendSelectionToDocumentBoundaryIntent intent, [
    BuildContext? context,
  ]) {
    _getDelegate().moveToDocumentStartOrEnd(
      forward: intent.forward,
      extend: !intent.collapseSelection,
    );
  }
}

/// Action for [ExtendSelectionToNextWordBoundaryOrCaretLocationIntent].
///
/// Used on some platforms for node-boundary jumps (word-modifier + Up/Down).
class _MoveToNodeBoundaryAction
    extends ContextAction<ExtendSelectionToNextWordBoundaryOrCaretLocationIntent> {
  _MoveToNodeBoundaryAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(
    ExtendSelectionToNextWordBoundaryOrCaretLocationIntent intent, [
    BuildContext? context,
  ]) {
    _getDelegate().moveToNodeStartOrEnd(
      forward: intent.forward,
      extend: !intent.collapseSelection,
    );
  }
}

/// Action for [DeleteCharacterIntent] — Delete (forward) and Backspace.
class _DeleteCharacterAction extends ContextAction<DeleteCharacterIntent> {
  _DeleteCharacterAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(DeleteCharacterIntent intent, [BuildContext? context]) {
    if (intent.forward) {
      _getDelegate().deleteForward();
    } else {
      _getDelegate().deleteBackward();
    }
  }
}

/// Action for [DeleteToNextWordBoundaryIntent] — word-modifier +
/// Delete/Backspace.
class _DeleteToWordBoundaryAction extends ContextAction<DeleteToNextWordBoundaryIntent> {
  _DeleteToWordBoundaryAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(DeleteToNextWordBoundaryIntent intent, [BuildContext? context]) {
    if (intent.forward) {
      _getDelegate().deleteForward();
    } else {
      _getDelegate().deleteBackward();
    }
  }
}

/// Action for [DeleteToLineBreakIntent] — line-modifier + Delete/Backspace.
class _DeleteToLineBreakAction extends ContextAction<DeleteToLineBreakIntent> {
  _DeleteToLineBreakAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(DeleteToLineBreakIntent intent, [BuildContext? context]) {
    if (intent.forward) {
      _getDelegate().deleteForward();
    } else {
      _getDelegate().deleteBackward();
    }
  }
}

/// Action for [ExtendSelectionVerticallyToAdjacentPageIntent] — Page Up/Down.
///
/// Flutter's [DefaultTextEditingShortcuts] maps Page Up/Down to
/// [ExtendSelectionVerticallyToAdjacentPageIntent]. When
/// [DirectionalCaretMovementIntent.collapseSelection] is `true` (the default
/// for non-shift Page Up/Down), the selection is moved without extending; when
/// `false` (Shift+Page Up/Down) the selection is extended.
class _MoveByPageAction extends ContextAction<ExtendSelectionVerticallyToAdjacentPageIntent> {
  _MoveByPageAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(
    ExtendSelectionVerticallyToAdjacentPageIntent intent, [
    BuildContext? context,
  ]) {
    _getDelegate().moveByPage(
      forward: intent.forward,
      extend: !intent.collapseSelection,
    );
  }
}

/// Action for [CopySelectionTextIntent] — Cmd/Ctrl+C and Cmd/Ctrl+X.
///
/// Flutter uses a single intent for both copy and cut: when
/// [CopySelectionTextIntent.collapseSelection] is `true` the intent represents
/// a cut; when `false` it is a plain copy.
class _CopyOrCutAction extends ContextAction<CopySelectionTextIntent> {
  _CopyOrCutAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(CopySelectionTextIntent intent, [BuildContext? context]) {
    if (intent.collapseSelection) {
      _getDelegate().cutSelection();
    } else {
      _getDelegate().copySelection();
    }
  }
}

/// Action for [PasteTextIntent] — Cmd/Ctrl+V.
class _PasteAction extends ContextAction<PasteTextIntent> {
  _PasteAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(PasteTextIntent intent, [BuildContext? context]) {
    _getDelegate().pasteClipboard();
  }
}

/// Action for [SelectAllTextIntent] — Cmd/Ctrl+A.
class _SelectAllAction extends ContextAction<SelectAllTextIntent> {
  _SelectAllAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(SelectAllTextIntent intent, [BuildContext? context]) {
    _getDelegate().selectAll();
  }
}

// ---------------------------------------------------------------------------
// Document-specific intent actions
// ---------------------------------------------------------------------------

/// Action for [CollapseSelectionIntent] — Escape.
class _CollapseSelectionAction extends ContextAction<CollapseSelectionIntent> {
  _CollapseSelectionAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(CollapseSelectionIntent intent, [BuildContext? context]) {
    _getDelegate().collapseSelection();
  }
}

/// Action for [ToggleAttributionIntent] — Cmd/Ctrl+B/I/U etc.
class _ToggleAttributionAction extends ContextAction<ToggleAttributionIntent> {
  _ToggleAttributionAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(ToggleAttributionIntent intent, [BuildContext? context]) {
    _getDelegate().toggleAttribution(intent.attribution);
  }
}

/// Action for [MoveToNodeBoundaryIntent] — word-modifier + Up/Down.
class _MoveToNodeBoundaryIntentAction extends ContextAction<MoveToNodeBoundaryIntent> {
  _MoveToNodeBoundaryIntentAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(MoveToNodeBoundaryIntent intent, [BuildContext? context]) {
    _getDelegate().moveToNodeStartOrEnd(
      forward: intent.forward,
      extend: intent.extend,
    );
  }
}

/// Action for [MoveToAdjacentTableCellIntent] — Tab / Shift+Tab in a table.
class _MoveToAdjacentTableCellAction extends ContextAction<MoveToAdjacentTableCellIntent> {
  _MoveToAdjacentTableCellAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(MoveToAdjacentTableCellIntent intent, [BuildContext? context]) {
    if (intent.forward) {
      _getDelegate().handleTab();
    } else {
      _getDelegate().handleShiftTab();
    }
  }
}

/// Action for [DocumentTabIntent] — Tab key.
class _DocumentTabAction extends ContextAction<DocumentTabIntent> {
  _DocumentTabAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(DocumentTabIntent intent, [BuildContext? context]) {
    _getDelegate().handleTab();
  }
}

/// Action for [DocumentShiftTabIntent] — Shift+Tab key.
class _DocumentShiftTabAction extends ContextAction<DocumentShiftTabIntent> {
  _DocumentShiftTabAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(DocumentShiftTabIntent intent, [BuildContext? context]) {
    _getDelegate().handleShiftTab();
  }
}

/// Action for [DocumentEnterIntent] — Enter key.
class _DocumentEnterAction extends ContextAction<DocumentEnterIntent> {
  _DocumentEnterAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(DocumentEnterIntent intent, [BuildContext? context]) {
    _getDelegate().handleEnter();
  }
}

/// Action for [DocumentShiftEnterIntent] — Shift+Enter key.
class _DocumentShiftEnterAction extends ContextAction<DocumentShiftEnterIntent> {
  _DocumentShiftEnterAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(DocumentShiftEnterIntent intent, [BuildContext? context]) {
    _getDelegate().handleShiftEnter();
  }
}

/// Action for [IndentListItemIntent] — Tab in a list item (via toolbar).
class _IndentListItemAction extends ContextAction<IndentListItemIntent> {
  _IndentListItemAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(IndentListItemIntent intent, [BuildContext? context]) {
    _getDelegate().handleTab();
  }
}

/// Action for [UnindentListItemIntent] — Shift+Tab in a list item (via
/// toolbar).
class _UnindentListItemAction extends ContextAction<UnindentListItemIntent> {
  _UnindentListItemAction(this._getDelegate);

  final DocumentEditingDelegate Function() _getDelegate;

  @override
  void invoke(UnindentListItemIntent intent, [BuildContext? context]) {
    _getDelegate().handleShiftTab();
  }
}

// ---------------------------------------------------------------------------
// Public factory
// ---------------------------------------------------------------------------

/// Creates the default document editing actions map.
///
/// [getDelegate] is a closure that returns the live [DocumentEditingDelegate]
/// (typically [EditableDocumentState]) so that the actions remain
/// const-constructible while still accessing up-to-date state.
///
/// The returned map is passed to an [Actions] widget that wraps the [Focus]
/// widget inside [EditableDocument].
Map<Type, Action<Intent>> createDocumentEditingActions(
  DocumentEditingDelegate Function() getDelegate,
) {
  return <Type, Action<Intent>>{
    // Flutter built-in intents (from DefaultTextEditingShortcuts).
    ExtendSelectionByCharacterIntent: _MoveByCharacterAction(getDelegate),
    ExtendSelectionToNextWordBoundaryIntent: _MoveByWordAction(getDelegate),
    ExtendSelectionToLineBreakIntent: _MoveToLineStartOrEndAction(getDelegate),
    ExtendSelectionVerticallyToAdjacentLineIntent: _MoveVerticallyAction(getDelegate),
    ExtendSelectionToDocumentBoundaryIntent: _MoveToDocumentStartOrEndAction(getDelegate),
    ExtendSelectionToNextWordBoundaryOrCaretLocationIntent: _MoveToNodeBoundaryAction(getDelegate),
    DeleteCharacterIntent: _DeleteCharacterAction(getDelegate),
    DeleteToNextWordBoundaryIntent: _DeleteToWordBoundaryAction(getDelegate),
    DeleteToLineBreakIntent: _DeleteToLineBreakAction(getDelegate),
    ExtendSelectionVerticallyToAdjacentPageIntent: _MoveByPageAction(getDelegate),
    CopySelectionTextIntent: _CopyOrCutAction(getDelegate),
    PasteTextIntent: _PasteAction(getDelegate),
    SelectAllTextIntent: _SelectAllAction(getDelegate),

    // Document-specific intents.
    CollapseSelectionIntent: _CollapseSelectionAction(getDelegate),
    ToggleAttributionIntent: _ToggleAttributionAction(getDelegate),
    MoveToNodeBoundaryIntent: _MoveToNodeBoundaryIntentAction(getDelegate),
    MoveToAdjacentTableCellIntent: _MoveToAdjacentTableCellAction(getDelegate),
    DocumentTabIntent: _DocumentTabAction(getDelegate),
    DocumentShiftTabIntent: _DocumentShiftTabAction(getDelegate),
    DocumentEnterIntent: _DocumentEnterAction(getDelegate),
    DocumentShiftEnterIntent: _DocumentShiftEnterAction(getDelegate),
    IndentListItemIntent: _IndentListItemAction(getDelegate),
    UnindentListItemIntent: _UnindentListItemAction(getDelegate),
  };
}

// ---------------------------------------------------------------------------
// Helper: isSelectionFullyAttributed
// ---------------------------------------------------------------------------

/// Returns `true` when every character in [selection] within [document]
/// carries [attribution].
///
/// Used by [DocumentEditingDelegate.toggleAttribution] to decide whether to
/// apply or remove. A collapsed selection always returns `false` (toggle
/// operates on [ComposerPreferences] instead).
///
/// Only single-node text selections are checked; multi-node selections always
/// return `false` (treated as partially attributed).
bool isSelectionFullyAttributed(
  DocumentSelection selection,
  Attribution attribution,
  Document document,
) {
  if (selection.isCollapsed) return false;

  final base = selection.base;
  final extent = selection.extent;

  // Multi-node selections treated as partially attributed.
  if (base.nodeId != extent.nodeId) return false;

  final node = document.nodeById(base.nodeId);

  if (node is TableNode) {
    final basePos = base.nodePosition;
    final extentPos = extent.nodePosition;
    if (basePos is! TableCellPosition || extentPos is! TableCellPosition) return false;
    if (basePos.row != extentPos.row || basePos.col != extentPos.col) return false;
    final cellText = node.cellAt(basePos.row, basePos.col);
    final start = basePos.offset < extentPos.offset ? basePos.offset : extentPos.offset;
    final end = basePos.offset < extentPos.offset ? extentPos.offset : basePos.offset;
    for (var i = start; i < end; i++) {
      if (!cellText.hasAttributionAt(i, attribution)) return false;
    }
    return true;
  }

  if (node is! TextNode) return false;

  final baseOffset = (base.nodePosition as TextNodePosition).offset;
  final extentOffset = (extent.nodePosition as TextNodePosition).offset;
  final start = baseOffset < extentOffset ? baseOffset : extentOffset;
  final end = baseOffset < extentOffset ? extentOffset : baseOffset;

  for (var i = start; i < end; i++) {
    if (!node.text.hasAttributionAt(i, attribution)) return false;
  }
  return true;
}
