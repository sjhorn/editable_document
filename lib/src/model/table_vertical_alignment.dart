/// Vertical alignment enum for table cells in the editable_document package.
///
/// Used by [TableNode.cellVerticalAligns] to control how cell content is
/// positioned vertically within each cell.
library;

// ---------------------------------------------------------------------------
// TableVerticalAlignment
// ---------------------------------------------------------------------------

/// Vertical alignment of text within a table cell.
///
/// Used by [TableNode.cellVerticalAligns] to control how cell content is
/// positioned vertically within each cell.
enum TableVerticalAlignment {
  /// Align cell content to the top of the row (default).
  top,

  /// Vertically center cell content within the row.
  middle,

  /// Align cell content to the bottom of the row.
  bottom,
}
