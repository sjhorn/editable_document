/// Document-specific [Intent] classes for the editable_document package.
///
/// Flutter's built-in text editing intents (in `widgets/text_editing_intents.dart`)
/// cover character, word, line, and document navigation plus clipboard operations.
/// This file defines only the intents that are new to block documents — formatting
/// toggles, block-type conversions, list indentation, block insertion, and
/// document-specific navigation.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../model/attribution.dart';
import '../model/list_item_node.dart';
import '../model/paragraph_node.dart';

// ---------------------------------------------------------------------------
// Formatting intents
// ---------------------------------------------------------------------------

/// Toggles an inline [Attribution] on the current selection.
///
/// When the selection is collapsed (caret), this toggles "composing
/// attribution" mode — text typed at this position will have the attribution
/// applied. When the selection is expanded, the attribution is toggled on the
/// selected range.
class ToggleAttributionIntent extends Intent {
  /// Creates an intent to toggle [attribution] on the current selection.
  const ToggleAttributionIntent(this.attribution);

  /// The [Attribution] to toggle.
  final Attribution attribution;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Attribution>('attribution', attribution));
  }
}

/// Removes all inline attributions from the current selection.
class ClearFormattingIntent extends Intent {
  /// Creates an intent to remove all inline attributions from the selection.
  const ClearFormattingIntent();
}

// ---------------------------------------------------------------------------
// Block type intents
// ---------------------------------------------------------------------------

/// Converts the block at the selection to a paragraph (optionally with
/// a specific [ParagraphBlockType]).
class ConvertToParagraphIntent extends Intent {
  /// Creates an intent to convert the current block to a paragraph.
  ///
  /// When [blockType] is `null`, the block becomes a normal paragraph.
  /// Pass a [ParagraphBlockType] value (e.g. [ParagraphBlockType.header1])
  /// to convert to a heading or other semantic paragraph type.
  const ConvertToParagraphIntent({this.blockType});

  /// Optional paragraph block type (heading1, heading2, etc.).
  ///
  /// When `null`, converts to a normal paragraph.
  final ParagraphBlockType? blockType;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      EnumProperty<ParagraphBlockType>('blockType', blockType, defaultValue: null),
    );
  }
}

/// Converts the block at the selection to a blockquote.
class ConvertToBlockquoteIntent extends Intent {
  /// Creates an intent to convert the current block to a blockquote.
  const ConvertToBlockquoteIntent();
}

/// Converts the block at the selection to a code block.
class ConvertToCodeBlockIntent extends Intent {
  /// Creates an intent to convert the current block to a code block.
  const ConvertToCodeBlockIntent();
}

/// Converts the block at the selection to a list item.
class ConvertToListItemIntent extends Intent {
  /// Creates an intent to convert the current block to a list item of
  /// [listType].
  const ConvertToListItemIntent(this.listType);

  /// The type of list item (ordered or unordered).
  final ListItemType listType;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<ListItemType>('listType', listType));
  }
}

// ---------------------------------------------------------------------------
// Text alignment intent
// ---------------------------------------------------------------------------

/// Changes the text alignment of the block at the selection.
class ChangeTextAlignIntent extends Intent {
  /// Creates an intent to apply [textAlign] to the block at the selection.
  const ChangeTextAlignIntent(this.textAlign);

  /// The desired [TextAlign] value.
  final TextAlign textAlign;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign));
  }
}

// ---------------------------------------------------------------------------
// List indentation intents
// ---------------------------------------------------------------------------

/// Indents the current list item one level deeper.
class IndentListItemIntent extends Intent {
  /// Creates an intent to indent the current list item.
  const IndentListItemIntent();
}

/// Unindents the current list item one level.
class UnindentListItemIntent extends Intent {
  /// Creates an intent to unindent the current list item.
  const UnindentListItemIntent();
}

// ---------------------------------------------------------------------------
// Block insertion intents
// ---------------------------------------------------------------------------

/// Inserts a horizontal rule at the current selection position.
class InsertHorizontalRuleIntent extends Intent {
  /// Creates an intent to insert a horizontal rule.
  const InsertHorizontalRuleIntent();
}

/// Inserts an image block at the current selection position.
class InsertImageIntent extends Intent {
  /// Creates an intent to insert an image at the current selection.
  ///
  /// [imageUrl] is the URL (or asset path) of the image. [altText] is an
  /// optional accessibility description.
  const InsertImageIntent({required this.imageUrl, this.altText});

  /// The URL or asset path of the image to insert.
  final String imageUrl;

  /// Optional alt text for accessibility.
  final String? altText;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('imageUrl', imageUrl));
    properties.add(StringProperty('altText', altText, defaultValue: null));
  }
}

/// Inserts a table at the current selection position.
class InsertTableIntent extends Intent {
  /// Creates an intent to insert a table with [rows] rows and [columns]
  /// columns.
  const InsertTableIntent({required this.rows, required this.columns});

  /// The number of rows in the new table.
  final int rows;

  /// The number of columns in the new table.
  final int columns;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('rows', rows));
    properties.add(IntProperty('columns', columns));
  }
}

// ---------------------------------------------------------------------------
// Document-specific navigation intents
// ---------------------------------------------------------------------------

/// Moves the caret to the start or end of the current node.
///
/// Flutter's text intents handle character, word, line, and document
/// boundaries — but not "node" boundaries. This intent handles
/// node-level navigation (e.g., Option+Up/Down on macOS, Ctrl+Up/Down
/// on Windows/Linux).
class MoveToNodeBoundaryIntent extends Intent {
  /// Creates an intent to move to the start or end of the current node.
  ///
  /// Set [forward] to `true` to move to the end of the node; `false` to move
  /// to the start. Set [extend] to `true` to extend the selection instead of
  /// collapsing it.
  const MoveToNodeBoundaryIntent({required this.forward, this.extend = false});

  /// `true` for end of node, `false` for start.
  final bool forward;

  /// Whether to extend the selection instead of collapsing.
  final bool extend;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('forward', value: forward, ifTrue: 'forward', ifFalse: 'backward'));
    properties.add(FlagProperty('extend', value: extend, ifTrue: 'extend'));
  }
}

/// Moves the caret to the next/previous cell in a table.
///
/// Tab/Shift+Tab within a table navigates cells. This is document-specific
/// behaviour that Flutter's built-in intents do not cover.
class MoveToAdjacentTableCellIntent extends Intent {
  /// Creates an intent to move to the next or previous table cell.
  ///
  /// Set [forward] to `true` to move to the next cell, `false` for the
  /// previous cell.
  const MoveToAdjacentTableCellIntent({required this.forward});

  /// `true` for next cell, `false` for previous.
  final bool forward;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('forward', value: forward, ifTrue: 'forward', ifFalse: 'backward'));
  }
}

/// Collapses an expanded selection to its extent position.
class CollapseSelectionIntent extends Intent {
  /// Creates an intent to collapse the current selection to its extent.
  const CollapseSelectionIntent();
}

// ---------------------------------------------------------------------------
// Table editing intents
// ---------------------------------------------------------------------------

/// Inserts a row above or below the current row in a table.
class InsertTableRowIntent extends Intent {
  /// Creates an intent to insert a table row.
  ///
  /// Set [below] to `true` to insert below the current row, `false` to insert
  /// above.
  const InsertTableRowIntent({required this.below});

  /// `true` to insert below the current row, `false` to insert above.
  final bool below;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('below', value: below, ifTrue: 'below', ifFalse: 'above'));
  }
}

/// Inserts a column to the left or right of the current column in a table.
class InsertTableColumnIntent extends Intent {
  /// Creates an intent to insert a table column.
  ///
  /// Set [after] to `true` to insert to the right of the current column,
  /// `false` to insert to the left.
  const InsertTableColumnIntent({required this.after});

  /// `true` to insert after the current column, `false` to insert before.
  final bool after;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('after', value: after, ifTrue: 'after', ifFalse: 'before'));
  }
}

/// Deletes the current row from a table.
class DeleteTableRowIntent extends Intent {
  /// Creates an intent to delete the current table row.
  const DeleteTableRowIntent();
}

/// Deletes the current column from a table.
class DeleteTableColumnIntent extends Intent {
  /// Creates an intent to delete the current table column.
  const DeleteTableColumnIntent();
}

/// Deletes the entire table and replaces it with an empty paragraph.
class DeleteTableIntent extends Intent {
  /// Creates an intent to delete the entire table.
  const DeleteTableIntent();
}
