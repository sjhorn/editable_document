/// [DocumentSemanticsScope] — inherited widget that flows semantics state.
///
/// Provides [isFocused] and [isReadOnly] from [EditableDocument] down to
/// [DocumentLayout] so that render objects can configure their semantics nodes
/// without requiring a direct callback connection.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// DocumentSemanticsScope
// ---------------------------------------------------------------------------

/// An [InheritedWidget] that makes focus and read-only state available to
/// [DocumentLayout] and its descendants.
///
/// [EditableDocument] wraps its [DocumentLayout] child in a
/// [DocumentSemanticsScope] so that the layout render objects can annotate
/// their semantics nodes correctly without a direct reference back to the
/// [EditableDocument] state.
///
/// ## Usage
///
/// Reading the scope from a build method:
///
/// ```dart
/// final scope = DocumentSemanticsScope.maybeOf(context);
/// final isFocused = scope?.isFocused ?? false;
/// final isReadOnly = scope?.isReadOnly ?? false;
/// ```
class DocumentSemanticsScope extends InheritedWidget {
  /// Creates a [DocumentSemanticsScope].
  ///
  /// [isFocused] should reflect whether the enclosing [EditableDocument] (or
  /// its [FocusNode]) currently has input focus.
  ///
  /// [isReadOnly] should reflect [EditableDocument.readOnly].
  const DocumentSemanticsScope({
    super.key,
    required this.isFocused,
    required this.isReadOnly,
    required super.child,
  });

  /// Whether the enclosing [EditableDocument] currently holds input focus.
  ///
  /// When `true` and [isReadOnly] is `false`, descendant render objects should
  /// annotate themselves as focused, editable text fields.
  final bool isFocused;

  /// Whether the enclosing [EditableDocument] is read-only.
  ///
  /// When `true`, descendant render objects should annotate themselves as
  /// read-only so that the accessibility system does not offer editing actions.
  final bool isReadOnly;

  /// Returns the nearest [DocumentSemanticsScope] ancestor, or `null` if none
  /// exists.
  ///
  /// Registers a dependency on the scope so the calling widget rebuilds
  /// whenever [isFocused] or [isReadOnly] changes.
  static DocumentSemanticsScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DocumentSemanticsScope>();
  }

  @override
  bool updateShouldNotify(DocumentSemanticsScope oldWidget) {
    return isFocused != oldWidget.isFocused || isReadOnly != oldWidget.isReadOnly;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('isFocused', isFocused));
    properties.add(DiagnosticsProperty<bool>('isReadOnly', isReadOnly));
  }
}
