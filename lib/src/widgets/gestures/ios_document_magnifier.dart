/// iOS-style document magnifier for the editable_document package.
///
/// [IOSDocumentMagnifier] is a circular magnifier overlay that appears
/// during long-press and handle drag gestures on iOS, showing the area
/// around the insertion point or handle position.
///
/// For Phase 6.4 the magnifier is implemented as a styled circular container
/// that indicates magnifier presence. Full pixel-accurate magnification via
/// [BackdropFilter] is deferred to a later phase.
///
/// The widget does **not** position itself — callers should wrap it in a
/// [Positioned] (inside a [Stack]) or use [Overlay] to place it above the
/// document content.
///
/// Typical usage inside a [Stack]:
/// ```dart
/// if (_showMagnifier)
///   Positioned(
///     left: _focalPoint.dx - 40,
///     top: _focalPoint.dy - 88,
///     child: IOSDocumentMagnifier(
///       focalPoint: _focalPoint,
///     ),
///   )
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// IOSDocumentMagnifier
// ---------------------------------------------------------------------------

/// A circular magnifier overlay widget for iOS long-press and handle drags.
///
/// Shown on iOS during long-press and handle-drag gestures. The widget
/// renders a [diameter]-pixel circle with a [magnification]-scaled content
/// indicator.
///
/// The parent is responsible for positioning this widget (e.g. using
/// [Positioned] inside a [Stack] or an [Overlay] entry).
///
/// ```dart
/// IOSDocumentMagnifier(
///   focalPoint: Offset(100, 200),
///   magnification: 1.5,
///   diameter: 80,
/// )
/// ```
class IOSDocumentMagnifier extends StatelessWidget {
  /// Creates an [IOSDocumentMagnifier].
  ///
  /// [focalPoint] is the global/local offset that the magnifier is logically
  /// centred on; it is stored as a property but this widget does not perform
  /// self-positioning — the parent must do that.
  /// [magnification] scales the magnified content (default `1.5`).
  /// [diameter] is the diameter of the circular magnifier in logical pixels
  /// (default `80.0`).
  const IOSDocumentMagnifier({
    super.key,
    required this.focalPoint,
    this.magnification = 1.5,
    this.diameter = 80.0,
  });

  /// The logical focal point (in the parent coordinate space) that this
  /// magnifier should be centred over.
  ///
  /// This is stored for parent widgets to read; the magnifier widget itself
  /// does not use it for self-positioning.
  final Offset focalPoint;

  /// The magnification factor applied to the content under the magnifier.
  ///
  /// Defaults to `1.5`.
  final double magnification;

  /// The diameter of the circular magnifier window in logical pixels.
  ///
  /// Defaults to `80.0`.
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Center(
            child: Transform.scale(
              scale: magnification,
              child: SizedBox(
                width: diameter,
                height: diameter,
                child: CustomPaint(
                  painter: _MagnifierLensPainter(
                    color: theme.colorScheme.primary.withAlpha(30),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('focalPoint', focalPoint));
    properties.add(DoubleProperty('magnification', magnification));
    properties.add(DoubleProperty('diameter', diameter));
  }
}

// ---------------------------------------------------------------------------
// _MagnifierLensPainter
// ---------------------------------------------------------------------------

/// Paints a subtle lens effect inside the magnifier circle.
///
/// Draws a filled circle with a semi-transparent [color] to indicate the
/// magnifier's lens area.
class _MagnifierLensPainter extends CustomPainter {
  /// Creates a [_MagnifierLensPainter] with the given [color].
  const _MagnifierLensPainter({required this.color});

  /// The tint colour of the lens area.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(_MagnifierLensPainter oldDelegate) => oldDelegate.color != color;
}
