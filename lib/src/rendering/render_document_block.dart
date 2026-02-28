/// Abstract [RenderBox] base for all document block types.
///
/// This file defines [RenderDocumentBlock], the common interface that every
/// per-block render object in the editable_document rendering layer must
/// implement.  The document-level layout and selection systems delegate all
/// geometry queries to this interface.
library;

import 'package:flutter/rendering.dart';

import '../model/document_selection.dart';
import '../model/node_position.dart';

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

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('nodeId', nodeId));
    properties.add(DiagnosticsProperty<DocumentSelection?>('nodeSelection', nodeSelection));
  }
}
