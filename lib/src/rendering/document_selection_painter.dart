/// Selection highlight painter for the editable_document rendering layer.
///
/// [DocumentSelectionPainter] is a [CustomPainter] that draws cross-block
/// selection highlights.  Pre-computed selection rectangles (in layout
/// coordinates) are supplied by the widget layer so that this painter
/// remains simple, testable, and decoupled from [RenderDocumentLayout].
library;

import 'package:flutter/rendering.dart';

/// A [CustomPainter] that draws selection-highlight rectangles.
///
/// Selection geometry is computed outside this painter — typically by
/// iterating [RenderDocumentBlock] children via [RenderDocumentLayout] —
/// and passed in as [selectionRects].  Each rectangle is painted in
/// [selectionColor].
///
/// When [selectionRects] is empty (no selection or collapsed caret),
/// [paint] is a no-op.
///
/// ## Performance contract
///
/// This painter must never trigger a layout pass.  [shouldRepaint]
/// compares [selectionRects] by identity/equality and [selectionColor]
/// to avoid unnecessary repaints.
///
/// Example:
/// ```dart
/// CustomPaint(
///   painter: DocumentSelectionPainter(
///     selectionRects: [Rect.fromLTWH(0, 0, 200, 20)],
///     selectionColor: Color(0x663399FF),
///   ),
/// )
/// ```
class DocumentSelectionPainter extends CustomPainter {
  /// Creates a [DocumentSelectionPainter].
  ///
  /// [selectionRects] are the pre-computed bounding boxes of the selection
  /// highlight in layout coordinates.  Pass an empty list to suppress
  /// painting.
  ///
  /// [selectionColor] defaults to a semi-transparent blue (`0x663399FF`).
  const DocumentSelectionPainter({
    required this.selectionRects,
    this.selectionColor = const Color(0x663399FF),
  });

  /// The selection highlight rectangles in layout coordinates.
  ///
  /// Typically obtained by calling [RenderDocumentBlock.getEndpointsForSelection]
  /// for each node that falls within the active selection and translating
  /// results into the coordinate space of the owning [CustomPaint].
  ///
  /// An empty list means nothing is painted.
  final List<Rect> selectionRects;

  /// The colour used to fill each selection-highlight rectangle.
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionRects.isEmpty) return;

    final paint = Paint()..color = selectionColor;
    for (final rect in selectionRects) {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(DocumentSelectionPainter oldDelegate) {
    if (oldDelegate.selectionColor != selectionColor) return true;
    if (oldDelegate.selectionRects.length != selectionRects.length) return true;
    for (var i = 0; i < selectionRects.length; i++) {
      if (oldDelegate.selectionRects[i] != selectionRects[i]) return true;
    }
    return false;
  }
}
