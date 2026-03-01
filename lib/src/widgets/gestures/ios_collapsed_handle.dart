/// iOS-style collapsed (caret) selection handle for the editable_document
/// package.
///
/// [IOSCollapsedHandle] paints the iOS teardrop-shaped caret handle and
/// provides drag callbacks so gesture controllers can move the caret as
/// the user drags.
///
/// The handle is positioned via [CompositedTransformFollower] attached to
/// [layerLink], which should be the same [LayerLink] exposed by the
/// [DocumentSelectionOverlay.startHandleLayerLink].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// IOSCollapsedHandle
// ---------------------------------------------------------------------------

/// An iOS-style teardrop caret handle that follows a [LayerLink].
///
/// Used by iOS gesture controllers to display and drag the collapsed
/// caret handle. The handle paints a teardrop/pin shape using [CustomPaint].
///
/// Provide drag callbacks to react when the user moves the handle:
///
/// ```dart
/// IOSCollapsedHandle(
///   layerLink: startHandleLayerLink,
///   color: Theme.of(context).colorScheme.primary,
///   onDragStart: () => _showMagnifier(),
///   onDragUpdate: (details) => _moveCaret(details.globalPosition),
///   onDragEnd: () => _hideMagnifier(),
/// )
/// ```
class IOSCollapsedHandle extends StatelessWidget {
  /// Creates an [IOSCollapsedHandle].
  ///
  /// [layerLink] is the [LayerLink] that positions the handle.
  /// [color] is the fill colour of the teardrop shape.
  /// [onDragStart], [onDragUpdate], and [onDragEnd] are optional drag
  /// lifecycle callbacks.
  const IOSCollapsedHandle({
    super.key,
    required this.layerLink,
    required this.color,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  /// The [LayerLink] used to position this handle via
  /// [CompositedTransformFollower].
  final LayerLink layerLink;

  /// The colour of the teardrop handle shape.
  final Color color;

  /// Called when a drag gesture starts on this handle.
  final VoidCallback? onDragStart;

  /// Called during a drag gesture with the current [DragUpdateDetails].
  final ValueChanged<DragUpdateDetails>? onDragUpdate;

  /// Called when a drag gesture ends on this handle.
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
        child: SizedBox(
          width: 24,
          height: 36,
          child: CustomPaint(
            painter: _IOSCollapsedHandlePainter(color: color),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LayerLink>('layerLink', layerLink));
    properties.add(ColorProperty('color', color));
    properties
        .add(FlagProperty('onDragStart', value: onDragStart != null, ifTrue: 'has onDragStart'));
    properties
        .add(FlagProperty('onDragUpdate', value: onDragUpdate != null, ifTrue: 'has onDragUpdate'));
    properties.add(FlagProperty('onDragEnd', value: onDragEnd != null, ifTrue: 'has onDragEnd'));
  }
}

// ---------------------------------------------------------------------------
// _IOSCollapsedHandlePainter
// ---------------------------------------------------------------------------

/// Paints the iOS-style teardrop/pin handle shape for a collapsed caret.
///
/// The shape consists of a circle at the bottom and a thin vertical line
/// (the stem) pointing upward, matching the native iOS caret handle appearance.
class _IOSCollapsedHandlePainter extends CustomPainter {
  /// Creates a [_IOSCollapsedHandlePainter] with the given [color].
  const _IOSCollapsedHandlePainter({required this.color});

  /// The fill colour of the handle shape.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw the ball at the bottom.
    final ballRadius = size.width / 2;
    final ballCenter = Offset(size.width / 2, size.height - ballRadius);
    canvas.drawCircle(ballCenter, ballRadius, paint);

    // Draw the stem (thin vertical line from the top).
    final stemRect = Rect.fromLTWH(
      size.width / 2 - 1.5,
      0,
      3,
      size.height - ballRadius * 1.5,
    );
    canvas.drawRect(stemRect, paint);
  }

  @override
  bool shouldRepaint(_IOSCollapsedHandlePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
