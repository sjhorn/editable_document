/// [SliverEditableDocument] — a sliver wrapper for [EditableDocument].
///
/// Embeds an [EditableDocument] inside a [SliverToBoxAdapter] so that it can
/// participate in a [CustomScrollView] alongside other slivers without nested
/// scroll conflicts.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/document_editing_controller.dart';
import '../model/document_selection.dart';
import '../model/editor.dart';
import 'component_builder.dart';
import 'document_layout.dart';
import 'editable_document.dart';

// ---------------------------------------------------------------------------
// SliverEditableDocument
// ---------------------------------------------------------------------------

/// A sliver that wraps [EditableDocument] in a [SliverToBoxAdapter].
///
/// Use [SliverEditableDocument] to embed an editable block document in a
/// [CustomScrollView] alongside other slivers — for example between a
/// [SliverAppBar] and a [SliverList] — without creating nested scroll
/// conflicts.
///
/// All parameters mirror [EditableDocument] exactly and are forwarded
/// unchanged to the inner [EditableDocument].
///
/// ## Minimal usage
///
/// ```dart
/// CustomScrollView(
///   slivers: [
///     const SliverAppBar(title: Text('My Document')),
///     SliverEditableDocument(
///       controller: controller,
///       focusNode: focusNode,
///     ),
///   ],
/// )
/// ```
class SliverEditableDocument extends StatelessWidget {
  /// Creates a [SliverEditableDocument].
  ///
  /// [controller] and [focusNode] are required. All other parameters have
  /// the same defaults as [EditableDocument].
  const SliverEditableDocument({
    super.key,
    required this.controller,
    required this.focusNode,
    this.layoutKey,
    this.style,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.readOnly = false,
    this.autofocus = false,
    this.textInputAction = TextInputAction.newline,
    this.keyboardType = TextInputType.multiline,
    this.onChanged,
    this.onSelectionChanged,
    this.componentBuilders,
    this.blockSpacing = 12.0,
    this.stylesheet,
    this.editor,
    this.scrollPadding = const EdgeInsets.all(20.0),
  });

  /// The document editing controller holding the [MutableDocument] and current
  /// [DocumentSelection].
  final DocumentEditingController controller;

  /// The focus node used to manage keyboard focus for the inner
  /// [EditableDocument].
  ///
  /// The caller owns the [FocusNode]; the inner [EditableDocument] registers
  /// and unregisters listeners but never disposes it.
  final FocusNode focusNode;

  /// An optional [GlobalKey] forwarded to the inner [EditableDocument]'s
  /// [DocumentLayout].
  ///
  /// When provided, external code can use [DocumentLayoutState] to query
  /// geometry. When `null`, [EditableDocument] manages its own internal key.
  final GlobalKey<DocumentLayoutState>? layoutKey;

  /// The base [TextStyle] applied to text blocks.
  ///
  /// Forwarded to [EditableDocument.style].
  final TextStyle? style;

  /// The text directionality for block layout.
  ///
  /// When `null`, the ambient [Directionality] is used.
  final TextDirection? textDirection;

  /// The text alignment applied to paragraph blocks.
  ///
  /// Defaults to [TextAlign.start].
  final TextAlign textAlign;

  /// Whether the document is read-only.
  ///
  /// When `true`, the IME connection is not opened on focus and keyboard
  /// events are not forwarded. Defaults to `false`.
  final bool readOnly;

  /// Whether the inner [EditableDocument] should receive focus automatically
  /// when the widget tree is built.
  ///
  /// Defaults to `false`.
  final bool autofocus;

  /// The keyboard action button label shown by the soft keyboard.
  ///
  /// Defaults to [TextInputAction.newline].
  final TextInputAction textInputAction;

  /// The type of keyboard to use for the inner [EditableDocument].
  ///
  /// Defaults to [TextInputType.multiline].
  final TextInputType keyboardType;

  /// Called when the document content changes.
  ///
  /// Forwarded to [EditableDocument.onChanged].
  final ValueChanged<String>? onChanged;

  /// Called whenever the document selection changes.
  ///
  /// Receives the new [DocumentSelection], or `null` when the selection is
  /// cleared. Forwarded to [EditableDocument.onSelectionChanged].
  final ValueChanged<DocumentSelection?>? onSelectionChanged;

  /// The ordered list of [ComponentBuilder]s used to render block nodes.
  ///
  /// When `null`, [defaultComponentBuilders] is used. Prepend custom builders
  /// to override defaults for specific node types.
  final List<ComponentBuilder>? componentBuilders;

  /// The vertical gap in logical pixels between consecutive block children.
  ///
  /// Defaults to `12.0`.
  final double blockSpacing;

  /// An optional map of style-key strings to [TextStyle]s.
  ///
  /// Forwarded to [EditableDocument.stylesheet].
  final Map<String, TextStyle>? stylesheet;

  /// An optional [Editor] used to route [EditRequest]s through the command
  /// pipeline.
  ///
  /// Forwarded to [EditableDocument.editor].
  final Editor? editor;

  /// Padding around the caret to ensure it is not flush against the viewport
  /// edge after auto-scrolling.
  ///
  /// Defaults to `EdgeInsets.all(20.0)`, matching [EditableDocument.scrollPadding].
  final EdgeInsets scrollPadding;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: EditableDocument(
        controller: controller,
        focusNode: focusNode,
        layoutKey: layoutKey,
        style: style,
        textDirection: textDirection,
        textAlign: textAlign,
        readOnly: readOnly,
        autofocus: autofocus,
        textInputAction: textInputAction,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onSelectionChanged: onSelectionChanged,
        componentBuilders: componentBuilders,
        blockSpacing: blockSpacing,
        stylesheet: stylesheet,
        editor: editor,
        scrollPadding: scrollPadding,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DocumentEditingController>('controller', controller));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode));
    properties.add(DiagnosticsProperty<TextStyle?>('style', style, defaultValue: null));
    properties.add(
      EnumProperty<TextDirection?>('textDirection', textDirection, defaultValue: null),
    );
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign));
    properties.add(FlagProperty('readOnly', value: readOnly, ifTrue: 'readOnly'));
    properties.add(FlagProperty('autofocus', value: autofocus, ifTrue: 'autofocus'));
    properties.add(EnumProperty<TextInputAction>('textInputAction', textInputAction));
    properties.add(DiagnosticsProperty<TextInputType>('keyboardType', keyboardType));
    properties.add(
      ObjectFlagProperty<ValueChanged<String>?>.has('onChanged', onChanged),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<DocumentSelection?>?>.has(
        'onSelectionChanged',
        onSelectionChanged,
      ),
    );
    properties.add(
      DiagnosticsProperty<List<ComponentBuilder>?>(
        'componentBuilders',
        componentBuilders,
        defaultValue: null,
      ),
    );
    properties.add(DoubleProperty('blockSpacing', blockSpacing));
    properties.add(
      DiagnosticsProperty<Map<String, TextStyle>?>('stylesheet', stylesheet, defaultValue: null),
    );
    properties.add(DiagnosticsProperty<Editor?>('editor', editor, defaultValue: null));
    properties.add(
      DiagnosticsProperty<GlobalKey<DocumentLayoutState>?>('layoutKey', layoutKey),
    );
    properties.add(DiagnosticsProperty<EdgeInsets>('scrollPadding', scrollPadding));
  }
}
