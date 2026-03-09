/// Block layout interface for container document nodes.
///
/// Provides [HasBlockLayout], the common interface for nodes that support
/// block-level layout properties: alignment, text wrapping, width, and height.
library;

import 'block_alignment.dart';

/// Interface for document nodes that support block-level layout properties.
///
/// Container block nodes — [ImageNode], [CodeBlockNode], [BlockquoteNode],
/// and [HorizontalRuleNode] — all implement this interface, providing a
/// uniform way to read their layout properties without type-checking each
/// concrete type.
///
/// ```dart
/// if (node is HasBlockLayout) {
///   final alignment = node.alignment;
///   final wrap = node.textWrap;
/// }
/// ```
abstract interface class HasBlockLayout {
  /// How the block is horizontally aligned within the available layout width.
  BlockAlignment get alignment;

  /// Whether surrounding text may flow around this block.
  bool get textWrap;

  /// Preferred display width in logical pixels, or `null` for default sizing.
  double? get width;

  /// Preferred display height in logical pixels, or `null` for default sizing.
  double? get height;
}
