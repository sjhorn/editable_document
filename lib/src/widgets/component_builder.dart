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
/// The seven default builders are available via [defaultComponentBuilders].
/// Use [resolveViewModel] to try builders in order and return the first
/// non-null result.
library;

import 'dart:ui' as ui show Image;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '_image_provider_stub.dart' if (dart.library.io) '_image_provider_io.dart';
import '../model/attributed_text.dart';
import '../model/block_border.dart';
import '../model/block_alignment.dart';
import '../model/block_dimension.dart';
import '../model/text_wrap_mode.dart';
import '../model/blockquote_node.dart';
import '../model/code_block_node.dart';
import '../model/document.dart';
import '../model/document_node.dart';
import '../model/document_selection.dart';
import '../model/horizontal_rule_node.dart';
import '../model/image_node.dart';
import '../model/list_item_node.dart';
import '../model/paragraph_node.dart';
import '../model/table_node.dart';
import '../model/table_vertical_alignment.dart';
import '../rendering/block_layout_mixin.dart';
import '../rendering/render_blockquote_block.dart';
import '../rendering/render_code_block.dart';
import '../rendering/render_text_block.dart' show TextSpanBuilder;
import '../rendering/render_horizontal_rule_block.dart';
import '../rendering/render_image_block.dart';
import '../rendering/render_list_item_block.dart';
import '../rendering/render_paragraph_block.dart';
import '../rendering/render_table_block.dart';

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
// HasLayoutFields — view model interface for block layout properties
// ---------------------------------------------------------------------------

/// Interface for component view models with block layout fields.
///
/// Container block view models — [ImageComponentViewModel],
/// [CodeBlockComponentViewModel], [BlockquoteComponentViewModel], and
/// [HorizontalRuleComponentViewModel] — all implement this interface,
/// enabling the shared [_updateBlockLayout] helper.
abstract interface class HasLayoutFields {
  /// The horizontal alignment within the layout.
  BlockAlignment get alignment;

  /// How surrounding text interacts with this block.
  TextWrapMode get textWrap;

  /// Preferred display width as a [BlockDimension], or `null` for default sizing.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel width or
  /// [BlockDimension.percent] for a fraction of the document width.
  BlockDimension? get width;

  /// Preferred display height as a [BlockDimension], or `null` for default sizing.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel height or
  /// [BlockDimension.percent] for a fraction of the viewport height.
  BlockDimension? get height;
}

/// Updates block layout properties on a render object from a view model.
void _updateBlockLayout(BlockLayoutMixin renderObject, HasLayoutFields vm) {
  renderObject
    ..blockAlignment = vm.alignment
    ..widthDimension = vm.width
    ..heightDimension = vm.height
    ..textWrap = vm.textWrap;
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
/// 5. [BlockquoteComponentBuilder]
/// 6. [HorizontalRuleComponentBuilder]
/// 7. [TableComponentBuilder]
///
/// Prepend custom builders to override defaults for specific node types.
const List<ComponentBuilder> defaultComponentBuilders = [
  ParagraphComponentBuilder(),
  ListItemComponentBuilder(),
  ImageComponentBuilder(),
  CodeBlockComponentBuilder(),
  BlockquoteComponentBuilder(),
  HorizontalRuleComponentBuilder(),
  TableComponentBuilder(),
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
    this.textAlign = TextAlign.start,
    this.lineHeight,
    this.spaceBefore,
    this.spaceAfter,
    this.indentLeft,
    this.indentRight,
    this.firstLineIndent,
    this.border,
    super.nodeSelection,
    super.isSelected,
  });

  /// The text content of the paragraph.
  final AttributedText text;

  /// The semantic block type (heading level, blockquote, etc.).
  final ParagraphBlockType blockType;

  /// The base [TextStyle] to apply before block-type scaling.
  final TextStyle textStyle;

  /// The text alignment for this paragraph.
  final TextAlign textAlign;

  /// Line-height multiplier, or `null` to inherit the document default.
  final double? lineHeight;

  /// Extra space before this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceBefore;

  /// Extra space after this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceAfter;

  /// Left indent in logical pixels, or `null` for no extra indent.
  final double? indentLeft;

  /// Right indent in logical pixels, or `null` for no extra indent.
  final double? indentRight;

  /// First-line indent in logical pixels, or `null` for no special first-line treatment.
  final double? firstLineIndent;

  /// The outside border drawn around this block, or `null` for no border.
  final BlockBorder? border;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParagraphComponentViewModel &&
        other.nodeId == nodeId &&
        other.text == text &&
        other.blockType == blockType &&
        other.textStyle == textStyle &&
        other.textAlign == textAlign &&
        other.lineHeight == lineHeight &&
        other.spaceBefore == spaceBefore &&
        other.spaceAfter == spaceAfter &&
        other.indentLeft == indentLeft &&
        other.indentRight == indentRight &&
        other.firstLineIndent == firstLineIndent &&
        other.border == border &&
        other.nodeSelection == nodeSelection &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(
        nodeId,
        text,
        blockType,
        textStyle,
        textAlign,
        lineHeight,
        spaceBefore,
        spaceAfter,
        indentLeft,
        indentRight,
        firstLineIndent,
        border,
        nodeSelection,
        isSelected,
      );
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
      textAlign: node.textAlign,
      lineHeight: node.lineHeight,
      spaceBefore: node.spaceBefore,
      spaceAfter: node.spaceAfter,
      indentLeft: node.indentLeft,
      indentRight: node.indentRight,
      firstLineIndent: node.firstLineIndent,
      border: node.border,
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
      textAlign: viewModel.textAlign,
    )
      ..lineHeightMultiplier = viewModel.lineHeight
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..indentLeft = viewModel.indentLeft ?? 0
      ..indentRight = viewModel.indentRight ?? 0
      ..firstLineIndent = viewModel.firstLineIndent ?? 0
      ..border = viewModel.border;
  }

  @override
  void updateRenderObject(BuildContext context, RenderParagraphBlock renderObject) {
    renderObject
      ..nodeId = viewModel.nodeId
      ..text = viewModel.text
      ..blockType = viewModel.blockType
      ..baseTextStyle = DefaultTextStyle.of(context).style.merge(viewModel.textStyle)
      ..textAlign = viewModel.textAlign
      ..lineHeightMultiplier = viewModel.lineHeight
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..indentLeft = viewModel.indentLeft ?? 0
      ..indentRight = viewModel.indentRight ?? 0
      ..firstLineIndent = viewModel.firstLineIndent ?? 0
      ..border = viewModel.border
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
    this.textAlign = TextAlign.start,
    this.lineHeight,
    this.spaceBefore,
    this.spaceAfter,
    this.indentLeft,
    this.indentRight,
    this.border,
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

  /// The text alignment for this list item.
  final TextAlign textAlign;

  /// Line-height multiplier, or `null` to inherit the document default.
  final double? lineHeight;

  /// Extra space before this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceBefore;

  /// Extra space after this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceAfter;

  /// Left indent in logical pixels, or `null` for no extra indent.
  final double? indentLeft;

  /// Right indent in logical pixels, or `null` for no extra indent.
  final double? indentRight;

  /// The outside border drawn around this block, or `null` for no border.
  final BlockBorder? border;

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
        other.textAlign == textAlign &&
        other.lineHeight == lineHeight &&
        other.spaceBefore == spaceBefore &&
        other.spaceAfter == spaceAfter &&
        other.indentLeft == indentLeft &&
        other.indentRight == indentRight &&
        other.border == border &&
        other.nodeSelection == nodeSelection &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(
        nodeId,
        text,
        type,
        indent,
        ordinalIndex,
        textStyle,
        textAlign,
        lineHeight,
        spaceBefore,
        spaceAfter,
        indentLeft,
        indentRight,
        border,
        nodeSelection,
        isSelected,
      );
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
      textAlign: node.textAlign,
      lineHeight: node.lineHeight,
      spaceBefore: node.spaceBefore,
      spaceAfter: node.spaceAfter,
      indentLeft: node.indentLeft,
      indentRight: node.indentRight,
      border: node.border,
    );
  }

  /// Computes the 1-based ordinal index for [node] within a run of ordered
  /// list items at the same indent level.
  ///
  /// The counter increments for each preceding ordered item at the same indent.
  /// It resets to 1 when:
  /// - A non-list-item node is encountered.
  /// - A list item at a shallower or equal indent (parent or sibling of a
  ///   different type) is encountered.
  ///
  /// Items at a deeper indent (children) are skipped without affecting the
  /// counter so that nested sub-lists do not break the parent run.
  int _computeOrdinal(Document document, ListItemNode node) {
    if (node.type != ListItemType.ordered) return 1;
    var count = 1;
    for (final n in document.nodes) {
      if (n.id == node.id) break;
      if (n is ListItemNode) {
        if (n.type == ListItemType.ordered && n.indent == node.indent) {
          count++;
        } else if (n.indent <= node.indent) {
          // A parent-level item or a same-level item of a different type
          // breaks the ordered run.
          count = 1;
        }
        // n.indent > node.indent → child items never break a parent run.
      } else {
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
      textAlign: viewModel.textAlign,
    )
      ..lineHeightMultiplier = viewModel.lineHeight
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..indentLeft = viewModel.indentLeft ?? 0
      ..indentRight = viewModel.indentRight ?? 0
      ..border = viewModel.border;
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
      ..textAlign = viewModel.textAlign
      ..lineHeightMultiplier = viewModel.lineHeight
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..indentLeft = viewModel.indentLeft ?? 0
      ..indentRight = viewModel.indentRight ?? 0
      ..border = viewModel.border
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
class ImageComponentViewModel extends ComponentViewModel implements HasLayoutFields {
  /// Creates an [ImageComponentViewModel].
  const ImageComponentViewModel({
    required super.nodeId,
    required this.imageUrl,
    this.altText,
    this.imageWidth,
    this.imageHeight,
    this.alignment = BlockAlignment.stretch,
    this.textWrap = TextWrapMode.none,
    this.spaceBefore,
    this.spaceAfter,
    this.border,
    super.nodeSelection,
    super.isSelected,
  });

  /// The URL of the image.
  final String imageUrl;

  /// Accessible description of the image, or `null`.
  final String? altText;

  /// Preferred display width as a [BlockDimension], or `null` to use intrinsic size.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel width or
  /// [BlockDimension.percent] for a fraction of the document width.
  final BlockDimension? imageWidth;

  /// Preferred display height as a [BlockDimension], or `null` to use intrinsic size.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel height or
  /// [BlockDimension.percent] for a fraction of the viewport height.
  final BlockDimension? imageHeight;

  /// The horizontal alignment of this image within the layout.
  ///
  /// Defaults to [BlockAlignment.stretch].
  final BlockAlignment alignment;

  /// How surrounding text interacts with this image.
  ///
  /// Defaults to [TextWrapMode.none].
  final TextWrapMode textWrap;

  /// Extra space before this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceBefore;

  /// Extra space after this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceAfter;

  /// The outside border drawn around this block, or `null` for no border.
  final BlockBorder? border;

  @override
  BlockDimension? get width => imageWidth;

  @override
  BlockDimension? get height => imageHeight;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageComponentViewModel &&
        other.nodeId == nodeId &&
        other.imageUrl == imageUrl &&
        other.altText == altText &&
        other.imageWidth == imageWidth &&
        other.imageHeight == imageHeight &&
        other.alignment == alignment &&
        other.textWrap == textWrap &&
        other.spaceBefore == spaceBefore &&
        other.spaceAfter == spaceAfter &&
        other.border == border &&
        other.nodeSelection == nodeSelection &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(
        nodeId,
        imageUrl,
        altText,
        imageWidth,
        imageHeight,
        alignment,
        textWrap,
        spaceBefore,
        spaceAfter,
        border,
        nodeSelection,
        isSelected,
      );
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
      alignment: node.alignment,
      textWrap: node.textWrap,
      spaceBefore: node.spaceBefore,
      spaceAfter: node.spaceAfter,
      border: node.border,
    );
  }

  @override
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context) {
    if (viewModel is! ImageComponentViewModel) return null;
    return _ImageBlockWidget(viewModel: viewModel);
  }
}

/// [StatefulWidget] that loads an image via [ImageStream] and renders it
/// with [_RawImageBlockWidget].
///
/// Manages the full [ImageStream] lifecycle: resolves the stream in
/// [State.didChangeDependencies] (and whenever [imageUrl] changes in
/// [State.didUpdateWidget]), adds/removes listeners, and disposes [ImageInfo]
/// in a post-frame callback to avoid disposing an image still in use during
/// the current frame.
class _ImageBlockWidget extends StatefulWidget {
  const _ImageBlockWidget({required this.viewModel});

  final ImageComponentViewModel viewModel;

  @override
  State<_ImageBlockWidget> createState() => _ImageBlockWidgetState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ImageComponentViewModel>('viewModel', viewModel));
  }
}

class _ImageBlockWidgetState extends State<_ImageBlockWidget> {
  ImageStream? _imageStream;
  ImageInfo? _imageInfo;
  late final ImageStreamListener _listener = ImageStreamListener(
    _handleImageFrame,
    onError: _handleImageError,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(_ImageBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel.imageUrl != widget.viewModel.imageUrl) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    final url = widget.viewModel.imageUrl;
    final ImageProvider provider;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      provider = NetworkImage(url);
    } else {
      final fileProvider = createFileImageProvider(url);
      if (fileProvider == null) return; // web — no local file support
      provider = fileProvider;
    }
    final newStream = provider.resolve(createLocalImageConfiguration(context));
    if (newStream.key != _imageStream?.key) {
      _imageStream?.removeListener(_listener);
      _imageStream = newStream;
      _imageStream!.addListener(_listener);
    }
  }

  void _handleImageFrame(ImageInfo info, bool synchronousCall) {
    if (identical(_imageInfo, info)) return;
    final old = _imageInfo;
    setState(() {
      _imageInfo = info;
    });
    if (old != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  void _handleImageError(Object error, StackTrace? stackTrace) {
    debugPrint('Failed to load image: $error');
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_listener);
    _imageInfo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RawImageBlockWidget(
      viewModel: widget.viewModel,
      image: _imageInfo?.image,
    );
  }
}

/// [LeafRenderObjectWidget] that wraps [RenderImageBlock] directly.
///
/// Accepts an optional pre-decoded [image] which is forwarded to the render
/// object. When [image] is `null` the render object paints a placeholder.
class _RawImageBlockWidget extends LeafRenderObjectWidget {
  const _RawImageBlockWidget({required this.viewModel, this.image});

  final ImageComponentViewModel viewModel;

  /// The decoded image to paint, or `null` to show the placeholder.
  final ui.Image? image;

  @override
  RenderImageBlock createRenderObject(BuildContext context) {
    return RenderImageBlock(
      nodeId: viewModel.nodeId,
      altText: viewModel.altText,
      image: image,
      blockAlignment: viewModel.alignment,
      widthDimension: viewModel.imageWidth,
      heightDimension: viewModel.imageHeight,
      textWrap: viewModel.textWrap,
    )
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..border = viewModel.border;
  }

  @override
  void updateRenderObject(BuildContext context, RenderImageBlock renderObject) {
    renderObject
      ..nodeId = viewModel.nodeId
      ..altText = viewModel.altText
      ..image = image
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..border = viewModel.border
      ..nodeSelection = viewModel.nodeSelection;
    _updateBlockLayout(renderObject, viewModel);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ImageComponentViewModel>('viewModel', viewModel));
    properties.add(DiagnosticsProperty<ui.Image?>('image', image, defaultValue: null));
  }
}

// ===========================================================================
// CodeBlockComponentBuilder
// ===========================================================================

/// [ComponentViewModel] for [CodeBlockNode].
class CodeBlockComponentViewModel extends ComponentViewModel implements HasLayoutFields {
  /// Creates a [CodeBlockComponentViewModel].
  const CodeBlockComponentViewModel({
    required super.nodeId,
    required this.text,
    required this.textStyle,
    this.language,
    this.width,
    this.height,
    this.alignment = BlockAlignment.stretch,
    this.textWrap = TextWrapMode.none,
    this.textSpanBuilder,
    this.lineHeight,
    this.spaceBefore,
    this.spaceAfter,
    this.border,
    super.nodeSelection,
    super.isSelected,
  });

  /// The source code text.
  final AttributedText text;

  /// The base [TextStyle] (font family will be overridden to monospace).
  final TextStyle textStyle;

  /// The programming language identifier for syntax highlighting, or `null`.
  final String? language;

  /// Preferred display width as a [BlockDimension], or `null` for default sizing.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel width or
  /// [BlockDimension.percent] for a fraction of the document width.
  final BlockDimension? width;

  /// Preferred display height as a [BlockDimension], or `null` for default sizing.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel height or
  /// [BlockDimension.percent] for a fraction of the viewport height.
  final BlockDimension? height;

  /// The horizontal alignment of this code block within the layout.
  ///
  /// Defaults to [BlockAlignment.stretch].
  final BlockAlignment alignment;

  /// How surrounding text interacts with this code block.
  ///
  /// Defaults to [TextWrapMode.none].
  final TextWrapMode textWrap;

  /// Optional callback to build a custom [TextSpan] for this code block.
  ///
  /// When non-null, the [RenderTextBlock] will use this callback instead
  /// of its default attribution-based span building. This allows external
  /// syntax-highlighting packages to provide pre-styled [TextSpan] trees.
  final TextSpanBuilder? textSpanBuilder;

  /// Line-height multiplier, or `null` to inherit the document default.
  final double? lineHeight;

  /// Extra space before this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceBefore;

  /// Extra space after this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceAfter;

  /// The outside border drawn around this block, or `null` for no border.
  final BlockBorder? border;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CodeBlockComponentViewModel &&
        other.nodeId == nodeId &&
        other.text == text &&
        other.textStyle == textStyle &&
        other.language == language &&
        other.width == width &&
        other.height == height &&
        other.alignment == alignment &&
        other.textWrap == textWrap &&
        other.lineHeight == lineHeight &&
        other.spaceBefore == spaceBefore &&
        other.spaceAfter == spaceAfter &&
        other.border == border &&
        other.nodeSelection == nodeSelection &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(
        nodeId,
        text,
        textStyle,
        language,
        width,
        height,
        alignment,
        textWrap,
        lineHeight,
        spaceBefore,
        spaceAfter,
        border,
        nodeSelection,
        isSelected,
      );
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
      width: node.width,
      height: node.height,
      alignment: node.alignment,
      textWrap: node.textWrap,
      lineHeight: node.lineHeight,
      spaceBefore: node.spaceBefore,
      spaceAfter: node.spaceAfter,
      border: node.border,
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
      blockAlignment: viewModel.alignment,
      widthDimension: viewModel.width,
      heightDimension: viewModel.height,
      textWrap: viewModel.textWrap,
    )
      ..textSpanBuilder = viewModel.textSpanBuilder
      ..lineHeightMultiplier = viewModel.lineHeight
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..border = viewModel.border;
  }

  @override
  void updateRenderObject(BuildContext context, RenderCodeBlock renderObject) {
    renderObject
      ..nodeId = viewModel.nodeId
      ..text = viewModel.text
      ..textSpanBuilder = viewModel.textSpanBuilder
      ..lineHeightMultiplier = viewModel.lineHeight
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..border = viewModel.border
      ..nodeSelection = viewModel.nodeSelection;
    _updateBlockLayout(renderObject, viewModel);
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
class HorizontalRuleComponentViewModel extends ComponentViewModel implements HasLayoutFields {
  /// Creates a [HorizontalRuleComponentViewModel].
  const HorizontalRuleComponentViewModel({
    required super.nodeId,
    this.alignment = BlockAlignment.stretch,
    this.width,
    this.height,
    this.textWrap = TextWrapMode.none,
    this.spaceBefore,
    this.spaceAfter,
    this.border,
    super.nodeSelection,
    super.isSelected,
  });

  /// The horizontal alignment of this rule within the layout.
  ///
  /// Defaults to [BlockAlignment.stretch].
  final BlockAlignment alignment;

  /// Preferred display width as a [BlockDimension], or `null` to fill available width.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel width or
  /// [BlockDimension.percent] for a fraction of the document width.
  final BlockDimension? width;

  /// Preferred display height as a [BlockDimension], or `null` to use the default.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel height or
  /// [BlockDimension.percent] for a fraction of the viewport height.
  final BlockDimension? height;

  /// How surrounding text interacts with this block.
  ///
  /// Defaults to [TextWrapMode.none].
  final TextWrapMode textWrap;

  /// Extra space before this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceBefore;

  /// Extra space after this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceAfter;

  /// The outside border drawn around this block, or `null` for no border.
  final BlockBorder? border;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HorizontalRuleComponentViewModel &&
        other.nodeId == nodeId &&
        other.alignment == alignment &&
        other.width == width &&
        other.height == height &&
        other.textWrap == textWrap &&
        other.spaceBefore == spaceBefore &&
        other.spaceAfter == spaceAfter &&
        other.border == border &&
        other.nodeSelection == nodeSelection &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(
        nodeId,
        alignment,
        width,
        height,
        textWrap,
        spaceBefore,
        spaceAfter,
        border,
        nodeSelection,
        isSelected,
      );
}

/// [ComponentBuilder] that handles [HorizontalRuleNode].
class HorizontalRuleComponentBuilder extends ComponentBuilder {
  /// Creates a const [HorizontalRuleComponentBuilder].
  const HorizontalRuleComponentBuilder();

  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! HorizontalRuleNode) return null;
    return HorizontalRuleComponentViewModel(
      nodeId: node.id,
      alignment: node.alignment,
      width: node.width,
      height: node.height,
      textWrap: node.textWrap,
      spaceBefore: node.spaceBefore,
      spaceAfter: node.spaceAfter,
      border: node.border,
    );
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
    return RenderHorizontalRuleBlock(
      nodeId: viewModel.nodeId,
      blockAlignment: viewModel.alignment,
      widthDimension: viewModel.width,
      heightDimension: viewModel.height,
      textWrap: viewModel.textWrap,
    )
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..border = viewModel.border;
  }

  @override
  void updateRenderObject(BuildContext context, RenderHorizontalRuleBlock renderObject) {
    renderObject
      ..nodeId = viewModel.nodeId
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..border = viewModel.border
      ..nodeSelection = viewModel.nodeSelection;
    _updateBlockLayout(renderObject, viewModel);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<HorizontalRuleComponentViewModel>('viewModel', viewModel),
    );
  }
}

// ===========================================================================
// BlockquoteComponentBuilder
// ===========================================================================

/// [ComponentViewModel] for [BlockquoteNode].
class BlockquoteComponentViewModel extends ComponentViewModel implements HasLayoutFields {
  /// Creates a [BlockquoteComponentViewModel].
  const BlockquoteComponentViewModel({
    required super.nodeId,
    required this.text,
    required this.textStyle,
    this.width,
    this.height,
    this.alignment = BlockAlignment.stretch,
    this.textWrap = TextWrapMode.none,
    this.textAlign = TextAlign.start,
    this.lineHeight,
    this.spaceBefore,
    this.spaceAfter,
    this.indentLeft,
    this.indentRight,
    this.firstLineIndent,
    this.border,
    super.nodeSelection,
    super.isSelected,
  });

  /// The attributed text content of the blockquote.
  final AttributedText text;

  /// The base [TextStyle] applied before attributions.
  final TextStyle textStyle;

  /// Preferred display width as a [BlockDimension], or `null` for default sizing.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel width or
  /// [BlockDimension.percent] for a fraction of the document width.
  final BlockDimension? width;

  /// Preferred display height as a [BlockDimension], or `null` for default sizing.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel height or
  /// [BlockDimension.percent] for a fraction of the viewport height.
  final BlockDimension? height;

  /// The horizontal alignment of this blockquote within the layout.
  ///
  /// Defaults to [BlockAlignment.stretch].
  final BlockAlignment alignment;

  /// How surrounding text interacts with this blockquote.
  ///
  /// Defaults to [TextWrapMode.none].
  final TextWrapMode textWrap;

  /// The text alignment for this blockquote.
  final TextAlign textAlign;

  /// Line-height multiplier, or `null` to inherit the document default.
  final double? lineHeight;

  /// Extra space before this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceBefore;

  /// Extra space after this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceAfter;

  /// Left indent in logical pixels, or `null` for no extra indent.
  final double? indentLeft;

  /// Right indent in logical pixels, or `null` for no extra indent.
  final double? indentRight;

  /// First-line indent in logical pixels, or `null` for no special first-line treatment.
  final double? firstLineIndent;

  /// The outside border drawn around this block, or `null` for no border.
  final BlockBorder? border;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BlockquoteComponentViewModel &&
        other.nodeId == nodeId &&
        other.text == text &&
        other.textStyle == textStyle &&
        other.width == width &&
        other.height == height &&
        other.alignment == alignment &&
        other.textWrap == textWrap &&
        other.textAlign == textAlign &&
        other.lineHeight == lineHeight &&
        other.spaceBefore == spaceBefore &&
        other.spaceAfter == spaceAfter &&
        other.indentLeft == indentLeft &&
        other.indentRight == indentRight &&
        other.firstLineIndent == firstLineIndent &&
        other.border == border &&
        other.nodeSelection == nodeSelection &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(
        nodeId,
        text,
        textStyle,
        width,
        height,
        alignment,
        textWrap,
        textAlign,
        lineHeight,
        spaceBefore,
        spaceAfter,
        indentLeft,
        indentRight,
        firstLineIndent,
        border,
        nodeSelection,
        isSelected,
      );
}

/// [ComponentBuilder] that handles [BlockquoteNode].
class BlockquoteComponentBuilder extends ComponentBuilder {
  /// Creates a const [BlockquoteComponentBuilder].
  const BlockquoteComponentBuilder();

  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! BlockquoteNode) return null;
    return BlockquoteComponentViewModel(
      nodeId: node.id,
      text: node.text,
      textStyle: const TextStyle(),
      width: node.width,
      height: node.height,
      alignment: node.alignment,
      textWrap: node.textWrap,
      textAlign: node.textAlign,
      lineHeight: node.lineHeight,
      spaceBefore: node.spaceBefore,
      spaceAfter: node.spaceAfter,
      indentLeft: node.indentLeft,
      indentRight: node.indentRight,
      firstLineIndent: node.firstLineIndent,
      border: node.border,
    );
  }

  @override
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context) {
    if (viewModel is! BlockquoteComponentViewModel) return null;
    return _BlockquoteBlockWidget(viewModel: viewModel);
  }
}

/// [LeafRenderObjectWidget] that wraps [RenderBlockquoteBlock].
class _BlockquoteBlockWidget extends LeafRenderObjectWidget {
  const _BlockquoteBlockWidget({required this.viewModel});

  final BlockquoteComponentViewModel viewModel;

  @override
  RenderBlockquoteBlock createRenderObject(BuildContext context) {
    return RenderBlockquoteBlock(
      nodeId: viewModel.nodeId,
      text: viewModel.text,
      textStyle: DefaultTextStyle.of(context).style.merge(viewModel.textStyle),
      blockAlignment: viewModel.alignment,
      widthDimension: viewModel.width,
      heightDimension: viewModel.height,
      textWrap: viewModel.textWrap,
      textAlign: viewModel.textAlign,
    )
      ..lineHeightMultiplier = viewModel.lineHeight
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..indentLeft = viewModel.indentLeft ?? 0
      ..indentRight = viewModel.indentRight ?? 0
      ..firstLineIndent = viewModel.firstLineIndent ?? 0
      ..border = viewModel.border;
  }

  @override
  void updateRenderObject(BuildContext context, RenderBlockquoteBlock renderObject) {
    renderObject
      ..nodeId = viewModel.nodeId
      ..text = viewModel.text
      ..textStyle = DefaultTextStyle.of(context).style.merge(viewModel.textStyle)
      ..textAlign = viewModel.textAlign
      ..lineHeightMultiplier = viewModel.lineHeight
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..indentLeft = viewModel.indentLeft ?? 0
      ..indentRight = viewModel.indentRight ?? 0
      ..firstLineIndent = viewModel.firstLineIndent ?? 0
      ..border = viewModel.border
      ..nodeSelection = viewModel.nodeSelection;
    _updateBlockLayout(renderObject, viewModel);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BlockquoteComponentViewModel>('viewModel', viewModel));
  }
}

// ===========================================================================
// TableComponentBuilder
// ===========================================================================

/// [ComponentViewModel] for [TableNode].
///
/// Holds the full cell grid, dimension counts, per-column width hints, and
/// block layout properties forwarded from the source [TableNode]. The widget
/// layer uses this to create and update a [RenderTableBlock].
class TableComponentViewModel extends ComponentViewModel implements HasLayoutFields {
  /// Creates a [TableComponentViewModel].
  ///
  /// [nodeId] uniquely identifies the source [TableNode].
  /// [rowCount] and [columnCount] define the grid dimensions.
  /// [cells] is the [rowCount] × [columnCount] grid of [AttributedText] values.
  /// [columnWidths] optionally specifies per-column widths; `null` entries mean
  ///   that column is auto-sized. When the list itself is `null`, all columns
  ///   are auto-sized.
  /// [rowHeights] optionally specifies per-row minimum heights; `null` entries
  ///   mean that row is auto-sized. When the list itself is `null`, all rows
  ///   are auto-sized.
  /// [textStyle] is the base [TextStyle] applied before attributions.
  /// [cellPadding] is the horizontal and vertical padding inside each cell.
  /// [borderWidth] is the stroke width of the grid lines.
  /// [borderColor] is the color of the grid lines.
  /// [alignment] is the horizontal alignment within the layout.
  /// [textWrap] controls how surrounding text interacts with this block.
  /// [requestedWidth] and [requestedHeight] are optional explicit dimensions.
  /// [spaceBefore] and [spaceAfter] are optional spacing overrides.
  TableComponentViewModel({
    required super.nodeId,
    required this.rowCount,
    required this.columnCount,
    required this.cells,
    this.columnWidths,
    this.rowHeights,
    this.cellTextAligns,
    this.cellVerticalAligns,
    this.textStyle,
    this.cellPadding = 8.0,
    this.borderWidth = 1.0,
    this.borderColor = const Color(0xFFCCCCCC),
    this.alignment = BlockAlignment.stretch,
    this.textWrap = TextWrapMode.none,
    this.requestedWidth,
    this.requestedHeight,
    this.spaceBefore,
    this.spaceAfter,
    this.border,
    super.nodeSelection,
    super.isSelected,
  });

  /// Number of rows in the table.
  final int rowCount;

  /// Number of columns in the table.
  final int columnCount;

  /// The 2-D grid of [AttributedText] cells.
  ///
  /// Outer list has [rowCount] entries; each inner list has [columnCount]
  /// entries. The grid is not modifiable after construction.
  final List<List<AttributedText>> cells;

  /// Optional per-column width hints in logical pixels.
  ///
  /// When non-null, the list has exactly [columnCount] entries. A `null` entry
  /// means the corresponding column is auto-sized. When the list itself is
  /// `null`, all columns are auto-sized.
  final List<double?>? columnWidths;

  /// Optional per-row minimum height hints in logical pixels.
  ///
  /// When non-null, the list has exactly [rowCount] entries. A `null` entry
  /// means the corresponding row is auto-sized. When the list itself is
  /// `null`, all rows are auto-sized.
  final List<double?>? rowHeights;

  /// Per-cell horizontal text alignment, or `null` to use the default.
  ///
  /// When non-null, this is a rowCount × columnCount 2D grid of [TextAlign]
  /// values. Each inner list corresponds to one row.
  final List<List<TextAlign>>? cellTextAligns;

  /// Per-cell vertical alignment, or `null` to use [TableVerticalAlignment.top].
  ///
  /// When non-null, this is a rowCount × columnCount 2D grid of
  /// [TableVerticalAlignment] values. Each inner list corresponds to one row.
  final List<List<TableVerticalAlignment>>? cellVerticalAligns;

  /// The base [TextStyle] applied to all cell text before attributions.
  ///
  /// When `null`, the ambient [DefaultTextStyle] is used.
  final TextStyle? textStyle;

  /// Horizontal and vertical padding inside each cell in logical pixels.
  ///
  /// Defaults to `8.0`.
  final double cellPadding;

  /// Stroke width of the grid lines in logical pixels.
  ///
  /// Defaults to `1.0`.
  final double borderWidth;

  /// Color of the grid lines.
  ///
  /// Defaults to `Color(0xFFCCCCCC)` (light grey).
  final Color borderColor;

  /// The horizontal alignment of this table within the layout.
  ///
  /// Defaults to [BlockAlignment.stretch].
  @override
  final BlockAlignment alignment;

  /// How surrounding text interacts with this table.
  ///
  /// Defaults to [TextWrapMode.none].
  @override
  final TextWrapMode textWrap;

  /// Preferred display width as a [BlockDimension], or `null` to fill available width.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel width or
  /// [BlockDimension.percent] for a fraction of the document width.
  final BlockDimension? requestedWidth;

  /// Preferred display height as a [BlockDimension], or `null` to use intrinsic height.
  ///
  /// Use [BlockDimension.pixels] for a fixed logical-pixel height or
  /// [BlockDimension.percent] for a fraction of the viewport height.
  final BlockDimension? requestedHeight;

  /// Extra space before this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceBefore;

  /// Extra space after this block in logical pixels, or `null` to use the
  /// document-level default spacing.
  final double? spaceAfter;

  /// The outside border drawn around this block, or `null` for no border.
  final BlockBorder? border;

  @override
  BlockDimension? get width => requestedWidth;

  @override
  BlockDimension? get height => requestedHeight;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TableComponentViewModel) return false;
    if (other.nodeId != nodeId ||
        other.rowCount != rowCount ||
        other.columnCount != columnCount ||
        other.textStyle != textStyle ||
        other.cellPadding != cellPadding ||
        other.borderWidth != borderWidth ||
        other.borderColor != borderColor ||
        other.alignment != alignment ||
        other.textWrap != textWrap ||
        other.requestedWidth != requestedWidth ||
        other.requestedHeight != requestedHeight ||
        other.spaceBefore != spaceBefore ||
        other.spaceAfter != spaceAfter ||
        other.border != border ||
        other.nodeSelection != nodeSelection ||
        other.isSelected != isSelected) {
      return false;
    }
    // Compare columnWidths, rowHeights, cellTextAligns, cellVerticalAligns.
    if (!_listEquals(other.columnWidths, columnWidths)) return false;
    if (!_listEquals(other.rowHeights, rowHeights)) return false;
    // Compare cellTextAligns row by row.
    if ((other.cellTextAligns == null) != (cellTextAligns == null)) return false;
    if (cellTextAligns != null) {
      for (int r = 0; r < rowCount; r++) {
        if (!_listEquals(other.cellTextAligns![r], cellTextAligns![r])) return false;
      }
    }
    // Compare cellVerticalAligns row by row.
    if ((other.cellVerticalAligns == null) != (cellVerticalAligns == null)) return false;
    if (cellVerticalAligns != null) {
      for (int r = 0; r < rowCount; r++) {
        if (!_listEquals(other.cellVerticalAligns![r], cellVerticalAligns![r])) return false;
      }
    }
    // Compare cells row by row.
    if (other.cells.length != cells.length) return false;
    for (int r = 0; r < rowCount; r++) {
      if (other.cells[r].length != cells[r].length) return false;
      for (int c = 0; c < columnCount; c++) {
        if (other.cells[r][c] != cells[r][c]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    final cellHashes = <int>[];
    for (final row in cells) {
      for (final cell in row) {
        cellHashes.add(cell.hashCode);
      }
    }
    final scalarHash = Object.hash(
      nodeId,
      rowCount,
      columnCount,
      textStyle,
      cellPadding,
      borderWidth,
      borderColor,
      alignment,
      textWrap,
      requestedWidth,
      requestedHeight,
      spaceBefore,
      spaceAfter,
      border,
      nodeSelection,
      isSelected,
    );
    return Object.hash(
      scalarHash,
      Object.hashAll(cellHashes),
      Object.hashAll(columnWidths ?? const <double?>[]),
      Object.hashAll(rowHeights ?? const <double?>[]),
      Object.hashAll(cellTextAligns == null
          ? const <TextAlign>[]
          : [for (final row in cellTextAligns!) ...row]),
      Object.hashAll(cellVerticalAligns == null
          ? const <TableVerticalAlignment>[]
          : [for (final row in cellVerticalAligns!) ...row]),
    );
  }
}

/// [ComponentBuilder] that handles [TableNode].
///
/// Creates a [TableComponentViewModel] from a [TableNode] and returns a
/// [_TableBlockWidget] that drives a [RenderTableBlock].
class TableComponentBuilder extends ComponentBuilder {
  /// Creates a const [TableComponentBuilder].
  const TableComponentBuilder();

  @override
  ComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! TableNode) return null;
    // Reconstruct the cells grid from the public cellAt accessor.
    final cells = List.generate(
      node.rowCount,
      (r) => List.generate(node.columnCount, (c) => node.cellAt(r, c)),
    );
    return TableComponentViewModel(
      nodeId: node.id,
      rowCount: node.rowCount,
      columnCount: node.columnCount,
      cells: cells,
      columnWidths: node.columnWidths,
      rowHeights: node.rowHeights,
      cellTextAligns: node.cellTextAligns,
      cellVerticalAligns: node.cellVerticalAligns,
      alignment: node.alignment,
      textWrap: node.textWrap,
      requestedWidth: node.width,
      requestedHeight: node.height,
      spaceBefore: node.spaceBefore,
      spaceAfter: node.spaceAfter,
      border: node.border,
    );
  }

  @override
  Widget? createComponent(ComponentViewModel viewModel, ComponentContext context) {
    if (viewModel is! TableComponentViewModel) return null;
    return _TableBlockWidget(viewModel: viewModel);
  }
}

/// [LeafRenderObjectWidget] that wraps [RenderTableBlock].
class _TableBlockWidget extends LeafRenderObjectWidget {
  const _TableBlockWidget({required this.viewModel});

  final TableComponentViewModel viewModel;

  @override
  RenderTableBlock createRenderObject(BuildContext context) {
    final textStyle = DefaultTextStyle.of(context).style.merge(viewModel.textStyle);
    return RenderTableBlock(
      nodeId: viewModel.nodeId,
      rowCount: viewModel.rowCount,
      columnCount: viewModel.columnCount,
      cells: viewModel.cells,
      textStyle: textStyle,
      columnWidths: viewModel.columnWidths,
      rowHeights: viewModel.rowHeights,
      cellTextAligns: viewModel.cellTextAligns,
      cellVerticalAligns: viewModel.cellVerticalAligns,
      cellPadding: viewModel.cellPadding,
      borderWidth: viewModel.borderWidth,
      borderColor: viewModel.borderColor,
      blockAlignment: viewModel.alignment,
      widthDimension: viewModel.requestedWidth,
      heightDimension: viewModel.requestedHeight,
      textWrap: viewModel.textWrap,
    )
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..border = viewModel.border;
  }

  @override
  void updateRenderObject(BuildContext context, RenderTableBlock renderObject) {
    final textStyle = DefaultTextStyle.of(context).style.merge(viewModel.textStyle);
    renderObject
      ..nodeId = viewModel.nodeId
      ..rowCount = viewModel.rowCount
      ..columnCount = viewModel.columnCount
      ..cells = viewModel.cells
      ..textStyle = textStyle
      ..columnWidths = viewModel.columnWidths
      ..rowHeights = viewModel.rowHeights
      ..cellTextAligns = viewModel.cellTextAligns
      ..cellVerticalAligns = viewModel.cellVerticalAligns
      ..cellPadding = viewModel.cellPadding
      ..borderWidth = viewModel.borderWidth
      ..borderColor = viewModel.borderColor
      ..spaceBefore = viewModel.spaceBefore
      ..spaceAfter = viewModel.spaceAfter
      ..border = viewModel.border
      ..nodeSelection = viewModel.nodeSelection;
    _updateBlockLayout(renderObject, viewModel);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TableComponentViewModel>('viewModel', viewModel));
  }
}

// ---------------------------------------------------------------------------
// Private helper
// ---------------------------------------------------------------------------

/// Null-safe shallow equality for nullable lists.
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
