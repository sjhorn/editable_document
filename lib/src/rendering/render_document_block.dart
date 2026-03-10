/// Abstract [RenderBox] base for all document block types.
///
/// This file defines [RenderDocumentBlock], the common interface that every
/// per-block render object in the editable_document rendering layer must
/// implement.  The document-level layout and selection systems delegate all
/// geometry queries to this interface.
library;

import 'package:flutter/rendering.dart';

import '../model/block_alignment.dart';
import '../model/document_selection.dart';
import '../model/node_position.dart';
import '../model/text_wrap_mode.dart';

/// Abstract [RenderBox] base for all document block types.
///
/// Every block type must implement [getLocalRectForPosition],
/// [getPositionAtOffset], and [getEndpointsForSelection] so that the
/// document-level selection system can delegate geometry queries.
///
/// Concrete implementations include [RenderTextBlock], [RenderImageBlock],
/// and [RenderHorizontalRuleBlock].
abstract class RenderDocumentBlock extends RenderBox {
  /// The unique identifier of the document node this block renders.
  ///
  /// Matches the [DocumentNode.id] of the corresponding model node.
  String get nodeId;

  /// Sets the node identifier.
  ///
  /// Changing this value marks the render object as needing paint so any
  /// debug overlays are updated.
  set nodeId(String value);

  /// The portion of the document selection that intersects this block,
  /// or `null` when no selection is active in this block.
  DocumentSelection? get nodeSelection;

  /// Sets the node selection and triggers a repaint.
  ///
  /// Setting this to a non-null value causes selection highlights to be
  /// drawn during [paint]. Setting it to `null` clears any selection
  /// highlight.
  set nodeSelection(DocumentSelection? value);

  /// Returns the local rect for [position] within this block.
  ///
  /// For text blocks, this is the caret rect at the given character offset.
  /// For binary-position blocks (images, horizontal rules), this is the
  /// leading or trailing edge of the block.
  ///
  /// Must only be called after layout.
  Rect getLocalRectForPosition(NodePosition position);

  /// Returns the [NodePosition] nearest to [localOffset].
  ///
  /// Performs a hit-test in local coordinates and returns the closest
  /// meaningful position within this block.  For text blocks this delegates
  /// to [TextPainter.getPositionForOffset]; for binary-position blocks it
  /// returns [BinaryNodePosition.upstream] or [BinaryNodePosition.downstream]
  /// based on which half of the block was tapped.
  ///
  /// Must only be called after layout.
  NodePosition getPositionAtOffset(Offset localOffset);

  /// Returns the rects that represent the selection between [base] and [extent].
  ///
  /// For text blocks, these are the [TextBox]es returned by
  /// [TextPainter.getBoxesForSelection].  For binary-position blocks, the
  /// result is either the full block rect (when both endpoints are present)
  /// or an empty list.
  ///
  /// Must only be called after layout.
  List<Rect> getEndpointsForSelection(NodePosition base, NodePosition extent);

  /// The horizontal alignment of this block within the layout.
  ///
  /// Text blocks default to [BlockAlignment.stretch] and fill the available
  /// width.  Container blocks (image, code, blockquote, horizontal rule) may
  /// override this to return the value set by the widget layer.
  BlockAlignment get blockAlignment => BlockAlignment.stretch;

  /// The requested width of this block in logical pixels, or `null`.
  ///
  /// When non-null, the document layout uses this value instead of the full
  /// available width.  Text blocks return `null` by default (full width).
  double? get requestedWidth => null;

  /// The requested height of this block in logical pixels, or `null`.
  ///
  /// When non-null, the document layout uses this value to constrain the
  /// block height.  Text blocks return `null` by default (intrinsic height).
  double? get requestedHeight => null;

  /// How surrounding text interacts with this block.
  ///
  /// When [TextWrapMode.wrap] and [blockAlignment] is [BlockAlignment.start],
  /// [BlockAlignment.end], or [BlockAlignment.center], the document layout
  /// creates an exclusion zone and adjacent blocks receive reduced-width
  /// constraints.  Other modes position the block like a float but without
  /// creating an exclusion zone.
  TextWrapMode get textWrap => TextWrapMode.none;

  /// Whether this block should clear active float exclusion zones.
  ///
  /// When `true` and [blockAlignment] is [BlockAlignment.stretch], the
  /// document layout advances past any active float before laying out this
  /// block at full width.  Defaults to `false`, meaning stretch blocks
  /// narrow to fit beside floats.
  ///
  /// Override to `true` in block types that are full-width dividers
  /// (e.g. horizontal rules without an explicit [requestedWidth]).
  bool get clearsFloat => false;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('nodeId', nodeId));
    properties.add(DiagnosticsProperty<DocumentSelection?>('nodeSelection', nodeSelection));
    properties.add(EnumProperty<BlockAlignment>('blockAlignment', blockAlignment));
    properties.add(DoubleProperty('requestedWidth', requestedWidth));
    properties.add(DoubleProperty('requestedHeight', requestedHeight));
    properties
        .add(EnumProperty<TextWrapMode>('textWrap', textWrap, defaultValue: TextWrapMode.none));
    properties.add(DiagnosticsProperty<bool>('clearsFloat', clearsFloat));
  }
}
