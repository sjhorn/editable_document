/// [DocumentViewportScope] — InheritedWidget that carries viewport dimensions.
///
/// Placed in its own file to avoid circular imports between
/// [DocumentScrollable] (which creates the scope) and [DocumentLayout]
/// (which reads from it).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// DocumentViewportScope
// ---------------------------------------------------------------------------

/// An [InheritedWidget] that provides the viewport dimensions to descendant
/// [DocumentLayout] widgets.
///
/// When a [DocumentScrollable] wraps content in a horizontal
/// [SingleChildScrollView], the incoming `maxWidth` constraint becomes
/// `double.infinity`. Stretch blocks (paragraphs) need to know the actual
/// viewport width so they fill the visible area rather than expanding to
/// infinity. [DocumentViewportScope] carries that width down the tree.
///
/// Similarly, [viewportHeight] is provided so that blocks using
/// [BlockDimension.percent] height dimensions can resolve to logical pixels
/// relative to the visible viewport height.
///
/// Use [maybeOf] to read the viewport width and [maybeHeightOf] to read the
/// viewport height from within a [DocumentLayout]:
///
/// ```dart
/// final vpWidth = DocumentViewportScope.maybeOf(context);
/// final vpHeight = DocumentViewportScope.maybeHeightOf(context);
/// ```
class DocumentViewportScope extends InheritedWidget {
  /// Creates a [DocumentViewportScope] with the given [viewportWidth] and
  /// [viewportHeight].
  const DocumentViewportScope({
    super.key,
    required this.viewportWidth,
    required this.viewportHeight,
    required super.child,
  });

  /// The width of the visible viewport in logical pixels.
  final double viewportWidth;

  /// The height of the visible viewport in logical pixels.
  final double viewportHeight;

  /// Returns the [viewportWidth] from the nearest [DocumentViewportScope]
  /// ancestor, or `null` if none exists.
  static double? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DocumentViewportScope>()?.viewportWidth;
  }

  /// Returns the [viewportHeight] from the nearest [DocumentViewportScope]
  /// ancestor, or `null` if none exists.
  static double? maybeHeightOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DocumentViewportScope>()?.viewportHeight;
  }

  @override
  bool updateShouldNotify(DocumentViewportScope oldWidget) {
    return viewportWidth != oldWidget.viewportWidth || viewportHeight != oldWidget.viewportHeight;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('viewportWidth', viewportWidth));
    properties.add(DoubleProperty('viewportHeight', viewportHeight));
  }
}
