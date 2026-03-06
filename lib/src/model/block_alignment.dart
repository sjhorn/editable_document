/// Block-level horizontal alignment for the editable_document package.
///
/// Determines how a sized block element is positioned within the available
/// layout width. Used by [ImageNode], [CodeBlockNode], and other block-level
/// nodes that have a finite, user-controlled width.
library;

/// Block-level horizontal alignment for container document nodes.
///
/// Determines how a sized block (image, code block, blockquote, horizontal
/// rule) is positioned within the available layout width.
///
/// [start] and [end] are directionality-aware: in LTR layouts [start] means
/// left-aligned and [end] means right-aligned; in RTL layouts the mapping is
/// reversed.
///
/// The default alignment everywhere in the framework is [stretch], which causes
/// the block to fill the entire available width — matching the existing
/// full-width layout behavior.
///
/// ```dart
/// final image = ImageNode(
///   id: 'img-1',
///   imageUrl: 'https://example.com/photo.jpg',
///   metadata: {'alignment': BlockAlignment.center},
/// );
/// ```
enum BlockAlignment {
  /// Align the block to the start edge of the layout (left in LTR, right in RTL).
  start,

  /// Center the block horizontally within the available width.
  center,

  /// Align the block to the end edge of the layout (right in LTR, left in RTL).
  end,

  /// Stretch the block to fill the entire available width (default).
  stretch,
}
