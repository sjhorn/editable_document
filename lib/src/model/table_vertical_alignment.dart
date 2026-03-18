/// Vertical alignment enum for table rows in the editable_document package.
///
/// Used by [TableNode.rowVerticalAligns] to control how cell content is
/// positioned vertically within each row.
library;

// ---------------------------------------------------------------------------
// TableVerticalAlignment
// ---------------------------------------------------------------------------

/// Vertical alignment of text within a table row.
///
/// Used by [TableNode.rowVerticalAligns] to control how cell content is
/// positioned vertically within each row.
enum TableVerticalAlignment {
  /// Align cell content to the top of the row (default).
  top,

  /// Vertically center cell content within the row.
  middle,

  /// Align cell content to the bottom of the row.
  bottom,
}
