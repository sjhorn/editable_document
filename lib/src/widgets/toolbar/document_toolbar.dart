/// Full-featured document toolbar that composes all individual bars.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/document_editing_controller.dart';
import '../../model/edit_request.dart';
import '../../model/undoable_editor.dart';
import '../theme/document_toolbar_theme.dart';
import 'document_alignment_bar.dart';
import 'document_block_type_bar.dart';
import 'document_color_bar.dart';
import 'document_font_bar.dart';
import 'document_formatting_bar.dart';
import 'document_insert_bar.dart';
import 'document_list_indent_bar.dart';
import 'document_undo_redo_bar.dart';

// ---------------------------------------------------------------------------
// DocumentToolbar
// ---------------------------------------------------------------------------

/// A full-featured document toolbar that composes all individual bars.
///
/// Renders a horizontal scrollable row of toolbar groups, separated by
/// vertical dividers. Each group can be hidden via the corresponding `show*`
/// flag.
///
/// Styling is driven by [DocumentToolbarTheme]. If no theme ancestor is
/// present, Material theme defaults are used.
///
/// ```dart
/// DocumentToolbar(
///   controller: controller,
///   requestHandler: editor.submit,
///   editor: undoableEditor,
/// )
/// ```
class DocumentToolbar extends StatelessWidget {
  /// Creates a [DocumentToolbar].
  const DocumentToolbar({
    super.key,
    required this.controller,
    required this.requestHandler,
    this.editor,
    this.showFormatting = true,
    this.showBlockTypes = true,
    this.showAlignment = true,
    this.showInsert = true,
    this.showFont = true,
    this.showColor = true,
    this.showUndoRedo = true,
    this.showIndent = true,
    this.leading,
    this.trailing,
  });

  /// The document editing controller passed to each bar.
  final DocumentEditingController controller;

  /// Request handler passed to each bar.
  final void Function(EditRequest) requestHandler;

  /// The optional [UndoableEditor]. When `null`, [DocumentUndoRedoBar] is
  /// hidden even if [showUndoRedo] is `true`.
  final UndoableEditor? editor;

  /// Whether to show the inline formatting bar (bold, italic, etc.).
  final bool showFormatting;

  /// Whether to show the block type bar (paragraph, blockquote, etc.).
  final bool showBlockTypes;

  /// Whether to show the text alignment bar.
  final bool showAlignment;

  /// Whether to show the insert bar (horizontal rule, image, table).
  final bool showInsert;

  /// Whether to show the font family/size bar.
  final bool showFont;

  /// Whether to show the text/background color bar.
  final bool showColor;

  /// Whether to show the undo/redo bar.
  ///
  /// Has no effect when [editor] is `null`.
  final bool showUndoRedo;

  /// Whether to show the list indent/unindent bar.
  final bool showIndent;

  /// Optional widget rendered at the start of the toolbar (before all groups).
  final Widget? leading;

  /// Optional widget rendered at the end of the toolbar (after all groups).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = DocumentToolbarTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = theme.backgroundColor ?? colorScheme.surfaceContainerLow;
    final borderColor = theme.borderSide?.color ?? colorScheme.outlineVariant;
    final borderWidth = theme.borderSide?.width ?? 1.0;
    final padding = theme.padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final dividerColor = theme.dividerColor ?? colorScheme.outlineVariant;

    Widget divider() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            height: 24,
            child: VerticalDivider(width: 1, color: dividerColor),
          ),
        );

    final groups = <Widget>[
      if (leading != null) ...[leading!, divider()],
      if (showUndoRedo && editor != null) ...[
        DocumentUndoRedoBar(editor: editor!, controller: controller),
        divider(),
      ],
      if (showBlockTypes) ...[
        DocumentBlockTypeBar(controller: controller, requestHandler: requestHandler),
        divider(),
      ],
      if (showInsert) ...[
        DocumentInsertBar(controller: controller, requestHandler: requestHandler),
        divider(),
      ],
      if (showAlignment) ...[
        DocumentAlignmentBar(controller: controller, requestHandler: requestHandler),
        divider(),
      ],
      if (showFormatting) ...[
        DocumentFormattingBar(controller: controller, requestHandler: requestHandler),
        divider(),
      ],
      if (showFont) ...[
        DocumentFontBar(controller: controller, requestHandler: requestHandler),
        divider(),
      ],
      if (showColor) ...[
        DocumentColorBar(controller: controller, requestHandler: requestHandler),
        divider(),
      ],
      if (showIndent) ...[
        DocumentListIndentBar(controller: controller, requestHandler: requestHandler),
      ],
      if (trailing != null) ...[divider(), trailing!],
    ];

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: borderColor, width: borderWidth),
        ),
      ),
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: groups,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DocumentEditingController>('controller', controller),
    );
    properties.add(
      ObjectFlagProperty<void Function(EditRequest)>.has('requestHandler', requestHandler),
    );
    properties.add(DiagnosticsProperty<UndoableEditor>('editor', editor, defaultValue: null));
    properties.add(FlagProperty('showFormatting', value: showFormatting, ifTrue: 'showFormatting'));
    properties.add(FlagProperty('showBlockTypes', value: showBlockTypes, ifTrue: 'showBlockTypes'));
    properties.add(FlagProperty('showAlignment', value: showAlignment, ifTrue: 'showAlignment'));
    properties.add(FlagProperty('showInsert', value: showInsert, ifTrue: 'showInsert'));
    properties.add(FlagProperty('showFont', value: showFont, ifTrue: 'showFont'));
    properties.add(FlagProperty('showColor', value: showColor, ifTrue: 'showColor'));
    properties.add(FlagProperty('showUndoRedo', value: showUndoRedo, ifTrue: 'showUndoRedo'));
    properties.add(FlagProperty('showIndent', value: showIndent, ifTrue: 'showIndent'));
  }
}
