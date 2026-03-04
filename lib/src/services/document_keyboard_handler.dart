/// Keyboard handler for the editable_document services layer.
///
/// Maps raw [KeyEvent]s to [EditRequest]s for document navigation and editing
/// operations that are not covered by the IME delta model (e.g., arrow
/// navigation, Home/End, Delete-forward, Escape, Tab indent/unindent).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../model/attributed_text.dart';
import '../model/code_block_node.dart';
import '../model/document.dart';
import '../model/document_editing_controller.dart';
import '../model/document_node.dart';
import '../model/document_position.dart';
import '../model/document_selection.dart';
import '../model/edit_request.dart';
import '../model/list_item_node.dart';
import '../model/node_position.dart';
import '../model/paragraph_node.dart';
import '../model/text_node.dart';

// ---------------------------------------------------------------------------
// PageMoveResolver
// ---------------------------------------------------------------------------

/// Resolves a Page Up/Down movement. Returns the target [DocumentPosition],
/// or `null` if the move cannot be resolved.
typedef PageMoveResolver = DocumentPosition? Function({
  required DocumentPosition from,
  required bool forward,
});

// ---------------------------------------------------------------------------
// VerticalMoveResolver
// ---------------------------------------------------------------------------

/// Resolves a single-line vertical caret movement (Up/Down arrow).
/// Returns the target [DocumentPosition] one visual line above or below
/// [from], or `null` if the move cannot be resolved.
typedef VerticalMoveResolver = DocumentPosition? Function({
  required DocumentPosition from,
  required bool forward,
});

// ---------------------------------------------------------------------------
// LineMoveResolver
// ---------------------------------------------------------------------------

/// Resolves a line-boundary movement (Cmd+Left/Right on macOS, Alt+Left/Right
/// on other platforms). Returns the target [DocumentPosition] at the start or
/// end of the current visual line, or `null` when the resolver cannot
/// determine a visual-line boundary (e.g. for binary nodes).
typedef LineMoveResolver = DocumentPosition? Function({
  required DocumentPosition from,
  required bool forward,
});

/// Maps raw [KeyEvent]s to [EditRequest]s for the document editor.
///
/// Handles keys NOT covered by the IME delta model — primarily desktop
/// navigation and structural editing:
///
/// * **Arrow navigation** — move caret by character (Left/Right) or by visual
///   line (Up/Down when a [verticalMoveResolver] is provided, otherwise
///   falls back to jumping to the previous/next block).
/// * **Shift + Arrow** — extend the current selection.
/// * **Word modifier + Left/Right** — word-level navigation (moves to the
///   start/end of the current word or adjacent word boundary).
/// * **Word modifier + Up/Down** — node start/end navigation (jumps to the
///   first/last position of the current block).
/// * **Line modifier + Left/Right** — visual line start/end navigation (when
///   a [lineMoveResolver] is provided, moves to the start/end of the current
///   visual line; otherwise falls back to node start/end).
/// * **Line modifier + Up/Down** — document start/end navigation (jumps to
///   the very first/last position in the document).
/// * **Home / End** — move to the start/end of the current text node.
/// * **Primary modifier + Home / End** — move to the very start/end of the
///   document.
/// * **Page Up** — move the caret up by one viewport height (requires
///   [pageMoveResolver]).
/// * **Page Down** — move the caret down by one viewport height (requires
///   [pageMoveResolver]).
/// * **Shift + Page Up/Down** — extend the selection by one viewport height.
/// * **Delete** — forward-delete one character (or delete current selection).
/// * **Backspace** (fallback) — backward-delete one character.
/// * **Tab** — [IndentListItemRequest] when cursor is in a [ListItemNode];
///   otherwise ignored (returns `false`).
/// * **Shift + Tab** — [UnindentListItemRequest] when in a [ListItemNode].
/// * **Escape** — collapse an expanded selection to its extent.
/// * **Unknown keys** — returns `false`.
///
/// ### Platform modifier mapping
///
/// | Action | macOS / iOS | Windows / Linux / Android |
/// |--------|-------------|--------------------------|
/// | Word boundary (Left/Right) | **Option** (Alt) | **Ctrl** |
/// | Line start/end (Left/Right) | **Cmd** (Meta) | **Alt** |
/// | Document start/end (Up/Down) | **Cmd** (Meta) | **Alt** |
/// | Node start/end (Up/Down) | **Option** (Alt) | **Ctrl** |
/// | Document start/end (Home/End) | **Cmd** (Meta) | **Ctrl** |
///
/// ### macOS Emacs bindings (when Ctrl is pressed but NOT Cmd or Alt)
///
/// | Key | Action |
/// |-----|--------|
/// | Ctrl+A | Node start |
/// | Ctrl+E | Node end |
/// | Ctrl+F | Character forward (right) |
/// | Ctrl+B | Character backward (left) |
/// | Ctrl+N | Next block (down) |
/// | Ctrl+P | Previous block (up) |
///
/// All Emacs bindings support Shift for selection extension.
///
/// The modifiers are detected via [defaultTargetPlatform] at runtime so tests
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
  /// * [pageMoveResolver] — optional callback that resolves Page Up/Down
  ///   movement to a target [DocumentPosition]. When `null`, Page Up/Down
  ///   key events return `false` (unhandled).
  /// * [verticalMoveResolver] — optional callback that resolves single-line
  ///   Up/Down arrow movement to a target [DocumentPosition]. When `null`,
  ///   plain Up/Down falls back to block-level movement (previous/next node
  ///   start).
  /// * [lineMoveResolver] — optional callback that resolves line-boundary
  ///   Left/Right movement to a target [DocumentPosition]. When `null`,
  ///   line-modifier + Left/Right falls back to node start/end.
  DocumentKeyboardHandler({
    required Document document,
    required DocumentEditingController controller,
    required void Function(EditRequest request) requestHandler,
    this.pageMoveResolver,
    this.verticalMoveResolver,
    this.lineMoveResolver,
  })  : _document = document,
        _controller = controller,
        _requestHandler = requestHandler;

  final Document _document;
  final DocumentEditingController _controller;
  final void Function(EditRequest) _requestHandler;

  /// Optional callback that resolves page-level vertical caret movement.
  ///
  /// When non-null, Page Up/Down keys invoke this resolver to determine the
  /// target [DocumentPosition] one viewport height above or below the current
  /// extent. The widgets layer typically provides the implementation since it
  /// has access to layout geometry and viewport dimensions.
  ///
  /// When `null`, Page Up/Down key events return `false` (unhandled).
  final PageMoveResolver? pageMoveResolver;

  /// Optional callback that resolves single-line vertical caret movement.
  ///
  /// When non-null, plain Up/Down arrow keys invoke this resolver to determine
  /// the target [DocumentPosition] one visual line above or below the current
  /// extent. The widgets layer typically provides the implementation since it
  /// has access to layout geometry.
  ///
  /// When `null`, Up/Down falls back to block-level movement (previous/next
  /// node start).
  final VerticalMoveResolver? verticalMoveResolver;

  /// Optional callback that resolves line-boundary caret movement.
  ///
  /// When non-null, line-modifier + Left/Right keys (Cmd+Left/Right on macOS,
  /// Alt+Left/Right on other platforms) invoke this resolver to determine the
  /// target [DocumentPosition] at the visual line start or end. When the
  /// resolver returns `null` (e.g. for binary nodes without visual lines),
  /// the handler falls back to node start/end.
  ///
  /// When this field is `null`, line-modifier + Left/Right always moves to
  /// node start/end (the pre-existing behavior).
  final LineMoveResolver? lineMoveResolver;

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
    final bool wordModifier = _isWordModifierPressed();
    final bool lineModifier = _isLineModifierPressed();
    final bool shiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (logicalKey == LogicalKeyboardKey.escape) {
      return _handleEscape();
    }
    if (logicalKey == LogicalKeyboardKey.arrowLeft) {
      return _handleArrowLeft(
        wordModifier: wordModifier,
        lineModifier: lineModifier,
        shift: shiftPressed,
      );
    }
    if (logicalKey == LogicalKeyboardKey.arrowRight) {
      return _handleArrowRight(
        wordModifier: wordModifier,
        lineModifier: lineModifier,
        shift: shiftPressed,
      );
    }
    if (logicalKey == LogicalKeyboardKey.arrowUp) {
      return _handleArrowUp(
        wordModifier: wordModifier,
        lineModifier: lineModifier,
        shift: shiftPressed,
      );
    }
    if (logicalKey == LogicalKeyboardKey.arrowDown) {
      return _handleArrowDown(
        wordModifier: wordModifier,
        lineModifier: lineModifier,
        shift: shiftPressed,
      );
    }
    if (logicalKey == LogicalKeyboardKey.home) {
      return _handleHome(primaryModifier: primaryModifier, shift: shiftPressed);
    }
    if (logicalKey == LogicalKeyboardKey.end) {
      return _handleEnd(primaryModifier: primaryModifier, shift: shiftPressed);
    }
    if (logicalKey == LogicalKeyboardKey.pageUp) {
      return _handlePageMove(forward: false, shift: shiftPressed);
    }
    if (logicalKey == LogicalKeyboardKey.pageDown) {
      return _handlePageMove(forward: true, shift: shiftPressed);
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
    if (logicalKey == LogicalKeyboardKey.enter) {
      if (shiftPressed) {
        if (_handleShiftEnter()) return true;
      } else {
        if (_handleEnter()) return true;
      }
    }

    // macOS/iOS Emacs bindings: only when Ctrl is held but NOT Cmd (Meta) or
    // Alt (Option), to avoid conflicting with line/word modifier combos.
    if (_isMacOrIos() &&
        HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isAltPressed) {
      return _handleMacEmacsBinding(logicalKey, shift: shiftPressed);
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

  bool _handleArrowLeft({
    required bool wordModifier,
    required bool lineModifier,
    required bool shift,
  }) {
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

    final DocumentPosition newExtent;
    if (lineModifier) {
      newExtent = lineMoveResolver?.call(from: extentPos, forward: false) ?? _startOfNode(node);
    } else if (wordModifier) {
      newExtent = _moveToWordStart(extentPos, node);
    } else {
      newExtent = _moveCharacterLeft(extentPos, node);
    }

    _updateSelection(newExtent, extend: shift);
    return true;
  }

  // -------------------------------------------------------------------------
  // Arrow Right
  // -------------------------------------------------------------------------

  bool _handleArrowRight({
    required bool wordModifier,
    required bool lineModifier,
    required bool shift,
  }) {
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

    final DocumentPosition newExtent;
    if (lineModifier) {
      newExtent = lineMoveResolver?.call(from: extentPos, forward: true) ?? _endOfNode(node);
    } else if (wordModifier) {
      newExtent = _moveToWordEnd(extentPos, node);
    } else {
      newExtent = _moveCharacterRight(extentPos, node);
    }

    _updateSelection(newExtent, extend: shift);
    return true;
  }

  // -------------------------------------------------------------------------
  // Arrow Up
  // -------------------------------------------------------------------------

  bool _handleArrowUp({
    required bool wordModifier,
    required bool lineModifier,
    required bool shift,
  }) {
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

    final DocumentPosition newExtent;
    if (lineModifier) {
      // Line modifier + Up → document start (first node, first position).
      if (_document.nodes.isEmpty) return false;
      newExtent = _startOfNode(_document.nodes.first);
    } else if (wordModifier) {
      // Word modifier + Up → start of current node (line break equivalent).
      newExtent = _startOfNode(node);
    } else {
      // Plain Up → use visual-line resolver if available, else block-jump.
      final resolver = verticalMoveResolver;
      if (resolver != null) {
        final resolved = resolver(from: extentPos, forward: false);
        newExtent = resolved ?? extentPos;
      } else {
        final prevNode = _document.nodeBefore(extentPos.nodeId);
        newExtent = prevNode == null ? _startOfNode(node) : _startOfNode(prevNode);
      }
    }

    _updateSelection(newExtent, extend: shift);
    return true;
  }

  // -------------------------------------------------------------------------
  // Arrow Down
  // -------------------------------------------------------------------------

  bool _handleArrowDown({
    required bool wordModifier,
    required bool lineModifier,
    required bool shift,
  }) {
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

    final DocumentPosition newExtent;
    if (lineModifier) {
      // Line modifier + Down → document end (last node, last position).
      if (_document.nodes.isEmpty) return false;
      newExtent = _endOfNode(_document.nodes.last);
    } else if (wordModifier) {
      // Word modifier + Down → end of current node (line break equivalent).
      newExtent = _endOfNode(node);
    } else {
      // Plain Down → use visual-line resolver if available, else block-jump.
      final resolver = verticalMoveResolver;
      if (resolver != null) {
        final resolved = resolver(from: extentPos, forward: true);
        newExtent = resolved ?? extentPos;
      } else {
        final nextNode = _document.nodeAfter(extentPos.nodeId);
        newExtent = nextNode == null ? _endOfNode(node) : _startOfNode(nextNode);
      }
    }

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
  // Page Up / Page Down
  // -------------------------------------------------------------------------

  bool _handlePageMove({required bool forward, required bool shift}) {
    if (pageMoveResolver == null) return false;
    final selection = _controller.selection;
    if (selection == null) return false;
    final resolved = pageMoveResolver!(from: selection.extent, forward: forward);
    if (resolved == null) return false;
    _updateSelection(resolved, extend: shift);
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
        // Empty list item → convert to paragraph instead of merging.
        if (node is ListItemNode && node.text.text.isEmpty) {
          _requestHandler(ConvertListItemToParagraphRequest(nodeId: node.id));
        } else if (node is ParagraphNode &&
            node.blockType == ParagraphBlockType.blockquote &&
            node.text.text.isEmpty) {
          _requestHandler(
            ChangeBlockTypeRequest(
              nodeId: node.id,
              newBlockType: ParagraphBlockType.paragraph,
            ),
          );
        } else {
          final prevNode = _document.nodeBefore(extentPos.nodeId);
          if (prevNode == null) return false;
          _requestHandler(
            MergeNodeRequest(firstNodeId: prevNode.id, secondNodeId: node.id),
          );
        }
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
  // Enter (list-item exit / code block)
  // -------------------------------------------------------------------------

  /// Handles Enter inside list items and code blocks.
  ///
  /// **List items:** converts an empty [ListItemNode] to a [ParagraphNode].
  ///
  /// **Code blocks:**
  /// * Empty text → [ExitCodeBlockRequest] (convert in place).
  /// * Cursor at end + text ends with `'\n'` → [ExitCodeBlockRequest] with
  ///   [ExitCodeBlockRequest.removeTrailingNewline] (double-Enter exit).
  /// * Otherwise → [InsertTextRequest] with a newline (stay in block).
  ///
  /// Returns `false` for all other node types so the IME can handle the
  /// normal Enter/newline behavior.
  bool _handleEnter() {
    final selection = _controller.selection;
    if (selection == null || selection.isExpanded) return false;
    final node = _document.nodeById(selection.extent.nodeId);

    // Empty list item → convert to paragraph.
    if (node is ListItemNode && node.text.text.isEmpty) {
      _requestHandler(ConvertListItemToParagraphRequest(nodeId: node.id));
      return true;
    }

    // Empty blockquote → convert to plain paragraph.
    if (node is ParagraphNode &&
        node.blockType == ParagraphBlockType.blockquote &&
        node.text.text.isEmpty) {
      _requestHandler(
        ChangeBlockTypeRequest(
          nodeId: node.id,
          newBlockType: ParagraphBlockType.paragraph,
        ),
      );
      return true;
    }

    // Code block handling.
    if (node is CodeBlockNode) {
      final offset = (selection.extent.nodePosition as TextNodePosition).offset;
      final text = node.text.text;

      if (text.isEmpty) {
        // Empty code block → exit.
        _requestHandler(ExitCodeBlockRequest(nodeId: node.id, splitOffset: 0));
        return true;
      }

      if (offset == text.length && text.endsWith('\n')) {
        // Double-Enter: cursor at end and text ends with newline → exit.
        _requestHandler(
          ExitCodeBlockRequest(
            nodeId: node.id,
            splitOffset: offset,
            removeTrailingNewline: true,
          ),
        );
        return true;
      }

      // Normal Enter inside code block → insert newline, stay in block.
      _requestHandler(
        InsertTextRequest(
          nodeId: node.id,
          offset: offset,
          text: AttributedText('\n'),
        ),
      );
      return true;
    }

    return false;
  }

  // -------------------------------------------------------------------------
  // Shift+Enter (code block exit)
  // -------------------------------------------------------------------------

  /// Handles Shift+Enter to exit a [CodeBlockNode] at the current cursor
  /// position.
  ///
  /// Returns `false` for all non-code-block nodes so the event continues to
  /// other handlers.
  bool _handleShiftEnter() {
    final selection = _controller.selection;
    if (selection == null || selection.isExpanded) return false;
    final node = _document.nodeById(selection.extent.nodeId);
    if (node is! CodeBlockNode) return false;

    final offset = (selection.extent.nodePosition as TextNodePosition).offset;
    _requestHandler(ExitCodeBlockRequest(nodeId: node.id, splitOffset: offset));
    return true;
  }

  // -------------------------------------------------------------------------
  // macOS Emacs bindings
  // -------------------------------------------------------------------------

  /// Handles macOS/iOS Emacs-style Ctrl+letter navigation bindings.
  ///
  /// Only called when Ctrl is held but neither Cmd (Meta) nor Option (Alt)
  /// are simultaneously pressed. Returns `false` for unrecognised keys.
  ///
  /// Supported bindings:
  /// * Ctrl+A — start of current node (line start).
  /// * Ctrl+E — end of current node (line end).
  /// * Ctrl+F — one character forward (right).
  /// * Ctrl+B — one character backward (left).
  /// * Ctrl+N — start of next block (down).
  /// * Ctrl+P — start of previous block (up).
  ///
  /// All bindings respect [shift] for selection extension.
  bool _handleMacEmacsBinding(LogicalKeyboardKey key, {required bool shift}) {
    final selection = _controller.selection;
    if (selection == null) return false;

    final extentPos = selection.extent;
    final node = _document.nodeById(extentPos.nodeId);
    if (node == null) return false;

    if (key == LogicalKeyboardKey.keyA) {
      // Ctrl+A → node start (line start).
      _updateSelection(_startOfNode(node), extend: shift);
      return true;
    }
    if (key == LogicalKeyboardKey.keyE) {
      // Ctrl+E → node end (line end).
      _updateSelection(_endOfNode(node), extend: shift);
      return true;
    }
    if (key == LogicalKeyboardKey.keyF) {
      // Ctrl+F → character forward.
      _updateSelection(_moveCharacterRight(extentPos, node), extend: shift);
      return true;
    }
    if (key == LogicalKeyboardKey.keyB) {
      // Ctrl+B → character backward.
      _updateSelection(_moveCharacterLeft(extentPos, node), extend: shift);
      return true;
    }
    if (key == LogicalKeyboardKey.keyN) {
      // Ctrl+N → next block (down).
      final nextNode = _document.nodeAfter(extentPos.nodeId);
      final newExtent = nextNode == null ? _endOfNode(node) : _startOfNode(nextNode);
      _updateSelection(newExtent, extend: shift);
      return true;
    }
    if (key == LogicalKeyboardKey.keyP) {
      // Ctrl+P → previous block (up).
      final prevNode = _document.nodeBefore(extentPos.nodeId);
      final newExtent = prevNode == null ? _startOfNode(node) : _startOfNode(prevNode);
      _updateSelection(newExtent, extend: shift);
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
  ///
  /// For [TextNode]s, moves one codepoint left within the node's text. At
  /// offset zero, wraps to the downstream end of the previous node.
  ///
  /// For binary nodes ([ImageNode], [HorizontalRuleNode], etc.), a downstream
  /// [BinaryNodePosition] steps back to upstream (same node), and an upstream
  /// position wraps to the end of the previous node. When there is no previous
  /// node the position is unchanged.
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
    } else if (pos.nodePosition is BinaryNodePosition) {
      final binaryPos = pos.nodePosition as BinaryNodePosition;
      if (binaryPos.type == BinaryNodePositionType.downstream) {
        return DocumentPosition(
          nodeId: node.id,
          nodePosition: const BinaryNodePosition.upstream(),
        );
      }
      final prev = _document.nodeBefore(node.id);
      if (prev != null) return _endOfNode(prev);
    }
    return pos;
  }

  /// Moves one character to the right within [node], or wraps to the start of
  /// the next node.
  ///
  /// For [TextNode]s, moves one codepoint right within the node's text. At the
  /// end of the text, wraps to the upstream start of the next node.
  ///
  /// For binary nodes ([ImageNode], [HorizontalRuleNode], etc.), an upstream
  /// [BinaryNodePosition] steps forward to downstream (same node), and a
  /// downstream position wraps to the start of the next node. When there is no
  /// next node the position is unchanged.
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
    } else if (pos.nodePosition is BinaryNodePosition) {
      final binaryPos = pos.nodePosition as BinaryNodePosition;
      if (binaryPos.type == BinaryNodePositionType.upstream) {
        return DocumentPosition(
          nodeId: node.id,
          nodePosition: const BinaryNodePosition.downstream(),
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

  /// Returns `true` when the current platform is macOS or iOS.
  bool _isMacOrIos() {
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Returns `true` when the platform's primary modifier key is currently held.
  ///
  /// Used for Home/End document navigation:
  /// * macOS/iOS — Cmd ([LogicalKeyboardKey.meta]).
  /// * All other platforms — Ctrl ([LogicalKeyboardKey.control]).
  bool _isPrimaryModifierPressed() {
    if (_isMacOrIos()) {
      return HardwareKeyboard.instance.isMetaPressed;
    }
    return HardwareKeyboard.instance.isControlPressed;
  }

  /// Returns `true` when the word-level modifier key is currently held.
  ///
  /// Word-level navigation moves the caret by word boundaries (Left/Right)
  /// or to node start/end (Up/Down):
  /// * macOS/iOS — Option ([LogicalKeyboardKey.alt]).
  /// * All other platforms — Ctrl ([LogicalKeyboardKey.control]).
  bool _isWordModifierPressed() {
    if (_isMacOrIos()) {
      return HardwareKeyboard.instance.isAltPressed;
    }
    return HardwareKeyboard.instance.isControlPressed;
  }

  /// Returns `true` when the line/document-level modifier key is currently held.
  ///
  /// Line-level navigation moves the caret to line start/end (Left/Right)
  /// or document start/end (Up/Down):
  /// * macOS/iOS — Cmd ([LogicalKeyboardKey.meta]).
  /// * All other platforms — Alt ([LogicalKeyboardKey.alt]).
  bool _isLineModifierPressed() {
    if (_isMacOrIos()) {
      return HardwareKeyboard.instance.isMetaPressed;
    }
    return HardwareKeyboard.instance.isAltPressed;
  }
}
