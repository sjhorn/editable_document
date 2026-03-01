/// ComponentBuilder abstraction for the editable_document widget layer.
///
/// This file defines the bridge between document nodes ([DocumentNode]) and
/// their widget representations. The three key types are:
///
/// - [ComponentViewModel] — an immutable data object describing how to render
///   a single document block.
/// - [ComponentContext] — context passed to [ComponentBuilder.createComponent]
///   containing the document, current selection, and optional stylesheet.
/// - [ComponentBuilder] — abstract factory that converts a [DocumentNode] into
///   a [ComponentViewModel] and a [ComponentViewModel] into a [Widget].
///
/// The five default builders are available via [defaultComponentBuilders].
/// Use [resolveViewModel] to try builders in order and return the first
/// non-null result.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../model/attributed_text.dart';
import '../model/code_block_node.dart';
import '../model/document.dart';
import '../model/document_node.dart';
import '../model/document_selection.dart';
import '../model/horizontal_rule_node.dart';
import '../model/image_node.dart';
import '../model/list_item_node.dart';
import '../model/paragraph_node.dart';
import '../rendering/render_code_block.dart';
import '../rendering/render_horizontal_rule_block.dart';
import '../rendering/render_image_block.dart';
import '../rendering/render_list_item_block.dart';
import '../rendering/render_paragraph_block.dart';

// ---------------------------------------------------------------------------
// ComponentViewModel
// ---------------------------------------------------------------------------

/// Immutable data object that describes how to render a single document block.
///
/// Each [ComponentBuilder] produces a typed subclass of [ComponentViewModel]
/// from a [DocumentNode]. The document layout system compares old and new view
/// models to decide whether to rebuild or skip rebuilding a component.
///
/// Subclasses must implement [==] and [hashCode] so diffing works correctly.
abstract class ComponentViewModel {
  /// Creates a [ComponentViewModel] for the node with [nodeId].
  ///
  /// [nodeSelection] is the portion of the document selection that intersects
  /// this block, or `null` when there is no active selection in this block.
  /// [isSelected] is a convenience flag set to `true` when [nodeSelection] is
  /// non-null and covers the whole block.
  const ComponentViewModel({
    required this.nodeId,
    this.nodeSelection,
    this.isSelected = false,
  });

  /// The unique identifier of the document node this view model represents.
  final String nodeId;

  /// The portion of the document selection that intersects this block,
  /// or `null` when no selection is active in this block.
  final DocumentSelection? nodeSelection;

  /// Whether this block is fully selected.
  ///
  /// This is a convenience flag; the selection painter uses [nodeSelection]
  /// for precise highlight geometry.
  final bool isSelected;
}

// ---------------------------------------------------------------------------
// ComponentContext
// ---------------------------------------------------------------------------

/// Context object passed to [ComponentBuilder.createComponent].
///
/// Provides read access to the [Document], the current [DocumentSelection],
/// and an optional [stylesheet] mapping style keys to [TextStyle]s.
class ComponentContext {
  /// Creates a [ComponentContext].
  ///
  /// [document] and [selection] are the current document state.
  /// [stylesheet] is an optional map of style keys to [TextStyle]s.
  const ComponentContext({
    required this.document,
    required this.selection,
    required this.stylesheet,
  });

  /// The document being rendered.
  final Document document;

  /// The current document-level selection, or `null` when nothing is selected.
  final DocumentSelection? selection;

  /// An optional map of style-key strings to [TextStyle]s.
  ///
  /// Component builders may look up keys such as `'body'`, `'h1'`, or
  /// `'code'` to apply consistent typography across the document.
  final Map<String, TextStyle>? stylesheet;
}

// ---------------------------------------------------------------------------
// ComponentBuilder
// ---------------------------------------------------------------------------

/// Abstract factory that converts [DocumentNode]s into widgets.
///
/// Builders are tried in order; the first one that returns a non-null result
/// for [createViewModel] (or [createComponent]) wins. Apps can prepend custom
/// builders to [defaultComponentBuilders] to override defaults.
///
/// ```dart
/// final builders = [MyCustomBuilder(), ...defaultComponentBuilders];
/// ```
abstract class ComponentBuilder {
  /// Const constructor so subclasses can be `const`.
  const ComponentBuilder();

  /// Returns a [ComponentViewModel] for [node], or `null` if this builder
  /// does not handle [node]'s type.
  ///
  /// Called once per node per build cycle. Return `null` to pass the node
  /// on to the next builder in the list.
  ComponentViewModel? createViewModel(Document document, DocumentNode node);

  /// Returns a [Widget] for [viewModel], or `null` if this builder does not
  /// handle [viewModel]'s type.
  ///
  /// Called immediately after [createViewModel] returns a non-null result.
  /// Return `null` to pass the view model on to the next builder in the list
  /// (unusual, but supported).
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context);
}

// ---------------------------------------------------------------------------
// resolveViewModel — convenience helper
// ---------------------------------------------------------------------------

/// Tries each builder in [builders] in order and returns the first non-null
/// [ComponentViewModel] produced for [node], or `null` if no builder
/// handles the node type.
ComponentViewModel? resolveViewModel(
  List<ComponentBuilder> builders,
  Document document,
  DocumentNode node,
) {
  for (final builder in builders) {
    final vm = builder.createViewModel(document, node);
    if (vm != null) return vm;
  }
  return null;
}

// ---------------------------------------------------------------------------
// defaultComponentBuilders
// ---------------------------------------------------------------------------

/// The ordered list of default component builders.
///
/// Builders are tried in this order:
/// 1. [ParagraphComponentBuilder]
/// 2. [ListItemComponentBuilder]
/// 3. [ImageComponentBuilder]
/// 4. [CodeBlockComponentBuilder]
/// 5. [HorizontalRuleComponentBuilder]
///
/// Prepend custom builders to override defaults for specific node types.
const List<ComponentBuilder> defaultComponentBuilders = [
  ParagraphComponentBuilder(),
  ListItemComponentBuilder(),
  ImageComponentBuilder(),
  CodeBlockComponentBuilder(),
  HorizontalRuleComponentBuilder(),
];

// ===========================================================================
// ParagraphComponentBuilder
// ===========================================================================

/// [ComponentViewModel] for [ParagraphNode].
class ParagraphComponentViewModel extends ComponentViewModel {
  /// Creates a [ParagraphComponentViewModel].
  const ParagraphComponentViewModel({
    required super.nodeId,
    required this.text,
    required this.blockType,
    required this.textStyle,
    super.nodeSelection,
    super.isSelected,
  });

  /// The text content of the paragraph.
  final AttributedText text;

  /// The semantic block type (heading level, blockquote, etc.).
  final ParagraphBlockType blockType;

  /// The base [TextStyle] to apply before block-type scaling.
  final TextStyle textStyle;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParagraphComponentViewModel &&
        other.nodeId == nodeId &&
        other.text == text &&
        other.blockType == blockType &&
        other.textStyle == textStyle &&
        other.nodeSelection == nodeSelection &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(nodeId, text, blockType, textStyle, nodeSelection, isSelected);
}

/// [ComponentBuilder] that handles [ParagraphNode].
class ParagraphComponentBuilder extends ComponentBuilder {
  /// Creates a const [ParagraphComponentBuilder].
  const ParagraphComponentBuilder();

  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode) return null;
    return ParagraphComponentViewModel(
      nodeId: node.id,
      text: node.text,
      blockType: node.blockType,
      textStyle: const TextStyle(),
    );
  }

  @override
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context) {
    if (viewModel is! ParagraphComponentViewModel) return null;
    return _ParagraphBlockWidget(viewModel: viewModel);
  }
}

/// [LeafRenderObjectWidget] that wraps [RenderParagraphBlock].
class _ParagraphBlockWidget extends LeafRenderObjectWidget {
  const _ParagraphBlockWidget({required this.viewModel});

  final ParagraphComponentViewModel viewModel;

  @override
  RenderParagraphBlock createRenderObject(BuildContext context) {
    return RenderParagraphBlock(
      nodeId: viewModel.nodeId,
      text: viewModel.text,
      blockType: viewModel.blockType,
      baseTextStyle: DefaultTextStyle.of(context).style.merge(viewModel.textStyle),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderParagraphBlock renderObject) {
    renderObject
      ..nodeId = viewModel.nodeId
      ..text = viewModel.text
      ..blockType = viewModel.blockType
      ..baseTextStyle = DefaultTextStyle.of(context).style.merge(viewModel.textStyle)
      ..nodeSelection = viewModel.nodeSelection;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ParagraphComponentViewModel>('viewModel', viewModel));
  }
}

// ===========================================================================
// ListItemComponentBuilder
// ===========================================================================

/// [ComponentViewModel] for [ListItemNode].
class ListItemComponentViewModel extends ComponentViewModel {
  /// Creates a [ListItemComponentViewModel].
  const ListItemComponentViewModel({
    required super.nodeId,
    required this.text,
    required this.type,
    required this.indent,
    required this.ordinalIndex,
    required this.textStyle,
    super.nodeSelection,
    super.isSelected,
  });

  /// The text content of the list item.
  final AttributedText text;

  /// Whether this is an ordered or unordered list item.
  final ListItemType type;

  /// The nesting depth (0 = top level).
  final int indent;

  /// The 1-based position within a run of ordered items at the same indent.
  final int ordinalIndex;

  /// The base [TextStyle] to apply.
  final TextStyle textStyle;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListItemComponentViewModel &&
        other.nodeId == nodeId &&
        other.text == text &&
        other.type == type &&
        other.indent == indent &&
        other.ordinalIndex == ordinalIndex &&
        other.textStyle == textStyle &&
        other.nodeSelection == nodeSelection &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode =>
      Object.hash(nodeId, text, type, indent, ordinalIndex, textStyle, nodeSelection, isSelected);
}

/// [ComponentBuilder] that handles [ListItemNode].
class ListItemComponentBuilder extends ComponentBuilder {
  /// Creates a const [ListItemComponentBuilder].
  const ListItemComponentBuilder();

  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ListItemNode) return null;
    final ordinal = _computeOrdinal(document, node);
    return ListItemComponentViewModel(
      nodeId: node.id,
      text: node.text,
      type: node.type,
      indent: node.indent,
      ordinalIndex: ordinal,
      textStyle: const TextStyle(),
    );
  }

  /// Computes the 1-based ordinal index for [node] within a run of ordered
  /// list items at the same indent level. Resets to 1 after any non-list-item
  /// node or after a list item at a different indent level.
  int _computeOrdinal(Document document, ListItemNode node) {
    if (node.type != ListItemType.ordered) return 1;
    var count = 1;
    for (final n in document.nodes) {
      if (n.id == node.id) break;
      if (n is ListItemNode && n.type == ListItemType.ordered && n.indent == node.indent) {
        count++;
      } else if (n is! ListItemNode) {
        // A non-list node resets the run.
        count = 1;
      }
    }
    return count;
  }

  @override
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context) {
    if (viewModel is! ListItemComponentViewModel) return null;
    return _ListItemBlockWidget(viewModel: viewModel);
  }
}

/// [LeafRenderObjectWidget] that wraps [RenderListItemBlock].
class _ListItemBlockWidget extends LeafRenderObjectWidget {
  const _ListItemBlockWidget({required this.viewModel});

  final ListItemComponentViewModel viewModel;

  @override
  RenderListItemBlock createRenderObject(BuildContext context) {
    return RenderListItemBlock(
      nodeId: viewModel.nodeId,
      text: viewModel.text,
      type: viewModel.type,
      indent: viewModel.indent,
      ordinalIndex: viewModel.ordinalIndex,
      textStyle: DefaultTextStyle.of(context).style.merge(viewModel.textStyle),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderListItemBlock renderObject) {
    renderObject
      ..nodeId = viewModel.nodeId
      ..text = viewModel.text
      ..type = viewModel.type
      ..indent = viewModel.indent
      ..ordinalIndex = viewModel.ordinalIndex
      ..textStyle = DefaultTextStyle.of(context).style.merge(viewModel.textStyle)
      ..nodeSelection = viewModel.nodeSelection;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ListItemComponentViewModel>('viewModel', viewModel));
  }
}

// ===========================================================================
// ImageComponentBuilder
// ===========================================================================

/// [ComponentViewModel] for [ImageNode].
class ImageComponentViewModel extends ComponentViewModel {
  /// Creates an [ImageComponentViewModel].
  const ImageComponentViewModel({
    required super.nodeId,
    required this.imageUrl,
    this.altText,
    this.imageWidth,
    this.imageHeight,
    super.nodeSelection,
    super.isSelected,
  });

  /// The URL of the image.
  final String imageUrl;

  /// Accessible description of the image, or `null`.
  final String? altText;

  /// Preferred display width in logical pixels, or `null`.
  final double? imageWidth;

  /// Preferred display height in logical pixels, or `null`.
  final double? imageHeight;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageComponentViewModel &&
        other.nodeId == nodeId &&
        other.imageUrl == imageUrl &&
        other.altText == altText &&
        other.imageWidth == imageWidth &&
        other.imageHeight == imageHeight &&
        other.nodeSelection == nodeSelection &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode =>
      Object.hash(nodeId, imageUrl, altText, imageWidth, imageHeight, nodeSelection, isSelected);
}

/// [ComponentBuilder] that handles [ImageNode].
class ImageComponentBuilder extends ComponentBuilder {
  /// Creates a const [ImageComponentBuilder].
  const ImageComponentBuilder();

  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ImageNode) return null;
    return ImageComponentViewModel(
      nodeId: node.id,
      imageUrl: node.imageUrl,
      altText: node.altText,
      imageWidth: node.width,
      imageHeight: node.height,
    );
  }

  @override
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context) {
    if (viewModel is! ImageComponentViewModel) return null;
    return _ImageBlockWidget(viewModel: viewModel);
  }
}

/// [LeafRenderObjectWidget] that wraps [RenderImageBlock].
class _ImageBlockWidget extends LeafRenderObjectWidget {
  const _ImageBlockWidget({required this.viewModel});

  final ImageComponentViewModel viewModel;

  @override
  RenderImageBlock createRenderObject(BuildContext context) {
    return RenderImageBlock(
      nodeId: viewModel.nodeId,
      imageWidth: viewModel.imageWidth,
      imageHeight: viewModel.imageHeight,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderImageBlock renderObject) {
    renderObject
      ..nodeId = viewModel.nodeId
      ..imageWidth = viewModel.imageWidth
      ..imageHeight = viewModel.imageHeight
      ..nodeSelection = viewModel.nodeSelection;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ImageComponentViewModel>('viewModel', viewModel));
  }
}

// ===========================================================================
// CodeBlockComponentBuilder
// ===========================================================================

/// [ComponentViewModel] for [CodeBlockNode].
class CodeBlockComponentViewModel extends ComponentViewModel {
  /// Creates a [CodeBlockComponentViewModel].
  const CodeBlockComponentViewModel({
    required super.nodeId,
    required this.text,
    required this.textStyle,
    this.language,
    super.nodeSelection,
    super.isSelected,
  });

  /// The source code text.
  final AttributedText text;

  /// The base [TextStyle] (font family will be overridden to monospace).
  final TextStyle textStyle;

  /// The programming language identifier for syntax highlighting, or `null`.
  final String? language;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CodeBlockComponentViewModel &&
        other.nodeId == nodeId &&
        other.text == text &&
        other.textStyle == textStyle &&
        other.language == language &&
        other.nodeSelection == nodeSelection &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(nodeId, text, textStyle, language, nodeSelection, isSelected);
}

/// [ComponentBuilder] that handles [CodeBlockNode].
class CodeBlockComponentBuilder extends ComponentBuilder {
  /// Creates a const [CodeBlockComponentBuilder].
  const CodeBlockComponentBuilder();

  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! CodeBlockNode) return null;
    return CodeBlockComponentViewModel(
      nodeId: node.id,
      text: node.text,
      textStyle: const TextStyle(),
      language: node.language,
    );
  }

  @override
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context) {
    if (viewModel is! CodeBlockComponentViewModel) return null;
    return _CodeBlockWidget(viewModel: viewModel);
  }
}

/// [LeafRenderObjectWidget] that wraps [RenderCodeBlock].
class _CodeBlockWidget extends LeafRenderObjectWidget {
  const _CodeBlockWidget({required this.viewModel});

  final CodeBlockComponentViewModel viewModel;

  @override
  RenderCodeBlock createRenderObject(BuildContext context) {
    return RenderCodeBlock(
      nodeId: viewModel.nodeId,
      text: viewModel.text,
      baseTextStyle: DefaultTextStyle.of(context).style.merge(viewModel.textStyle),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderCodeBlock renderObject) {
    renderObject
      ..nodeId = viewModel.nodeId
      ..text = viewModel.text
      ..nodeSelection = viewModel.nodeSelection;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CodeBlockComponentViewModel>('viewModel', viewModel));
  }
}

// ===========================================================================
// HorizontalRuleComponentBuilder
// ===========================================================================

/// [ComponentViewModel] for [HorizontalRuleNode].
class HorizontalRuleComponentViewModel extends ComponentViewModel {
  /// Creates a [HorizontalRuleComponentViewModel].
  const HorizontalRuleComponentViewModel({
    required super.nodeId,
    super.nodeSelection,
    super.isSelected,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HorizontalRuleComponentViewModel &&
        other.nodeId == nodeId &&
        other.nodeSelection == nodeSelection &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(nodeId, nodeSelection, isSelected);
}

/// [ComponentBuilder] that handles [HorizontalRuleNode].
class HorizontalRuleComponentBuilder extends ComponentBuilder {
  /// Creates a const [HorizontalRuleComponentBuilder].
  const HorizontalRuleComponentBuilder();

  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! HorizontalRuleNode) return null;
    return HorizontalRuleComponentViewModel(nodeId: node.id);
  }

  @override
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context) {
    if (viewModel is! HorizontalRuleComponentViewModel) return null;
    return _HorizontalRuleBlockWidget(viewModel: viewModel);
  }
}

/// [LeafRenderObjectWidget] that wraps [RenderHorizontalRuleBlock].
class _HorizontalRuleBlockWidget extends LeafRenderObjectWidget {
  const _HorizontalRuleBlockWidget({required this.viewModel});

  final HorizontalRuleComponentViewModel viewModel;

  @override
  RenderHorizontalRuleBlock createRenderObject(BuildContext context) {
    return RenderHorizontalRuleBlock(nodeId: viewModel.nodeId);
  }

  @override
  void updateRenderObject(BuildContext context, RenderHorizontalRuleBlock renderObject) {
    renderObject
      ..nodeId = viewModel.nodeId
      ..nodeSelection = viewModel.nodeSelection;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<HorizontalRuleComponentViewModel>('viewModel', viewModel),
    );
  }
}
