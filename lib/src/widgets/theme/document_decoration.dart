/// Per-field visual configuration for [DocumentField].
///
/// Similar to [InputDecoration] for [TextField], [DocumentDecoration]
/// controls the border, background, and which chrome elements are shown
/// around document content.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// DocumentToolbarPosition
// ---------------------------------------------------------------------------

/// Position of the toolbar relative to the document content.
enum DocumentToolbarPosition {
  /// Toolbar appears above the content.
  top,

  /// Toolbar appears below the content.
  bottom,
}

// ---------------------------------------------------------------------------
// DocumentPanelPosition
// ---------------------------------------------------------------------------

/// Position of the property panel relative to the document content.
enum DocumentPanelPosition {
  /// Panel appears to the start (left in LTR) of the content.
  start,

  /// Panel appears to the end (right in LTR) of the content.
  end,
}

// ---------------------------------------------------------------------------
// DocumentDecoration
// ---------------------------------------------------------------------------

/// Visual configuration for a [DocumentField].
///
/// Similar to [InputDecoration] for [TextField], this class controls
/// the border, background, and which chrome elements are shown around
/// the document content area.
///
/// ```dart
/// DocumentField(
///   controller: controller,
///   decoration: DocumentDecoration(
///     backgroundColor: Colors.white,
///     border: BorderSide(color: Colors.grey),
///     showToolbar: true,
///     showPropertyPanel: true,
///   ),
/// )
/// ```
@immutable
class DocumentDecoration with Diagnosticable {
  /// Creates a [DocumentDecoration].
  const DocumentDecoration({
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.padding,
    this.showToolbar = false,
    this.showPropertyPanel = false,
    this.showStatusBar = false,
    this.toolbarPosition = DocumentToolbarPosition.top,
    this.propertyPanelPosition = DocumentPanelPosition.end,
  });

  /// Background color of the document content area.
  final Color? backgroundColor;

  /// Border drawn around the document content area.
  final BorderSide? border;

  /// Corner radius applied to the document content area border.
  final BorderRadius? borderRadius;

  /// Padding between the document border and the scrollable content.
  final EdgeInsetsGeometry? padding;

  /// Whether to show a [DocumentToolbar] above or below the content.
  ///
  /// The toolbar position is controlled by [toolbarPosition].
  final bool showToolbar;

  /// Whether to show a [DocumentPropertyPanel] beside the content.
  ///
  /// The panel position is controlled by [propertyPanelPosition].
  final bool showPropertyPanel;

  /// Whether to show a [DocumentStatusBar] below the content.
  final bool showStatusBar;

  /// Where the toolbar appears relative to the content.
  ///
  /// Only has effect when [showToolbar] is `true`.
  final DocumentToolbarPosition toolbarPosition;

  /// Where the property panel appears relative to the content.
  ///
  /// Only has effect when [showPropertyPanel] is `true`.
  final DocumentPanelPosition propertyPanelPosition;

  /// Returns a copy of this decoration with the provided fields overridden.
  ///
  /// Fields that are not provided keep their current values.
  DocumentDecoration copyWith({
    Color? backgroundColor,
    BorderSide? border,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    bool? showToolbar,
    bool? showPropertyPanel,
    bool? showStatusBar,
    DocumentToolbarPosition? toolbarPosition,
    DocumentPanelPosition? propertyPanelPosition,
  }) {
    return DocumentDecoration(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      showToolbar: showToolbar ?? this.showToolbar,
      showPropertyPanel: showPropertyPanel ?? this.showPropertyPanel,
      showStatusBar: showStatusBar ?? this.showStatusBar,
      toolbarPosition: toolbarPosition ?? this.toolbarPosition,
      propertyPanelPosition: propertyPanelPosition ?? this.propertyPanelPosition,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentDecoration &&
        other.backgroundColor == backgroundColor &&
        other.border == border &&
        other.borderRadius == borderRadius &&
        other.padding == padding &&
        other.showToolbar == showToolbar &&
        other.showPropertyPanel == showPropertyPanel &&
        other.showStatusBar == showStatusBar &&
        other.toolbarPosition == toolbarPosition &&
        other.propertyPanelPosition == propertyPanelPosition;
  }

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        border,
        borderRadius,
        padding,
        showToolbar,
        showPropertyPanel,
        showStatusBar,
        toolbarPosition,
        propertyPanelPosition,
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<BorderSide>('border', border, defaultValue: null));
    properties.add(
      DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius, defaultValue: null),
    );
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding, defaultValue: null));
    properties.add(
      FlagProperty('showToolbar', value: showToolbar, ifTrue: 'showToolbar', defaultValue: false),
    );
    properties.add(
      FlagProperty(
        'showPropertyPanel',
        value: showPropertyPanel,
        ifTrue: 'showPropertyPanel',
        defaultValue: false,
      ),
    );
    properties.add(
      FlagProperty(
        'showStatusBar',
        value: showStatusBar,
        ifTrue: 'showStatusBar',
        defaultValue: false,
      ),
    );
    properties.add(
      EnumProperty<DocumentToolbarPosition>(
        'toolbarPosition',
        toolbarPosition,
        defaultValue: DocumentToolbarPosition.top,
      ),
    );
    properties.add(
      EnumProperty<DocumentPanelPosition>(
        'propertyPanelPosition',
        propertyPanelPosition,
        defaultValue: DocumentPanelPosition.end,
      ),
    );
  }
}
