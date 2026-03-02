/// Image block render object for the editable_document rendering layer.
///
/// Provides [RenderImageBlock], a [RenderDocumentBlock] that renders a
/// placeholder rectangle in place of the actual image.  Actual image loading
/// is performed in the widget layer.
library;

import 'package:flutter/rendering.dart';

import '../model/document_selection.dart';
import '../model/node_position.dart';
import 'render_document_block.dart';

/// Default aspect ratio used when no [imageWidth]/[imageHeight] is known.
const double _kDefaultAspectRatio = 16.0 / 9.0;

/// Default caret height used for binary-position nodes.
///
/// Matches a typical text line height so the caret looks consistent when
/// navigating between text blocks and image blocks.
const double _kCaretHeight = 20.0;

/// A [RenderDocumentBlock] for image nodes.
///
/// Renders a filled placeholder rectangle sized according to the optional
/// [imageWidth] and [imageHeight] hints:
///
/// - When both dimensions are provided and the image fits within the layout
///   constraints, the block is exactly [imageWidth] × [imageHeight].
/// - When the image is wider than the available space, it is scaled down
///   uniformly to fit, preserving the aspect ratio.
/// - When no dimensions are provided, the block fills the available width
///   with a 16:9 aspect ratio.
///
/// Hit testing uses [BinaryNodePosition]: taps in the left half of the block
/// return [BinaryNodePosition.upstream] and taps in the right half return
/// [BinaryNodePosition.downstream].
class RenderImageBlock extends RenderDocumentBlock {
  /// Creates a [RenderImageBlock].
  ///
  /// [imageWidth] and [imageHeight] are the intrinsic dimensions of the image
  /// in logical pixels.  When omitted, a 16:9 aspect ratio is used.
  /// [placeholderColor] is the fill color of the placeholder rectangle.
  RenderImageBlock({
    required String nodeId,
    double? imageWidth,
    double? imageHeight,
    Color placeholderColor = const Color(0xFFE0E0E0),
  })  : _nodeId = nodeId,
        _imageWidth = imageWidth,
        _imageHeight = imageHeight,
        _placeholderColor = placeholderColor;

  // ---------------------------------------------------------------------------
  // Private state
  // ---------------------------------------------------------------------------

  String _nodeId;
  double? _imageWidth;
  double? _imageHeight;
  Color _placeholderColor;
  DocumentSelection? _nodeSelection;

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

  /// The fill color of the placeholder rectangle.
  // ignore: diagnostic_describe_all_properties
  Color get placeholderColor => _placeholderColor;

  /// Sets the placeholder color and schedules a repaint.
  set placeholderColor(Color value) {
    if (_placeholderColor == value) return;
    _placeholderColor = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    final maxW = constraints.maxWidth;

    if (_imageWidth != null && _imageHeight != null) {
      final w = _imageWidth!;
      final h = _imageHeight!;
      if (w <= maxW) {
        // Image fits — use its exact size.
        size = Size(w, h);
      } else {
        // Scale down to fit, preserving aspect ratio.
        final scale = maxW / w;
        size = Size(maxW, h * scale);
      }
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
    final paint = Paint()..color = _placeholderColor;
    context.canvas.drawRect(offset & size, paint);

    // Paint selection highlight if applicable.
    if (_nodeSelection != null) {
      final selPaint = Paint()..color = const Color(0x663399FF);
      context.canvas.drawRect(offset & size, selPaint);
    }
  }

  // ---------------------------------------------------------------------------
  // RenderDocumentBlock — geometry queries
  // ---------------------------------------------------------------------------

  @override
  Rect getLocalRectForPosition(NodePosition position) {
    assert(position is BinaryNodePosition, 'RenderImageBlock expects BinaryNodePosition');
    final bp = position as BinaryNodePosition;
    final caretHeight = size.height.clamp(0.0, _kCaretHeight);
    if (bp.type == BinaryNodePositionType.upstream) {
      // Before the image — caret at the top-left edge.
      return Rect.fromLTWH(0, 0, 0, caretHeight);
    } else {
      // After the image — caret at the bottom-left edge.
      return Rect.fromLTWH(0, size.height - caretHeight, 0, caretHeight);
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
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('imageWidth', _imageWidth, defaultValue: null));
    properties.add(DoubleProperty('imageHeight', _imageHeight, defaultValue: null));
    properties.add(ColorProperty('placeholderColor', _placeholderColor));
  }
}
