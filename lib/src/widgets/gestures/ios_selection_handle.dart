/// iOS-style selection handles for the editable_document package.
///
/// Provides [HandleType] (iOS handle variants) and [IOSSelectionHandle] —
/// the left (base) and right (extent) handles that appear when text is
/// selected on iOS. Dragging a handle extends or shrinks the selection.
///
/// The handle is positioned via [CompositedTransformFollower] attached to the
/// supplied [layerLink], which should correspond to either
/// [DocumentSelectionOverlay.startHandleLayerLink] (for the left handle) or
/// [DocumentSelectionOverlay.endHandleLayerLink] (for the right handle).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// HandleType
// ---------------------------------------------------------------------------

/// The side of a selection that an iOS handle represents.
///
/// [left] corresponds to the selection-start (base) handle and is drawn with
/// a downward-right teardrop. [right] corresponds to the selection-end (extent)
/// handle and is drawn with a downward-left teardrop.
enum HandleType {
  /// The left (base/start) selection handle.
  left,

  /// The right (extent/end) selection handle.
  right,
}

// ---------------------------------------------------------------------------
// IOSSelectionHandle
// ---------------------------------------------------------------------------

/// An iOS-style selection handle that follows a [LayerLink].
///
/// Shows a circle with a directional stem matching iOS's native selection
/// handles. Create two instances — one for the selection start
/// ([HandleType.left]) and one for the selection end ([HandleType.right]).
///
/// ```dart
/// IOSSelectionHandle(
///   layerLink: startHandleLayerLink,
///   type: HandleType.left,
///   color: Theme.of(context).colorScheme.primary,
///   onDragStart: () => _showMagnifier(),
///   onDragUpdate: (details) => _extendSelection(details.globalPosition),
///   onDragEnd: () => _hideMagnifier(),
/// )
/// ```
class IOSSelectionHandle extends StatelessWidget {
  /// Creates an [IOSSelectionHandle].
  ///
  /// [layerLink] positions the handle. [type] controls the direction of the
  /// teardrop stem (use [HandleType.left] or [HandleType.right]).
  /// [color] is the fill colour.
  const IOSSelectionHandle({
    super.key,
    required this.layerLink,
    required this.type,
    required this.color,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  /// The [LayerLink] used to position this handle via
  /// [CompositedTransformFollower].
  final LayerLink layerLink;

  /// Which end of the selection this handle represents.
  ///
  /// Use [HandleType.left] for the selection-start handle and
  /// [HandleType.right] for the selection-end handle.
  final HandleType type;

  /// The colour of the handle shape.
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
            painter: _IOSSelectionHandlePainter(color: color, type: type),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LayerLink>('layerLink', layerLink));
    properties.add(EnumProperty<HandleType>('type', type));
    properties.add(ColorProperty('color', color));
    properties.add(
      FlagProperty('onDragStart', value: onDragStart != null, ifTrue: 'has onDragStart'),
    );
    properties.add(
      FlagProperty('onDragUpdate', value: onDragUpdate != null, ifTrue: 'has onDragUpdate'),
    );
    properties.add(
      FlagProperty('onDragEnd', value: onDragEnd != null, ifTrue: 'has onDragEnd'),
    );
  }
}

// ---------------------------------------------------------------------------
// _IOSSelectionHandlePainter
// ---------------------------------------------------------------------------

/// Paints the iOS-style selection handle for [type].
///
/// [HandleType.left] draws a ball at the bottom-left with a stem pointing
/// up-right. [HandleType.right] draws a ball at the bottom-right with a
/// stem pointing up-left. [HandleType.collapsed] uses the right-hand layout
/// as a fallback.
class _IOSSelectionHandlePainter extends CustomPainter {
  /// Creates a [_IOSSelectionHandlePainter].
  const _IOSSelectionHandlePainter({required this.color, required this.type});

  /// The fill colour.
  final Color color;

  /// The handle side, controlling stem direction.
  final HandleType type;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final ballRadius = size.width / 2;

    if (type == HandleType.left) {
      // Left handle: ball at bottom-left, stem goes up-right.
      final ballCenter = Offset(ballRadius, size.height - ballRadius);
      canvas.drawCircle(ballCenter, ballRadius, paint);

      // Stem: angled from ball top-right to upper-right corner.
      final path = Path()
        ..moveTo(ballCenter.dx, ballCenter.dy - ballRadius)
        ..lineTo(size.width, 0)
        ..lineTo(size.width - 3, 0)
        ..lineTo(ballCenter.dx - 1.5, ballCenter.dy - ballRadius)
        ..close();
      canvas.drawPath(path, paint);
    } else {
      // Right handle (and collapsed fallback): ball at bottom-right, stem up-left.
      final ballCenter = Offset(size.width - ballRadius, size.height - ballRadius);
      canvas.drawCircle(ballCenter, ballRadius, paint);

      // Stem: angled from ball top-left to upper-left corner.
      final path = Path()
        ..moveTo(ballCenter.dx, ballCenter.dy - ballRadius)
        ..lineTo(0, 0)
        ..lineTo(3, 0)
        ..lineTo(ballCenter.dx + 1.5, ballCenter.dy - ballRadius)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_IOSSelectionHandlePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}
