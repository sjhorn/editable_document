/// Block layout mixin for the editable_document rendering layer.
///
/// Provides [BlockLayoutMixin], a mixin on [RenderDocumentBlock] that
/// implements the four common layout property fields: [blockAlignment],
/// [requestedWidth], [requestedHeight], and [textWrap].
library;

import 'package:flutter/rendering.dart';

import '../model/block_alignment.dart';
import '../model/block_dimension.dart';
import '../model/text_wrap_mode.dart';
import 'render_document_block.dart';

/// Mixin that provides storage and setter boilerplate for the four block
/// layout properties shared by container render objects.
///
/// Concrete render objects ([RenderImageBlock], [RenderCodeBlock],
/// [RenderBlockquoteBlock], [RenderHorizontalRuleBlock]) use this mixin
/// instead of duplicating the same private fields, getters, and setters.
///
/// Call [initBlockLayout] from the constructor body to set initial values
/// without triggering [markNeedsLayout].
///
/// The [textWrap] property uses [TextWrapMode] to control how surrounding
/// content interacts with this block when it is floated.
///
/// ```dart
/// class RenderMyBlock extends RenderDocumentBlock with BlockLayoutMixin {
///   RenderMyBlock({
///     BlockAlignment blockAlignment = BlockAlignment.stretch,
///     BlockDimension? widthDimension,
///   }) {
///     initBlockLayout(
///       blockAlignment: blockAlignment,
///       widthDimension: widthDimension,
///     );
///   }
/// }
/// ```
mixin BlockLayoutMixin on RenderDocumentBlock {
  BlockAlignment _blockAlignment = BlockAlignment.stretch;
  BlockDimension? _widthDimension;
  BlockDimension? _heightDimension;
  double? _requestedWidth;
  double? _requestedHeight;
  TextWrapMode _textWrap = TextWrapMode.none;

  /// Sets initial block layout values without triggering [markNeedsLayout].
  ///
  /// Call this from the constructor body. Because the render object has not
  /// been attached to the tree yet, calling [markNeedsLayout] would be
  /// premature.
  void initBlockLayout({
    BlockAlignment blockAlignment = BlockAlignment.stretch,
    BlockDimension? widthDimension,
    BlockDimension? heightDimension,
    TextWrapMode textWrap = TextWrapMode.none,
  }) {
    _blockAlignment = blockAlignment;
    _widthDimension = widthDimension;
    _heightDimension = heightDimension;
    // Resolve immediately for PixelDimension; PercentDimension will be
    // resolved later by RenderDocumentLayout before layout.
    _requestedWidth = widthDimension is PixelDimension ? widthDimension.value : null;
    _requestedHeight = heightDimension is PixelDimension ? heightDimension.value : null;
    _textWrap = textWrap;
  }

  /// The horizontal alignment of this block within the layout.
  ///
  /// Defaults to [BlockAlignment.stretch].  Changing this value schedules a
  /// layout pass so the parent can reposition the block.
  // ignore: diagnostic_describe_all_properties
  @override
  BlockAlignment get blockAlignment => _blockAlignment;

  /// Sets the block alignment and schedules a layout pass.
  set blockAlignment(BlockAlignment value) {
    if (_blockAlignment == value) return;
    _blockAlignment = value;
    markNeedsLayout();
  }

  /// The [BlockDimension] for the width of this block, or `null`.
  ///
  /// Use [BlockDimension.pixels] for a fixed width or [BlockDimension.percent]
  /// for a width relative to the document's available width.  When `null`,
  /// the block fills the available width.
  ///
  /// [RenderDocumentLayout] resolves this to [requestedWidth] before each
  /// layout pass.
  // ignore: diagnostic_describe_all_properties
  @override
  BlockDimension? get widthDimension => _widthDimension;

  /// Sets the width dimension and schedules a layout pass.
  ///
  /// For [PixelDimension] values, [requestedWidth] is updated immediately.
  /// For [PercentDimension] values, [requestedWidth] is updated lazily by
  /// [resolveWidth] during [RenderDocumentLayout.performLayout].
  set widthDimension(BlockDimension? value) {
    if (_widthDimension == value) return;
    _widthDimension = value;
    if (value is PixelDimension) {
      _requestedWidth = value.value;
    } else if (value == null) {
      _requestedWidth = null;
    }
    markNeedsLayout();
  }

  /// The [BlockDimension] for the height of this block, or `null`.
  ///
  /// Use [BlockDimension.pixels] for a fixed height or [BlockDimension.percent]
  /// for a height relative to the viewport height.  When `null`, the block
  /// uses its intrinsic height.
  ///
  /// [RenderDocumentLayout] resolves this to [requestedHeight] before each
  /// layout pass.
  // ignore: diagnostic_describe_all_properties
  @override
  BlockDimension? get heightDimension => _heightDimension;

  /// Sets the height dimension and schedules a layout pass.
  ///
  /// For [PixelDimension] values, [requestedHeight] is updated immediately.
  /// For [PercentDimension] values, [requestedHeight] is updated lazily by
  /// [resolveHeight] during [RenderDocumentLayout.performLayout].
  set heightDimension(BlockDimension? value) {
    if (_heightDimension == value) return;
    _heightDimension = value;
    if (value is PixelDimension) {
      _requestedHeight = value.value;
    } else if (value == null) {
      _requestedHeight = null;
    }
    markNeedsLayout();
  }

  /// The requested width of this block in logical pixels, or `null`.
  ///
  /// This is the resolved value of [widthDimension] in pixels.  It is set
  /// automatically by [resolveWidth] during [RenderDocumentLayout.performLayout].
  /// When `null`, the block fills the available width.
  // ignore: diagnostic_describe_all_properties
  @override
  double? get requestedWidth => _requestedWidth;

  /// Sets the requested width directly in pixels and schedules a layout pass.
  ///
  /// Prefer using [widthDimension] for new code.  This setter exists for
  /// backward compatibility with callers that work in pixels directly.
  /// It clears [widthDimension] so the two properties remain consistent.
  set requestedWidth(double? value) {
    if (_requestedWidth == value) return;
    _requestedWidth = value;
    _widthDimension = value != null ? BlockDimension.pixels(value) : null;
    markNeedsLayout();
  }

  /// The requested height of this block in logical pixels, or `null`.
  ///
  /// This is the resolved value of [heightDimension] in pixels.  It is set
  /// automatically by [resolveHeight] during [RenderDocumentLayout.performLayout].
  /// When `null`, the block uses its intrinsic height.
  // ignore: diagnostic_describe_all_properties
  @override
  double? get requestedHeight => _requestedHeight;

  /// Sets the requested height directly in pixels and schedules a layout pass.
  ///
  /// Prefer using [heightDimension] for new code.  This setter exists for
  /// backward compatibility with callers that work in pixels directly.
  /// It clears [heightDimension] so the two properties remain consistent.
  set requestedHeight(double? value) {
    if (_requestedHeight == value) return;
    _requestedHeight = value;
    _heightDimension = value != null ? BlockDimension.pixels(value) : null;
    markNeedsLayout();
  }

  /// Resolves [widthDimension] to pixels using [referenceSize] and stores
  /// the result in [requestedWidth].
  ///
  /// Called by [RenderDocumentLayout] at the start of each layout pass so
  /// that [PercentDimension] values are recalculated when the viewport changes.
  void resolveWidth(double referenceSize) {
    _requestedWidth = BlockDimension.resolve(_widthDimension, referenceSize);
  }

  /// Resolves [heightDimension] to pixels using [referenceSize] and stores
  /// the result in [requestedHeight].
  ///
  /// Called by [RenderDocumentLayout] at the start of each layout pass so
  /// that [PercentDimension] values are recalculated when the viewport changes.
  void resolveHeight(double referenceSize) {
    _requestedHeight = BlockDimension.resolve(_heightDimension, referenceSize);
  }

  /// How surrounding text interacts with this block when floated.
  ///
  /// When [TextWrapMode.wrap] and [blockAlignment] is [BlockAlignment.start],
  /// [BlockAlignment.end], or [BlockAlignment.center], the document layout
  /// creates an exclusion zone so adjacent blocks receive reduced-width
  /// constraints.  [TextWrapMode.none] causes the block to occupy a full
  /// vertical row.
  // ignore: diagnostic_describe_all_properties
  @override
  TextWrapMode get textWrap => _textWrap;

  /// Sets the text-wrap mode and schedules a layout pass.
  set textWrap(TextWrapMode value) {
    if (_textWrap == value) return;
    _textWrap = value;
    markNeedsLayout();
  }

  /// Adds the block layout properties to [properties] with default values.
  ///
  /// Call from [debugFillProperties] in concrete subclasses.
  void debugFillBlockLayoutProperties(DiagnosticPropertiesBuilder properties) {
    properties.add(EnumProperty<BlockAlignment>(
      'blockAlignment',
      _blockAlignment,
      defaultValue: BlockAlignment.stretch,
    ));
    properties.add(DiagnosticsProperty<BlockDimension?>(
      'widthDimension',
      _widthDimension,
      defaultValue: null,
    ));
    properties.add(DiagnosticsProperty<BlockDimension?>(
      'heightDimension',
      _heightDimension,
      defaultValue: null,
    ));
    properties.add(DoubleProperty('requestedWidth', _requestedWidth, defaultValue: null));
    properties.add(DoubleProperty('requestedHeight', _requestedHeight, defaultValue: null));
    properties
        .add(EnumProperty<TextWrapMode>('textWrap', _textWrap, defaultValue: TextWrapMode.none));
  }
}
