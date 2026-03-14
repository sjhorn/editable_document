/// Block layout interface for container document nodes.
///
/// Provides [HasBlockLayout], the common interface for nodes that support
/// block-level layout properties: alignment, text wrapping, width, height,
/// draggability, resizability, and size-copy.
library;

import 'block_alignment.dart';
import 'document_node.dart';
import 'text_wrap_mode.dart';

/// Interface for document nodes that support block-level layout properties.
///
/// Container block nodes — [ImageNode], [CodeBlockNode], [BlockquoteNode],
/// [HorizontalRuleNode], and [TableNode] — all implement this interface,
/// providing a uniform way to read and update their layout properties without
/// type-checking each concrete type.
///
/// ```dart
/// if (node is HasBlockLayout) {
///   final alignment = node.alignment;
///   final wrap = node.textWrap;
///   if (node.isResizable) {
///     final resized = node.copyWithSize(width: 320.0);
///   }
/// }
/// ```
abstract interface class HasBlockLayout {
  /// How the block is horizontally aligned within the available layout width.
  BlockAlignment get alignment;

  /// How surrounding text interacts with this block.
  TextWrapMode get textWrap;

  /// Preferred display width in logical pixels, or `null` for default sizing.
  double? get width;

  /// Preferred display height in logical pixels, or `null` for default sizing.
  double? get height;

  /// Whether this block can be dragged to a new position in the document.
  ///
  /// All concrete [HasBlockLayout] implementations return `true` by default,
  /// allowing drag-to-move interactions at the editing layer. Override to
  /// return `false` for nodes that should remain anchored in place.
  bool get isDraggable;

  /// Whether this block can be resized via drag handles.
  ///
  /// Returns `true` when [alignment] is not [BlockAlignment.stretch], because
  /// stretch-aligned blocks fill the full available width and resizing them
  /// independently would conflict with the stretch constraint. When
  /// [alignment] is [BlockAlignment.stretch] this returns `false`.
  bool get isResizable;

  /// Returns a copy of this node with updated [width], [height], and/or [alignment].
  ///
  /// This eliminates the need for type-dispatching in resize and re-alignment
  /// operations. Pass `null` for any parameter to preserve the current value.
  ///
  /// ```dart
  /// final resized = (node as HasBlockLayout).copyWithSize(width: 400.0);
  /// final realigned = (node as HasBlockLayout).copyWithSize(
  ///   alignment: BlockAlignment.center,
  /// );
  /// ```
  DocumentNode copyWithSize({double? width, double? height, BlockAlignment? alignment});
}
