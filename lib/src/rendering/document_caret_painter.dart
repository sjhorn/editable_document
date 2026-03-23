/// Caret (cursor) painter for the editable_document rendering layer.
///
/// [DocumentCaretPainter] is a [CustomPainter] responsible solely for
/// drawing a blinking text cursor.  Blink animation is driven by the
/// widget layer via the [visible] flag — this painter never schedules
/// its own animation.
library;

import 'package:flutter/rendering.dart';

/// A [CustomPainter] that draws a single text-cursor rectangle.
///
/// The caret is painted as an [RRect] with [cornerRadius] applied to all
/// corners, using [color] as the fill.  When [visible] is `false` or
/// [caretRect] is `null`, nothing is drawn.
///
/// Blink is controlled by the widget layer: the widget toggles [visible]
/// at each blink interval, which triggers a repaint via [shouldRepaint].
/// This painter never calls `markNeedsPaint` directly.
///
/// Example:
/// ```dart
/// CustomPaint(
///   painter: DocumentCaretPainter(
///     caretRect: Rect.fromLTWH(42, 0, 2, 20),
///     color: Colors.black,
///   ),
/// )
/// ```
class DocumentCaretPainter extends CustomPainter {
  /// Creates a [DocumentCaretPainter].
  ///
  /// [caretRect] is the bounding box of the cursor in layout coordinates.
  /// Pass `null` to suppress painting entirely.
  ///
  /// [color] defaults to opaque black (`0xFF000000`).
  ///
  /// `width` overrides the painted rect width; defaults to `2.0` pixels.
  ///
  /// [cornerRadius] is the radius applied to every corner of the drawn
  /// [RRect]; defaults to `1.0` pixel.
  ///
  /// [visible] controls blink; defaults to `true`.
  const DocumentCaretPainter({
    required this.caretRect,
    this.color = const Color(0xFF000000),
    this.width = 2.0,
    this.cornerRadius = 1.0,
    this.visible = true,
  });

  /// The position and height of the caret in layout coordinates.
  ///
  /// When `null`, [paint] is a no-op.
  final Rect? caretRect;

  /// The fill colour of the cursor rectangle.
  final Color color;

  /// The painted width of the cursor in logical pixels.
  ///
  /// The [caretRect] width is ignored; this value is used instead so that
  /// the cursor always has a consistent visual weight regardless of where
  /// it was computed.
  final double width;

  /// The corner radius applied to all four corners of the drawn [RRect].
  final double cornerRadius;

  /// Whether the caret is currently visible (controls blink state).
  ///
  /// When `false`, [paint] is a no-op.  The widget layer toggles this to
  /// implement blinking without triggering a layout pass.
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = caretRect;
    if (rect == null || !visible) return;

    final paintedRect = Rect.fromLTWH(rect.left, rect.top, width, rect.height);
    final rrect = RRect.fromRectAndRadius(paintedRect, Radius.circular(cornerRadius));
    canvas.drawRRect(rrect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(DocumentCaretPainter oldDelegate) {
    return oldDelegate.caretRect != caretRect ||
        oldDelegate.color != color ||
        oldDelegate.visible != visible;
  }
}
