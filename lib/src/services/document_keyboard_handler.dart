/// Keyboard handler for the editable_document services layer.
///
/// Maps raw [KeyEvent]s to [EditRequest]s for document navigation and editing
/// operations that are not covered by the IME delta model (e.g., arrow
/// navigation, Home/End, Delete-forward, Escape, Tab indent/unindent).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../model/document.dart';
import '../model/document_editing_controller.dart';
import '../model/document_node.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';
import '../model/edit_request.dart';
import '../model/list_item_node.dart';
import '../model/node_position.dart';
import '../model/text_node.dart';

// ---------------------------------------------------------------------------
// DocumentKeyboardHandler
// ---------------------------------------------------------------------------

/// Maps raw [KeyEvent]s to [EditRequest]s for the document editor.
///
/// Handles keys NOT covered by the IME delta model — primarily desktop
/// navigation and structural editing:
///
/// * **Arrow navigation** — move caret by character (Left/Right) or block
///   (Up/Down jumps to the previous/next node).
/// * **Shift + Arrow** — extend the current selection.
/// * **Ctrl/Cmd + Left/Right** — word-level navigation (moves to the
///   start/end of the current word or adjacent word boundary).
/// * **Ctrl/Cmd + Up/Down** — paragraph navigation (jumps to the first
///   position of the previous/next block).
/// * **Home / End** — move to the start/end of the current text node.
/// * **Ctrl/Cmd + Home / End** — move to the very start/end of the document.
/// * **Delete** — forward-delete one character (or delete current selection).
/// * **Backspace** (fallback) — backward-delete one character.
/// * **Tab** — [IndentListItemRequest] when cursor is in a [ListItemNode];
///   otherwise ignored (returns `false`).
/// * **Shift + Tab** — [UnindentListItemRequest] when in a [ListItemNode].
/// * **Escape** — collapse an expanded selection to its extent.
/// * **Unknown keys** — returns `false`.
///
/// Platform-specific primary modifier:
/// * macOS — `LogicalKeyboardKey.meta` (Cmd).
/// * Windows / Linux / other — `LogicalKeyboardKey.control` (Ctrl).
///
/// The modifier is detected via [defaultTargetPlatform] at runtime so tests
/// can override the platform using [debugDefaultTargetPlatformOverride].
///
/// Example:
/// ```dart
/// final handler = DocumentKeyboardHandler(
///   document: controller.document,
///   controller: controller,
///   requestHandler: editor.submit,
/// );
/// // Attach via a Focus widget:
/// Focus(
///   onKeyEvent: (node, event) =>
///       handler.onKeyEvent(event)
///           ? KeyEventResult.handled
///           : KeyEventResult.ignored,
///   child: myDocumentWidget,
/// );
/// ```
class DocumentKeyboardHandler {
  /// Creates a [DocumentKeyboardHandler].
  ///
  /// * [document] — read-only document view used for position look-ups.
  /// * [controller] — provides and mutates the current [DocumentSelection].
  /// * [requestHandler] — called with each [EditRequest] produced by a key
  ///   event (typically `editor.submit`).
  DocumentKeyboardHandler({
    required Document document,
    required DocumentEditingController controller,
    required void Function(EditRequest request) requestHandler,
  })  : _document = document,
        _controller = controller,
        _requestHandler = requestHandler;

  final Document _document;
  final DocumentEditingController _controller;
  final void Function(EditRequest) _requestHandler;

  // -------------------------------------------------------------------------
  // Public entry point
  // -------------------------------------------------------------------------

  /// Handles a raw [KeyEvent] from the Flutter focus system.
  ///
  /// Returns `true` when the event is consumed (handled), or `false` when it
  /// should continue to other handlers (ignored).
  ///
  /// The widget layer wraps this in a `Focus.onKeyEvent` callback:
  ///
  /// ```dart
  /// Focus(
  ///   onKeyEvent: (node, event) =>
  ///       handler.onKeyEvent(event)
  ///           ? KeyEventResult.handled
  ///           : KeyEventResult.ignored,
  ///   child: ...,
  /// );
  /// ```
  ///
  /// Only [KeyDownEvent] and [KeyRepeatEvent] are acted upon;
  /// [KeyUpEvent]s are always ignored.
  bool onKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) return false;

    final logicalKey = event.logicalKey;
    final bool primaryModifier = _isPrimaryModifierPressed();
    final bool shiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (logicalKey == LogicalKeyboardKey.escape) {
      return _handleEscape();
    }
    if (logicalKey == LogicalKeyboardKey.arrowLeft) {
      return _handleArrowLeft(primaryModifier: primaryModifier, shift: shiftPressed);
    }
    if (logicalKey == LogicalKeyboardKey.arrowRight) {
      return _handleArrowRight(primaryModifier: primaryModifier, shift: shiftPressed);
    }
    if (logicalKey == LogicalKeyboardKey.arrowUp) {
      return _handleArrowUp(shift: shiftPressed);
    }
    if (logicalKey == LogicalKeyboardKey.arrowDown) {
      return _handleArrowDown(shift: shiftPressed);
    }
    if (logicalKey == LogicalKeyboardKey.home) {
      return _handleHome(primaryModifier: primaryModifier, shift: shiftPressed);
    }
    if (logicalKey == LogicalKeyboardKey.end) {
      return _handleEnd(primaryModifier: primaryModifier, shift: shiftPressed);
    }
    if (logicalKey == LogicalKeyboardKey.delete) {
      return _handleDeleteForward();
    }
    if (logicalKey == LogicalKeyboardKey.backspace) {
      return _handleBackspace();
    }
    if (logicalKey == LogicalKeyboardKey.tab) {
      return shiftPressed ? _handleShiftTab() : _handleTab();
    }

    return false;
  }

  // -------------------------------------------------------------------------
  // Escape
  // -------------------------------------------------------------------------

  bool _handleEscape() {
    final selection = _controller.selection;
    if (selection == null) return false;
    if (selection.isCollapsed) return false;
    _controller.setSelection(
      DocumentSelection.collapsed(position: selection.extent),
    );
    return true;
  }

  // -------------------------------------------------------------------------
  // Arrow Left
  // -------------------------------------------------------------------------

  bool _handleArrowLeft({required bool primaryModifier, required bool shift}) {
    final selection = _controller.selection;
    if (selection == null) return false;

    if (!shift && selection.isExpanded) {
      final normalised = selection.normalize(_document);
      _controller.setSelection(DocumentSelection.collapsed(position: normalised.base));
      return true;
    }

    final extentPos = selection.extent;
    final node = _document.nodeById(extentPos.nodeId);
    if (node == null) return false;

    final newExtent =
        primaryModifier ? _moveToWordStart(extentPos, node) : _moveCharacterLeft(extentPos, node);

    _updateSelection(newExtent, extend: shift);
    return true;
  }

  // -------------------------------------------------------------------------
  // Arrow Right
  // -------------------------------------------------------------------------

  bool _handleArrowRight({required bool primaryModifier, required bool shift}) {
    final selection = _controller.selection;
    if (selection == null) return false;

    if (!shift && selection.isExpanded) {
      final normalised = selection.normalize(_document);
      _controller.setSelection(DocumentSelection.collapsed(position: normalised.extent));
      return true;
    }

    final extentPos = selection.extent;
    final node = _document.nodeById(extentPos.nodeId);
    if (node == null) return false;

    final newExtent =
        primaryModifier ? _moveToWordEnd(extentPos, node) : _moveCharacterRight(extentPos, node);

    _updateSelection(newExtent, extend: shift);
    return true;
  }

  // -------------------------------------------------------------------------
  // Arrow Up
  // -------------------------------------------------------------------------

  bool _handleArrowUp({required bool shift}) {
    final selection = _controller.selection;
    if (selection == null) return false;

    final extentPos = selection.extent;
    final node = _document.nodeById(extentPos.nodeId);
    if (node == null) return false;

    // Both plain Up and Ctrl/Cmd+Up move to the start of the previous block.
    // (Line-within-block navigation requires a render layer; that is out of
    // scope for the services layer.)
    final prevNode = _document.nodeBefore(extentPos.nodeId);
    final newExtent = prevNode == null ? _startOfNode(node) : _startOfNode(prevNode);

    _updateSelection(newExtent, extend: shift);
    return true;
  }

  // -------------------------------------------------------------------------
  // Arrow Down
  // -------------------------------------------------------------------------

  bool _handleArrowDown({required bool shift}) {
    final selection = _controller.selection;
    if (selection == null) return false;

    final extentPos = selection.extent;
    final node = _document.nodeById(extentPos.nodeId);
    if (node == null) return false;

    // Both plain Down and Ctrl/Cmd+Down move to the start of the next block.
    final nextNode = _document.nodeAfter(extentPos.nodeId);
    final newExtent = nextNode == null ? _endOfNode(node) : _startOfNode(nextNode);

    _updateSelection(newExtent, extend: shift);
    return true;
  }

  // -------------------------------------------------------------------------
  // Home
  // -------------------------------------------------------------------------

  bool _handleHome({required bool primaryModifier, required bool shift}) {
    final selection = _controller.selection;
    if (selection == null) return false;

    final extentPos = selection.extent;

    DocumentPosition newExtent;
    if (primaryModifier) {
      if (_document.nodes.isEmpty) return false;
      newExtent = _startOfNode(_document.nodes.first);
    } else {
      final node = _document.nodeById(extentPos.nodeId);
      if (node == null) return false;
      newExtent = _startOfNode(node);
    }

    _updateSelection(newExtent, extend: shift);
    return true;
  }

  // -------------------------------------------------------------------------
  // End
  // -------------------------------------------------------------------------

  bool _handleEnd({required bool primaryModifier, required bool shift}) {
    final selection = _controller.selection;
    if (selection == null) return false;

    final extentPos = selection.extent;

    DocumentPosition newExtent;
    if (primaryModifier) {
      if (_document.nodes.isEmpty) return false;
      newExtent = _endOfNode(_document.nodes.last);
    } else {
      final node = _document.nodeById(extentPos.nodeId);
      if (node == null) return false;
      newExtent = _endOfNode(node);
    }

    _updateSelection(newExtent, extend: shift);
    return true;
  }

  // -------------------------------------------------------------------------
  // Delete (forward)
  // -------------------------------------------------------------------------

  bool _handleDeleteForward() {
    final selection = _controller.selection;
    if (selection == null) return false;

    if (selection.isExpanded) {
      _requestHandler(DeleteContentRequest(selection: selection));
      return true;
    }

    final extentPos = selection.extent;
    final node = _document.nodeById(extentPos.nodeId);
    if (node == null) return false;

    if (node is TextNode) {
      final offset = (extentPos.nodePosition as TextNodePosition).offset;
      if (offset >= node.text.text.length) {
        final nextNode = _document.nodeAfter(extentPos.nodeId);
        if (nextNode == null) return false;
        _requestHandler(
          MergeNodeRequest(firstNodeId: node.id, secondNodeId: nextNode.id),
        );
      } else {
        _requestHandler(
          DeleteContentRequest(
            selection: DocumentSelection(
              base: extentPos,
              extent: DocumentPosition(
                nodeId: extentPos.nodeId,
                nodePosition: TextNodePosition(offset: offset + 1),
              ),
            ),
          ),
        );
      }
    } else {
      _requestHandler(
        DeleteContentRequest(
          selection: DocumentSelection(
            base: DocumentPosition(
              nodeId: extentPos.nodeId,
              nodePosition: const BinaryNodePosition.upstream(),
            ),
            extent: DocumentPosition(
              nodeId: extentPos.nodeId,
              nodePosition: const BinaryNodePosition.downstream(),
            ),
          ),
        ),
      );
    }

    return true;
  }

  // -------------------------------------------------------------------------
  // Backspace (fallback)
  // -------------------------------------------------------------------------

  bool _handleBackspace() {
    final selection = _controller.selection;
    if (selection == null) return false;

    if (selection.isExpanded) {
      _requestHandler(DeleteContentRequest(selection: selection));
      return true;
    }

    final extentPos = selection.extent;
    final node = _document.nodeById(extentPos.nodeId);
    if (node == null) return false;

    if (node is TextNode) {
      final offset = (extentPos.nodePosition as TextNodePosition).offset;
      if (offset == 0) {
        final prevNode = _document.nodeBefore(extentPos.nodeId);
        if (prevNode == null) return false;
        _requestHandler(
          MergeNodeRequest(firstNodeId: prevNode.id, secondNodeId: node.id),
        );
      } else {
        _requestHandler(
          DeleteContentRequest(
            selection: DocumentSelection(
              base: DocumentPosition(
                nodeId: extentPos.nodeId,
                nodePosition: TextNodePosition(offset: offset - 1),
              ),
              extent: extentPos,
            ),
          ),
        );
      }
    } else {
      _requestHandler(
        DeleteContentRequest(
          selection: DocumentSelection(
            base: DocumentPosition(
              nodeId: extentPos.nodeId,
              nodePosition: const BinaryNodePosition.upstream(),
            ),
            extent: DocumentPosition(
              nodeId: extentPos.nodeId,
              nodePosition: const BinaryNodePosition.downstream(),
            ),
          ),
        ),
      );
    }

    return true;
  }

  // -------------------------------------------------------------------------
  // Tab
  // -------------------------------------------------------------------------

  bool _handleTab() {
    final selection = _controller.selection;
    if (selection == null) return false;
    final node = _document.nodeById(selection.extent.nodeId);
    if (node is ListItemNode) {
      _requestHandler(IndentListItemRequest(nodeId: node.id));
      return true;
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // Shift+Tab
  // -------------------------------------------------------------------------

  bool _handleShiftTab() {
    final selection = _controller.selection;
    if (selection == null) return false;
    final node = _document.nodeById(selection.extent.nodeId);
    if (node is ListItemNode) {
      _requestHandler(UnindentListItemRequest(nodeId: node.id));
      return true;
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // Private helpers — position movement
  // -------------------------------------------------------------------------

  /// Returns the position at the start of [node].
  DocumentPosition _startOfNode(DocumentNode node) {
    if (node is TextNode) {
      return DocumentPosition(
        nodeId: node.id,
        nodePosition: const TextNodePosition(offset: 0),
      );
    }
    return DocumentPosition(
      nodeId: node.id,
      nodePosition: const BinaryNodePosition.upstream(),
    );
  }

  /// Returns the position at the end of [node].
  DocumentPosition _endOfNode(DocumentNode node) {
    if (node is TextNode) {
      return DocumentPosition(
        nodeId: node.id,
        nodePosition: TextNodePosition(offset: node.text.text.length),
      );
    }
    return DocumentPosition(
      nodeId: node.id,
      nodePosition: const BinaryNodePosition.downstream(),
    );
  }

  /// Moves one character to the left within [node], or wraps to the end of the
  /// previous node.
  DocumentPosition _moveCharacterLeft(DocumentPosition pos, DocumentNode node) {
    if (node is TextNode) {
      final offset = (pos.nodePosition as TextNodePosition).offset;
      if (offset > 0) {
        return DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: offset - 1),
        );
      }
      final prev = _document.nodeBefore(node.id);
      if (prev != null) return _endOfNode(prev);
    }
    return pos;
  }

  /// Moves one character to the right within [node], or wraps to the start of
  /// the next node.
  DocumentPosition _moveCharacterRight(DocumentPosition pos, DocumentNode node) {
    if (node is TextNode) {
      final offset = (pos.nodePosition as TextNodePosition).offset;
      if (offset < node.text.text.length) {
        return DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: offset + 1),
        );
      }
      final next = _document.nodeAfter(node.id);
      if (next != null) return _startOfNode(next);
    }
    return pos;
  }

  /// Moves to the start of the current word (or node start for non-text nodes).
  DocumentPosition _moveToWordStart(DocumentPosition pos, DocumentNode node) {
    if (node is! TextNode) return _startOfNode(node);
    final text = node.text.text;
    var offset = (pos.nodePosition as TextNodePosition).offset;
    while (offset > 0 && text[offset - 1] == ' ') {
      offset--;
    }
    while (offset > 0 && text[offset - 1] != ' ') {
      offset--;
    }
    return DocumentPosition(
      nodeId: node.id,
      nodePosition: TextNodePosition(offset: offset),
    );
  }

  /// Moves to the end of the current word (or node end for non-text nodes).
  DocumentPosition _moveToWordEnd(DocumentPosition pos, DocumentNode node) {
    if (node is! TextNode) return _endOfNode(node);
    final text = node.text.text;
    var offset = (pos.nodePosition as TextNodePosition).offset;
    while (offset < text.length && text[offset] == ' ') {
      offset++;
    }
    while (offset < text.length && text[offset] != ' ') {
      offset++;
    }
    return DocumentPosition(
      nodeId: node.id,
      nodePosition: TextNodePosition(offset: offset),
    );
  }

  // -------------------------------------------------------------------------
  // Private helpers — selection update
  // -------------------------------------------------------------------------

  /// Updates the controller's selection, either moving the caret to [newExtent]
  /// or extending the existing selection base to [newExtent] when [extend] is
  /// `true`.
  void _updateSelection(DocumentPosition newExtent, {required bool extend}) {
    final current = _controller.selection;
    if (extend && current != null) {
      _controller.setSelection(
        DocumentSelection(base: current.base, extent: newExtent),
      );
    } else {
      _controller.setSelection(DocumentSelection.collapsed(position: newExtent));
    }
  }

  // -------------------------------------------------------------------------
  // Private helpers — platform modifier
  // -------------------------------------------------------------------------

  /// Returns `true` when the platform's primary modifier key is currently held.
  ///
  /// macOS uses Cmd ([LogicalKeyboardKey.meta]); all other platforms use Ctrl
  /// ([LogicalKeyboardKey.control]).
  bool _isPrimaryModifierPressed() {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return HardwareKeyboard.instance.isMetaPressed;
    }
    return HardwareKeyboard.instance.isControlPressed;
  }
}
