/// Android-style selection handles for the editable_document package.
///
/// Provides [AndroidHandleType] (the three Android handle variants) and
/// [AndroidSelectionHandle] (a [StatelessWidget] that renders the handle
/// and reports drag events to the gesture controller).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AndroidHandleType
// ---------------------------------------------------------------------------

/// The visual variant of an Android selection handle.
///
/// - [left] — left handle of an expanded selection (teardrop pointing
///   right, placed at the start of the selected range).
/// - [right] — right handle of an expanded selection (teardrop pointing
///   left, placed at the end of the selected range).
/// - [collapsed] — collapsed-selection handle (lollipop / circular,
///   placed below the caret).
enum AndroidHandleType {
  /// Left handle of an expanded selection.
  left,

  /// Right handle of an expanded selection.
  right,

  /// Handle for a collapsed selection (caret handle).
  collapsed,
}

// ---------------------------------------------------------------------------
// AndroidSelectionHandle
// ---------------------------------------------------------------------------

/// An Android-style selection drag handle.
///
/// [AndroidSelectionHandle] renders a teardrop (for [AndroidHandleType.left]
/// and [AndroidHandleType.right]) or a lollipop/circle (for
/// [AndroidHandleType.collapsed]) and uses a [CompositedTransformFollower]
/// to track a [layerLink] so that the handle moves with the document layout
/// during scrolling.
///
/// Drag events are reported via [onDragStart], [onDragUpdate], and
/// [onDragEnd] so the gesture controller can extend or move the selection.
///
/// ```dart
/// AndroidSelectionHandle(
///   layerLink: overlayState.startHandleLayerLink,
///   type: AndroidHandleType.left,
///   color: Theme.of(context).colorScheme.primary,
///   onDragUpdate: (details) => _onHandleDragUpdate(details, isStart: true),
/// )
/// ```
class AndroidSelectionHandle extends StatelessWidget {
  /// Creates an [AndroidSelectionHandle].
  ///
  /// [layerLink] anchors the handle to the selection-start or -end position
  /// via [CompositedTransformFollower]. [type] controls the painted shape.
  /// [color] is the fill colour of the handle.
  ///
  /// [onDragStart], [onDragUpdate], and [onDragEnd] are optional drag
  /// callbacks.
  const AndroidSelectionHandle({
    super.key,
    required this.layerLink,
    required this.type,
    required this.color,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  /// The [LayerLink] that anchors the handle to a selection endpoint.
  final LayerLink layerLink;

  /// The visual variant of this handle.
  final AndroidHandleType type;

  /// The fill colour for the handle shape.
  final Color color;

  /// Called when the user starts dragging this handle.
  final VoidCallback? onDragStart;

  /// Called whenever the user moves this handle.
  final ValueChanged<DragUpdateDetails>? onDragUpdate;

  /// Called when the user releases this handle.
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
        child: _HandlePainterWidget(type: type, color: color),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<AndroidHandleType>('type', type));
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
// _HandlePainterWidget
// ---------------------------------------------------------------------------

/// Internal widget that paints the handle shape via [CustomPaint].
class _HandlePainterWidget extends StatelessWidget {
  const _HandlePainterWidget({required this.type, required this.color});

  final AndroidHandleType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _HandlePainter(type: type, color: color),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<AndroidHandleType>('type', type));
    properties.add(ColorProperty('color', color));
  }
}

// ---------------------------------------------------------------------------
// _HandlePainter
// ---------------------------------------------------------------------------

/// Paints the Android-style teardrop or lollipop handle shape.
///
/// - [AndroidHandleType.left]: a teardrop whose tail points up-right, placed
///   at the bottom-left of a selection line.
/// - [AndroidHandleType.right]: a teardrop whose tail points up-left, placed
///   at the bottom-right of a selection line.
/// - [AndroidHandleType.collapsed]: a filled circle (lollipop head)
///   representing the caret drag handle.
class _HandlePainter extends CustomPainter {
  const _HandlePainter({required this.type, required this.color});

  final AndroidHandleType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case AndroidHandleType.collapsed:
        // Lollipop: filled circle.
        final center = Offset(size.width / 2, size.height / 2);
        canvas.drawCircle(center, size.width / 2 - 1, paint);

      case AndroidHandleType.left:
        // Teardrop with tail pointing up-right (placed at selection start).
        final path = Path()
          ..moveTo(size.width, 0)
          ..lineTo(size.width / 2, 0)
          ..arcToPoint(
            Offset(0, size.height / 2),
            radius: Radius.circular(size.width / 2),
          )
          ..arcToPoint(
            Offset(size.width / 2, size.height),
            radius: Radius.circular(size.width / 2),
          )
          ..lineTo(size.width, size.height)
          ..close();
        canvas.drawPath(path, paint);

      case AndroidHandleType.right:
        // Teardrop with tail pointing up-left (placed at selection end).
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, 0)
          ..arcToPoint(
            Offset(size.width, size.height / 2),
            radius: Radius.circular(size.width / 2),
            clockwise: false,
          )
          ..arcToPoint(
            Offset(size.width / 2, size.height),
            radius: Radius.circular(size.width / 2),
            clockwise: false,
          )
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_HandlePainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
