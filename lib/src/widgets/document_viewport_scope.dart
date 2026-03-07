/// [DocumentViewportScope] — InheritedWidget that carries viewport width.
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

/// An [InheritedWidget] that provides the viewport width to descendant
/// [DocumentLayout] widgets.
///
/// When a [DocumentScrollable] wraps content in a horizontal
/// [SingleChildScrollView], the incoming `maxWidth` constraint becomes
/// `double.infinity`. Stretch blocks (paragraphs) need to know the actual
/// viewport width so they fill the visible area rather than expanding to
/// infinity. [DocumentViewportScope] carries that width down the tree.
///
/// Use [maybeOf] to read the viewport width from within a [DocumentLayout]:
///
/// ```dart
/// final vpWidth = DocumentViewportScope.maybeOf(context);
/// ```
class DocumentViewportScope extends InheritedWidget {
  /// Creates a [DocumentViewportScope] with the given [viewportWidth].
  const DocumentViewportScope({
    super.key,
    required this.viewportWidth,
    required super.child,
  });

  /// The width of the visible viewport in logical pixels.
  final double viewportWidth;

  /// Returns the [viewportWidth] from the nearest [DocumentViewportScope]
  /// ancestor, or `null` if none exists.
  static double? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DocumentViewportScope>()?.viewportWidth;
  }

  @override
  bool updateShouldNotify(DocumentViewportScope oldWidget) {
    return viewportWidth != oldWidget.viewportWidth;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('viewportWidth', viewportWidth));
  }
}
