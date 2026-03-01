/// Android-specific document caret widget for the editable_document package.
///
/// [AndroidDocumentCaret] is the draggable caret used on Android. It renders
/// a thin vertical bar (the caret) together with a circular drag handle below
/// it, and positions itself via a [CompositedTransformFollower] linked to the
/// [layerLink] provided by [DocumentSelectionOverlay].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AndroidDocumentCaret
// ---------------------------------------------------------------------------

/// An Android-style draggable caret widget.
///
/// [AndroidDocumentCaret] renders a vertical caret line and a circle handle
/// below it, matching Android's stock text-editing visual style. It tracks
/// the selection-endpoint position via [CompositedTransformFollower].
///
/// Drag events are reported via [onDragStart], [onDragUpdate], and
/// [onDragEnd], allowing the gesture controller to move the caret position.
///
/// ```dart
/// AndroidDocumentCaret(
///   layerLink: overlayState.endHandleLayerLink,
///   color: Theme.of(context).colorScheme.primary,
///   onDragUpdate: (details) => _onCaretDrag(details),
/// )
/// ```
class AndroidDocumentCaret extends StatelessWidget {
  /// Creates an [AndroidDocumentCaret].
  ///
  /// [layerLink] is the [LayerLink] used to position the caret. [color]
  /// is applied to both the vertical bar and the handle circle.
  ///
  /// [onDragStart], [onDragUpdate], and [onDragEnd] are optional drag
  /// callbacks invoked when the user drags the caret handle.
  const AndroidDocumentCaret({
    super.key,
    required this.layerLink,
    required this.color,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  /// The [LayerLink] used to position this caret via
  /// [CompositedTransformFollower].
  final LayerLink layerLink;

  /// The colour of the caret bar and handle circle.
  final Color color;

  /// Called when the user starts dragging the caret handle.
  final VoidCallback? onDragStart;

  /// Called whenever the user moves the caret handle.
  final ValueChanged<DragUpdateDetails>? onDragUpdate;

  /// Called when the user releases the caret handle.
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: layerLink,
      showWhenUnlinked: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: onDragStart != null ? (_) => onDragStart!() : null,
        onPanUpdate: onDragUpdate,
        onPanEnd: onDragEnd != null ? (_) => onDragEnd!() : null,
        child: CustomPaint(
          size: const Size(20, 40),
          painter: _AndroidCaretPainter(color: color),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('color', color));
    properties.add(DiagnosticsProperty<LayerLink>('layerLink', layerLink));
    properties.add(
      FlagProperty(
        'onDragStart',
        value: onDragStart != null,
        ifTrue: 'has onDragStart',
      ),
    );
    properties.add(
      FlagProperty(
        'onDragUpdate',
        value: onDragUpdate != null,
        ifTrue: 'has onDragUpdate',
      ),
    );
    properties.add(
      FlagProperty(
        'onDragEnd',
        value: onDragEnd != null,
        ifTrue: 'has onDragEnd',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AndroidCaretPainter
// ---------------------------------------------------------------------------

/// Paints an Android-style caret: a 2 dp vertical bar with a circle handle
/// below it.
class _AndroidCaretPainter extends CustomPainter {
  const _AndroidCaretPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Vertical bar — 2 dp wide, occupying the top half of the paint area.
    final barWidth = 2.0;
    final barHeight = size.height * 0.6;
    final barLeft = (size.width - barWidth) / 2;
    canvas.drawRect(
      Rect.fromLTWH(barLeft, 0, barWidth, barHeight),
      paint,
    );

    // Circle handle below the bar.
    final circleRadius = size.width / 2 - 1;
    final circleCenter = Offset(size.width / 2, barHeight + circleRadius + 1);
    canvas.drawCircle(circleCenter, circleRadius, paint);
  }

  @override
  bool shouldRepaint(_AndroidCaretPainter oldDelegate) => oldDelegate.color != color;
}
