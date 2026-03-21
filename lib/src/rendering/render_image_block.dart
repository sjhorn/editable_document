/// Image block render object for the editable_document rendering layer.
///
/// Provides [RenderImageBlock], a [RenderDocumentBlock] that renders either a
/// decoded [dart:ui] image or a placeholder rectangle in place of the actual
/// image.  Actual image loading and lifecycle management is performed in the
/// widget layer; this render object does **not** dispose the image.
library;

import 'dart:ui' as ui show Image;

import 'package:flutter/rendering.dart';

import '../model/block_alignment.dart';
import '../model/block_border.dart';
import '../model/document_selection.dart';
import '../model/node_position.dart';
import '../model/text_wrap_mode.dart';
import 'block_layout_mixin.dart';
import 'render_document_block.dart';

/// Default aspect ratio used when no [imageWidth]/[imageHeight] is known and
/// no [image] has been provided.
const double _kDefaultAspectRatio = 16.0 / 9.0;

/// Inset from the right edge for the downstream caret position.
///
/// The caret painter draws a 2 px-wide rect starting at [Rect.left].
/// Without this inset, a downstream rect at `x = size.width` would overflow
/// the block bounds and get clipped by the viewport.
const double _kCaretInset = 2.0;

/// A [RenderDocumentBlock] for image nodes.
///
/// Renders a decoded [dart:ui.Image] when one is available, or a filled
/// placeholder rectangle sized according to the optional [imageWidth] and
/// [imageHeight] hints:
///
/// - When both dimensions are provided and the image fits within the layout
///   constraints, the block is exactly [imageWidth] × [imageHeight].
/// - When the image is wider than the available space, it is scaled down
///   uniformly to fit, preserving the aspect ratio.
/// - When only [requestedWidth] is set and an [image] is available, the height
///   is derived from the image's natural aspect ratio
///   (`width * image.height / image.width`).  When no image is available the
///   height falls back to a 16:9 ratio.
/// - When only [requestedHeight] is set and an [image] is available, the width
///   is derived from the image's natural aspect ratio
///   (`height * image.width / image.height`), clamped to constraints.  When no
///   image is available the block fills the available width.
/// - When no dimensions are provided but an [image] is set, the image's
///   intrinsic pixel dimensions are used (with the same scaling logic).
/// - When no dimensions are provided and no image is set, the block fills
///   the available width with a 16:9 aspect ratio.
///
/// Hit testing uses [BinaryNodePosition]: taps in the left half of the block
/// return [BinaryNodePosition.upstream] and taps in the right half return
/// [BinaryNodePosition.downstream].
///
/// ## Image lifecycle
///
/// This render object does **not** own the [image] — it neither decodes nor
/// disposes it.  The widget layer is responsible for obtaining the
/// [dart:ui.Image] (e.g. via [ImageStream]) and setting [image] on this
/// render object.  When the widget is disposed, the widget layer must also
/// dispose the [dart:ui.Image].
///
/// ## Accessibility
///
/// This block is a semantics boundary ([SemanticsConfiguration.isSemanticBoundary]
/// is `true`). Screen readers will announce the [altText] when provided, or the
/// default label `'Image'` when [altText] is `null`. The node is also marked
/// [SemanticsConfiguration.isImage] so assistive technologies recognise it as
/// an image element.
class RenderImageBlock extends RenderDocumentBlock with BlockLayoutMixin {
  /// Creates a [RenderImageBlock].
  ///
  /// [imageWidth] and [imageHeight] are the intrinsic dimensions of the image
  /// in logical pixels.  When omitted and no [image] is provided, a 16:9
  /// aspect ratio is used.
  /// [image] is an optional pre-decoded [dart:ui.Image].  When non-null and
  /// no explicit [imageWidth]/[imageHeight] are set, the image's own pixel
  /// dimensions are used for layout.
  /// [placeholderColor] is the fill color of the placeholder rectangle drawn
  /// when [image] is `null`.
  /// [altText] is the accessible description announced by screen readers; when
  /// `null` the block is labelled `'Image'`.
  /// [blockAlignment] controls how this block is positioned horizontally within
  /// the available layout width; defaults to [BlockAlignment.stretch].
  /// [requestedWidth] overrides the intrinsic image width for layout purposes;
  /// when non-null the block is sized to this width (clamped to constraints).
  /// [requestedHeight] overrides the intrinsic image height for layout purposes;
  /// when non-null the block is sized to this height.
  /// [textWrap] controls how surrounding text interacts with this block;
  /// defaults to [TextWrapMode.none].
  RenderImageBlock({
    required String nodeId,
    double? imageWidth,
    double? imageHeight,
    ui.Image? image,
    Color placeholderColor = const Color(0xFFE0E0E0),
    String? altText,
    BlockAlignment blockAlignment = BlockAlignment.stretch,
    double? requestedWidth,
    double? requestedHeight,
    TextWrapMode textWrap = TextWrapMode.none,
  })  : _nodeId = nodeId,
        _imageWidth = imageWidth,
        _imageHeight = imageHeight,
        _image = image,
        _placeholderColor = placeholderColor,
        _altText = altText {
    initBlockLayout(
      blockAlignment: blockAlignment,
      requestedWidth: requestedWidth,
      requestedHeight: requestedHeight,
      textWrap: textWrap,
    );
  }

  // ---------------------------------------------------------------------------
  // Private state
  // ---------------------------------------------------------------------------

  String _nodeId;
  double? _imageWidth;
  double? _imageHeight;
  ui.Image? _image;
  Color _placeholderColor;
  String? _altText;
  DocumentSelection? _nodeSelection;
  double? _spaceBefore;
  double? _spaceAfter;
  BlockBorder? _border;

  // ---------------------------------------------------------------------------
  // RenderDocumentBlock — nodeId
  // ---------------------------------------------------------------------------

  @override
  String get nodeId => _nodeId;

  @override
  set nodeId(String value) {
    if (_nodeId == value) return;
    _nodeId = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // RenderDocumentBlock — nodeSelection
  // ---------------------------------------------------------------------------

  @override
  DocumentSelection? get nodeSelection => _nodeSelection;

  @override
  set nodeSelection(DocumentSelection? value) {
    if (_nodeSelection == value) return;
    _nodeSelection = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // Public properties — described in debugFillProperties below.
  // ---------------------------------------------------------------------------

  /// The intrinsic width of the image in logical pixels, or `null`.
  // ignore: diagnostic_describe_all_properties
  double? get imageWidth => _imageWidth;

  /// Sets the intrinsic width and schedules a layout pass.
  set imageWidth(double? value) {
    if (_imageWidth == value) return;
    _imageWidth = value;
    markNeedsLayout();
  }

  /// The intrinsic height of the image in logical pixels, or `null`.
  // ignore: diagnostic_describe_all_properties
  double? get imageHeight => _imageHeight;

  /// Sets the intrinsic height and schedules a layout pass.
  set imageHeight(double? value) {
    if (_imageHeight == value) return;
    _imageHeight = value;
    markNeedsLayout();
  }

  /// The decoded image to paint, or `null` when no image has been loaded yet.
  ///
  /// When non-null and no explicit [imageWidth]/[imageHeight] are set, the
  /// image's pixel dimensions are used to size this block.
  ///
  /// This render object does **not** own the image — it does not dispose it.
  /// The widget layer is responsible for the image lifecycle.
  // ignore: diagnostic_describe_all_properties
  ui.Image? get image => _image;

  /// Sets the image.
  ///
  /// If the new image has different dimensions than the current one, a layout
  /// pass is scheduled so the block resizes to match the new intrinsic size.
  /// Otherwise only a paint pass is scheduled.
  ///
  /// Assigning the same instance is a no-op.
  set image(ui.Image? value) {
    if (identical(_image, value)) return;
    final oldW = _image?.width;
    final oldH = _image?.height;
    _image = value;
    final newW = _image?.width;
    final newH = _image?.height;
    if (oldW != newW || oldH != newH) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  /// The fill color of the placeholder rectangle.
  // ignore: diagnostic_describe_all_properties
  Color get placeholderColor => _placeholderColor;

  /// Sets the placeholder color and schedules a repaint.
  set placeholderColor(Color value) {
    if (_placeholderColor == value) return;
    _placeholderColor = value;
    markNeedsPaint();
  }

  /// The accessible text description of this image, or `null`.
  ///
  /// When non-null this string is used as the semantics label for the block.
  /// When `null` the block is labelled `'Image'` by default.
  ///
  /// Corresponds to [ImageNode.altText] in the model layer.
  // ignore: diagnostic_describe_all_properties
  String? get altText => _altText;

  /// The decoded image's pixel dimensions, or `null` when no image is loaded.
  ///
  /// Returns `Size(_image!.width.toDouble(), _image!.height.toDouble())` when
  /// a [dart:ui.Image] has been provided via [image], otherwise returns `null`.
  ///
  /// The widget layer uses this to compare the node's explicit
  /// [requestedWidth]/[requestedHeight] against the image's true resolution —
  /// for example, to decide whether to show a "Reset to original size" button.
  @override
  Size? get intrinsicContentSize {
    if (_image == null) return null;
    return Size(_image!.width.toDouble(), _image!.height.toDouble());
  }

  /// Extra space before this block in logical pixels, or `null` for default.
  ///
  /// When non-null, [RenderDocumentLayout] uses this value instead of
  /// [RenderDocumentLayout.blockSpacing] for the gap above this block.
  @override
  // ignore: diagnostic_describe_all_properties
  double? get spaceBefore => _spaceBefore;

  /// Sets [spaceBefore] and notifies the parent layout when the value changes.
  set spaceBefore(double? value) {
    if (_spaceBefore == value) return;
    _spaceBefore = value;
    if (parent is RenderObject) (parent!).markNeedsLayout();
  }

  /// Extra space after this block in logical pixels, or `null` for default.
  ///
  /// When non-null, [RenderDocumentLayout] uses this value instead of
  /// [RenderDocumentLayout.blockSpacing] for the gap below this block.
  @override
  // ignore: diagnostic_describe_all_properties
  double? get spaceAfter => _spaceAfter;

  /// Sets [spaceAfter] and notifies the parent layout when the value changes.
  set spaceAfter(double? value) {
    if (_spaceAfter == value) return;
    _spaceAfter = value;
    if (parent is RenderObject) (parent!).markNeedsLayout();
  }

  /// The outside border drawn around this block, or `null` for no border.
  ///
  /// When non-null, [RenderDocumentLayout] draws a border around this block
  /// using the specified style, width, and color.
  @override
  // ignore: diagnostic_describe_all_properties
  BlockBorder? get border => _border;

  /// Sets [border] and triggers a repaint when the value changes.
  set border(BlockBorder? value) {
    if (_border == value) return;
    _border = value;
    markNeedsPaint();
  }

  /// Sets the alt text and schedules a semantics update.
  set altText(String? value) {
    if (_altText == value) return;
    _altText = value;
    markNeedsSemanticsUpdate();
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  /// Computes the size of this block from the available [constraints].
  ///
  /// Resolution order (using the effective width = [requestedWidth] ??
  /// [imageWidth] and effective height = [requestedHeight] ?? [imageHeight]):
  ///
  /// 1. Both dimensions known — scale uniformly to fit [constraints].
  /// 2. Only width known — use that width (clamped); derive height from the
  ///    decoded [image]'s natural aspect ratio when available, or fall back
  ///    to 16:9.
  /// 3. Only height known — derive width from the decoded [image]'s natural
  ///    aspect ratio when available (clamped to [constraints]), or fall back
  ///    to filling the available width.
  /// 4. Neither dimension set but [image] available — use the image's pixel
  ///    dimensions (scaled to fit [constraints]).
  /// 5. No information — fill the available width with a 16:9 placeholder.
  @override
  void performLayout() {
    final maxW = constraints.maxWidth;
    final minW = constraints.minWidth;

    // When requestedWidth/requestedHeight are set, they override the intrinsic
    // dimensions from imageWidth/imageHeight or the decoded image's pixel size.
    final intrinsicW = requestedWidth ?? _imageWidth;
    final intrinsicH = requestedHeight ?? _imageHeight;

    if (intrinsicW != null && intrinsicH != null) {
      // Both dimensions are known — use them, scaling to fit constraints.
      final w = intrinsicW.clamp(minW, maxW);
      final scale = w / intrinsicW;
      size = Size(w, intrinsicH * scale);
    } else if (intrinsicW != null) {
      // Only width is known.  Use the image's natural aspect ratio when
      // available; otherwise fall back to 16:9.
      final w = intrinsicW.clamp(minW, maxW);
      if (_image != null) {
        final imageAspect = _image!.height.toDouble() / _image!.width.toDouble();
        size = Size(w, w * imageAspect);
      } else {
        size = Size(w, w / _kDefaultAspectRatio);
      }
    } else if (intrinsicH != null) {
      // Only height is known.  Use the image's natural aspect ratio when
      // available (clamped to constraints); otherwise fill the available width.
      if (_image != null) {
        final imageAspect = _image!.width.toDouble() / _image!.height.toDouble();
        final w = (intrinsicH * imageAspect).clamp(minW, maxW);
        size = Size(w, intrinsicH);
      } else {
        size = Size(maxW, intrinsicH);
      }
    } else if (_image != null) {
      // No explicit dimensions — derive from the decoded image's pixel size.
      final w = _image!.width.toDouble().clamp(minW, maxW);
      final scale = w / _image!.width.toDouble();
      size = Size(w, _image!.height.toDouble() * scale);
    } else {
      // No intrinsic size — fill width with a 16:9 placeholder.
      size = Size(maxW, maxW / _kDefaultAspectRatio);
    }
  }

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    final dst = offset & size;

    if (_image != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        _image!.width.toDouble(),
        _image!.height.toDouble(),
      );
      context.canvas.drawImageRect(_image!, src, dst, Paint());
    } else {
      final paint = Paint()..color = _placeholderColor;
      context.canvas.drawRect(dst, paint);
    }

    // Paint selection highlight if applicable.
    if (_nodeSelection != null) {
      final selPaint = Paint()..color = const Color(0x663399FF);
      context.canvas.drawRect(dst, selPaint);
    }
  }

  // ---------------------------------------------------------------------------
  // RenderDocumentBlock — geometry queries
  // ---------------------------------------------------------------------------

  @override
  Rect getLocalRectForPosition(NodePosition position) {
    assert(position is BinaryNodePosition, 'RenderImageBlock expects BinaryNodePosition');
    final bp = position as BinaryNodePosition;
    if (bp.type == BinaryNodePositionType.upstream) {
      // Before the image — full-height caret at the left edge.
      return Rect.fromLTWH(0, 0, 0, size.height);
    } else {
      // After the image — full-height caret at the right edge, inset by
      // [_kCaretInset] so the painted caret stays within the block bounds.
      final x = (size.width - _kCaretInset).clamp(0.0, size.width);
      return Rect.fromLTWH(x, 0, 0, size.height);
    }
  }

  @override
  NodePosition getPositionAtOffset(Offset localOffset) {
    if (localOffset.dx < size.width / 2) {
      return const BinaryNodePosition.upstream();
    } else {
      return const BinaryNodePosition.downstream();
    }
  }

  @override
  List<Rect> getEndpointsForSelection(NodePosition base, NodePosition extent) {
    // For a binary-position node, the selection is always the full block.
    return [Offset.zero & size];
  }

  // ---------------------------------------------------------------------------
  // Semantics
  // ---------------------------------------------------------------------------

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    config.isImage = true;
    config.label = _altText ?? 'Image';
    config.textDirection = TextDirection.ltr;
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('imageWidth', _imageWidth, defaultValue: null));
    properties.add(DoubleProperty('imageHeight', _imageHeight, defaultValue: null));
    properties.add(ColorProperty('placeholderColor', _placeholderColor));
    properties.add(StringProperty('altText', _altText, defaultValue: null));
    properties.add(DiagnosticsProperty<ui.Image?>('image', _image, defaultValue: null));
    properties.add(DoubleProperty('spaceBefore', _spaceBefore, defaultValue: null));
    properties.add(DoubleProperty('spaceAfter', _spaceAfter, defaultValue: null));
    properties.add(DiagnosticsProperty<BlockBorder?>('border', _border, defaultValue: null));
    debugFillBlockLayoutProperties(properties);
  }
}
