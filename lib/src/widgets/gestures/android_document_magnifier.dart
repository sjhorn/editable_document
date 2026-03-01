/// Android-style document magnifier for the editable_document package.
///
/// [AndroidDocumentMagnifier] renders an Android-style rectangular magnifier
/// that follows the user's finger during a long-press or handle-drag. For
/// Phase 6.5 this is implemented as a styled container; full pixel-level
/// magnification can be added in a later phase when Flutter's
/// `RawMagnifier` API is wired in.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AndroidDocumentMagnifier
// ---------------------------------------------------------------------------

/// An Android-style rectangular magnifier widget.
///
/// Displayed during long-press and handle-drag gestures to help the user
/// precisely position the caret or selection handles. Position the widget
/// using a [Positioned] widget inside a [Stack], centred above the
/// [focalPoint] in document-layout coordinates.
///
/// The default [size] and [magnification] match Android's stock text
/// magnifier dimensions.
///
/// ```dart
/// // Typically rendered by AndroidDocumentGestureController:
/// AndroidDocumentMagnifier(
///   focalPoint: currentDragOffset,
///   magnification: 1.25,
/// )
/// ```
class AndroidDocumentMagnifier extends StatelessWidget {
  /// Creates an [AndroidDocumentMagnifier].
  ///
  /// [focalPoint] is the document-layout offset that the magnifier is
  /// nominally centered on (used by the parent [Stack] for positioning).
  /// [magnification] scales the content inside the magnifier (default `1.25`).
  /// [size] is the rendered size of the magnifier widget (default
  /// `Size(100, 48)`).
  const AndroidDocumentMagnifier({
    super.key,
    required this.focalPoint,
    this.magnification = 1.25,
    this.size = const Size(100, 48),
  });

  /// The document-layout offset that this magnifier is centered on.
  ///
  /// The gesture controller uses this value to compute the [Positioned]
  /// offsets when placing the magnifier inside the document [Stack].
  final Offset focalPoint;

  /// The scale factor applied to the content inside the magnifier.
  ///
  /// Defaults to `1.25`.
  final double magnification;

  /// The rendered size of the magnifier widget.
  ///
  /// Defaults to `Size(100, 48)`, matching Android's stock magnifier.
  final Size size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: _MagnifierContainer(size: size, magnification: magnification),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('focalPoint', focalPoint));
    properties.add(DoubleProperty('magnification', magnification));
    properties.add(DiagnosticsProperty<Size>('size', size));
  }
}

// ---------------------------------------------------------------------------
// _MagnifierContainer
// ---------------------------------------------------------------------------

/// Internal styled container that represents the magnifier chrome.
///
/// In Phase 6.5 this renders a rounded-rectangle with a border and shadow
/// to simulate the Android magnifier appearance. Full `RawMagnifier`-based
/// pixel magnification is deferred to a later phase.
class _MagnifierContainer extends StatelessWidget {
  const _MagnifierContainer({
    required this.size,
    required this.magnification,
  });

  final Size size;
  final double magnification;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFBBBBBB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'x${magnification.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Size>('size', size));
    properties.add(DoubleProperty('magnification', magnification));
  }
}
