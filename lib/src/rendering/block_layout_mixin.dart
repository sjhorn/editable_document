/// Block layout mixin for the editable_document rendering layer.
///
/// Provides [BlockLayoutMixin], a mixin on [RenderDocumentBlock] that
/// implements the four common layout property fields: [blockAlignment],
/// [requestedWidth], [requestedHeight], and [textWrap].
library;

import 'package:flutter/rendering.dart';

import '../model/block_alignment.dart';
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
/// ```dart
/// class RenderMyBlock extends RenderDocumentBlock with BlockLayoutMixin {
///   RenderMyBlock({
///     BlockAlignment blockAlignment = BlockAlignment.stretch,
///     double? requestedWidth,
///   }) {
///     initBlockLayout(
///       blockAlignment: blockAlignment,
///       requestedWidth: requestedWidth,
///     );
///   }
/// }
/// ```
mixin BlockLayoutMixin on RenderDocumentBlock {
  BlockAlignment _blockAlignment = BlockAlignment.stretch;
  double? _requestedWidth;
  double? _requestedHeight;
  bool _textWrap = false;

  /// Sets initial block layout values without triggering [markNeedsLayout].
  ///
  /// Call this from the constructor body. Because the render object has not
  /// been attached to the tree yet, calling [markNeedsLayout] would be
  /// premature.
  void initBlockLayout({
    BlockAlignment blockAlignment = BlockAlignment.stretch,
    double? requestedWidth,
    double? requestedHeight,
    bool textWrap = false,
  }) {
    _blockAlignment = blockAlignment;
    _requestedWidth = requestedWidth;
    _requestedHeight = requestedHeight;
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

  /// The requested width of this block in logical pixels, or `null`.
  ///
  /// When non-null, the document layout uses this value instead of the full
  /// available width.  When `null`, the block fills the available width.
  // ignore: diagnostic_describe_all_properties
  @override
  double? get requestedWidth => _requestedWidth;

  /// Sets the requested width and schedules a layout pass.
  set requestedWidth(double? value) {
    if (_requestedWidth == value) return;
    _requestedWidth = value;
    markNeedsLayout();
  }

  /// The requested height of this block in logical pixels, or `null`.
  ///
  /// When non-null, the document layout uses this value to constrain the
  /// block height.  When `null`, the block uses its intrinsic height.
  // ignore: diagnostic_describe_all_properties
  @override
  double? get requestedHeight => _requestedHeight;

  /// Sets the requested height and schedules a layout pass.
  set requestedHeight(double? value) {
    if (_requestedHeight == value) return;
    _requestedHeight = value;
    markNeedsLayout();
  }

  /// Whether subsequent blocks should wrap around this block.
  ///
  /// When `true` and [blockAlignment] is [BlockAlignment.start] or
  /// [BlockAlignment.end], the document layout creates an exclusion zone so
  /// adjacent blocks receive reduced-width constraints.
  // ignore: diagnostic_describe_all_properties
  @override
  bool get textWrap => _textWrap;

  /// Sets the text-wrap flag and schedules a layout pass.
  set textWrap(bool value) {
    if (_textWrap == value) return;
    _textWrap = value;
    markNeedsLayout();
  }

  /// Adds the four block layout properties to [properties] with default values.
  ///
  /// Call from [debugFillProperties] in concrete subclasses.
  void debugFillBlockLayoutProperties(DiagnosticPropertiesBuilder properties) {
    properties.add(EnumProperty<BlockAlignment>(
      'blockAlignment',
      _blockAlignment,
      defaultValue: BlockAlignment.stretch,
    ));
    properties.add(DoubleProperty('requestedWidth', _requestedWidth, defaultValue: null));
    properties.add(DoubleProperty('requestedHeight', _requestedHeight, defaultValue: null));
    properties.add(FlagProperty('textWrap', value: _textWrap, ifTrue: 'textWrap'));
  }
}
