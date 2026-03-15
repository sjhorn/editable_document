/// Render object that paints a block selection border and resize handles at
/// paint time.
///
/// [RenderBlockResizeBorder] queries [RenderDocumentLayout] during [paint] to
/// obtain the geometry for the selected block, so no pre-computed geometry is
/// required by the widget layer and there is no one-frame lag during viewport
/// resize.
library;

import 'package:flutter/rendering.dart';

import 'render_document_block.dart';
import 'render_document_layout.dart';

// ---------------------------------------------------------------------------
// RenderBlockResizeBorder
// ---------------------------------------------------------------------------

/// A [RenderBox] that paints a 1-px selection border and optional resize
/// handle squares around a single document block by querying
/// [RenderDocumentLayout] at paint time.
///
/// Place this render object as an overlay that covers the same area as the
/// [RenderDocumentLayout] it references.  During [paint] it resolves the
/// block rect from [documentLayout] using [selectedNodeId] and draws:
///
/// - A 1-px stroked rectangle in [borderColor].
/// - Eight filled squares (4 corners + 4 edge midpoints) in [handleColor]
///   when [showHandles] is `true`.
///
/// ## Drag preview
///
/// When [dragPreviewRect] is non-null, the border and handles are painted
/// using that rect directly instead of querying [documentLayout].  This lets
/// the widget layer supply the live geometry during a resize drag without
/// waiting for layout.
///
/// ## When nothing is drawn
///
/// [paint] is a no-op when any of the following conditions hold (and
/// [dragPreviewRect] is also null):
/// - [documentLayout] is `null`
/// - [selectedNodeId] is `null`
/// - [documentLayout] returns `null` for [selectedNodeId] (node not found)
///
/// ## Hit testing
///
/// [hitTestSelf] always returns `false`; the overlay is invisible to pointer
/// events.
///
/// Example:
/// ```dart
/// final resizeBorder = RenderBlockResizeBorder(
///   documentLayout: myLayout,
///   selectedNodeId: 'image1',
///   borderColor: const Color(0xFF2196F3),
///   handleColor: const Color(0xFF2196F3),
/// );
/// ```
class RenderBlockResizeBorder extends RenderBox {
  /// Creates a [RenderBlockResizeBorder] with optional initial values.
  ///
  /// [borderColor] and [handleColor] default to `Color(0xFF2196F3)` (Material
  /// blue), [handleSize] to `8.0`, and [showHandles] to `true`.
  RenderBlockResizeBorder({
    RenderDocumentLayout? documentLayout,
    String? selectedNodeId,
    Color borderColor = const Color(0xFF2196F3),
    Color handleColor = const Color(0xFF2196F3),
    double handleSize = 8.0,
    bool showHandles = true,
    Rect? dragPreviewRect,
  })  : _documentLayout = documentLayout,
        _selectedNodeId = selectedNodeId,
        _borderColor = borderColor,
        _handleColor = handleColor,
        _handleSize = handleSize,
        _showHandles = showHandles,
        _dragPreviewRect = dragPreviewRect;

  // ---------------------------------------------------------------------------
  // documentLayout
  // ---------------------------------------------------------------------------

  RenderDocumentLayout? _documentLayout;

  /// The [RenderDocumentLayout] to query for block geometry.
  ///
  /// When `null` and [dragPreviewRect] is also `null`, [paint] is a no-op.
  // ignore: diagnostic_describe_all_properties
  RenderDocumentLayout? get documentLayout => _documentLayout;

  /// Sets [documentLayout] and schedules a repaint when the value changes.
  set documentLayout(RenderDocumentLayout? value) {
    if (identical(_documentLayout, value)) return;
    _documentLayout = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // selectedNodeId
  // ---------------------------------------------------------------------------

  String? _selectedNodeId;

  /// The node id of the block to outline.
  ///
  /// When `null` and [dragPreviewRect] is also `null`, [paint] is a no-op.
  // ignore: diagnostic_describe_all_properties
  String? get selectedNodeId => _selectedNodeId;

  /// Sets [selectedNodeId] and schedules a repaint when the value changes.
  set selectedNodeId(String? value) {
    if (_selectedNodeId == value) return;
    _selectedNodeId = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // borderColor
  // ---------------------------------------------------------------------------

  Color _borderColor;

  /// The stroke colour used to draw the selection border rectangle.
  // ignore: diagnostic_describe_all_properties
  Color get borderColor => _borderColor;

  /// Sets [borderColor] and schedules a repaint when the value changes.
  set borderColor(Color value) {
    if (_borderColor == value) return;
    _borderColor = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // handleColor
  // ---------------------------------------------------------------------------

  Color _handleColor;

  /// The fill colour used to draw each resize handle square.
  // ignore: diagnostic_describe_all_properties
  Color get handleColor => _handleColor;

  /// Sets [handleColor] and schedules a repaint when the value changes.
  set handleColor(Color value) {
    if (_handleColor == value) return;
    _handleColor = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // handleSize
  // ---------------------------------------------------------------------------

  double _handleSize;

  /// The side length in logical pixels of each resize handle square.
  ///
  /// Defaults to `8.0`.
  // ignore: diagnostic_describe_all_properties
  double get handleSize => _handleSize;

  /// Sets [handleSize] and schedules a repaint when the value changes.
  set handleSize(double value) {
    if (_handleSize == value) return;
    _handleSize = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // showHandles
  // ---------------------------------------------------------------------------

  bool _showHandles;

  /// Whether to paint the eight resize handle squares around the border.
  ///
  /// When `false`, only the 1-px border rectangle is drawn.
  /// Defaults to `true`.
  // ignore: diagnostic_describe_all_properties
  bool get showHandles => _showHandles;

  /// Sets [showHandles] and schedules a repaint when the value changes.
  set showHandles(bool value) {
    if (_showHandles == value) return;
    _showHandles = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // dragPreviewRect
  // ---------------------------------------------------------------------------

  Rect? _dragPreviewRect;

  /// When non-null, the border and handles are painted using this rect instead
  /// of querying [documentLayout].
  ///
  /// Use this during a resize drag to supply live geometry without waiting for
  /// a layout pass.  Set to `null` when the drag ends.
  // ignore: diagnostic_describe_all_properties
  Rect? get dragPreviewRect => _dragPreviewRect;

  /// Sets [dragPreviewRect] and schedules a repaint when the value changes.
  set dragPreviewRect(Rect? value) {
    if (_dragPreviewRect == value) return;
    _dragPreviewRect = value;
    markNeedsPaint();
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  void performLayout() {
    size = constraints.biggest;
  }

  // ---------------------------------------------------------------------------
  // Hit testing
  // ---------------------------------------------------------------------------

  @override
  bool hitTestSelf(Offset position) => false;

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    final Rect? blockRect;

    if (_dragPreviewRect != null) {
      // During drag: use the caller-supplied preview rect directly.
      blockRect = _dragPreviewRect;
    } else {
      // Normal (non-drag): query layout at paint time.
      final layout = _documentLayout;
      final nodeId = _selectedNodeId;
      if (layout == null || nodeId == null) return;

      final RenderDocumentBlock? renderBlock = layout.getComponentByNodeId(nodeId);
      if (renderBlock == null) return;

      // Convert the block's top-left from block-local to layout-local coords.
      // Use parentData.offset directly — it is cheaper than localToGlobal and
      // works even when the render objects are not attached to a pipeline owner
      // (e.g. in unit tests).
      final parentData = renderBlock.parentData;
      final Offset blockOffsetInLayout;
      if (parentData is DocumentBlockParentData) {
        blockOffsetInLayout = parentData.offset;
      } else if (renderBlock.attached) {
        blockOffsetInLayout = renderBlock.localToGlobal(Offset.zero, ancestor: layout);
      } else {
        return;
      }
      blockRect = blockOffsetInLayout & renderBlock.size;
    }

    if (blockRect == null) return;

    final canvas = context.canvas;
    final shiftedRect = blockRect.shift(offset);

    // --- Border ---
    canvas.drawRect(
      shiftedRect,
      Paint()
        ..color = _borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // --- Handles ---
    if (_showHandles) {
      _paintHandles(canvas, shiftedRect);
    }
  }

  /// Paints the 8 resize handle squares around [rect].
  ///
  /// Handle positions: top-left, top-center, top-right, middle-left,
  /// middle-right, bottom-left, bottom-center, bottom-right.
  void _paintHandles(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = _handleColor
      ..style = PaintingStyle.fill;

    final positions = [
      // corners
      Offset(rect.left, rect.top), // topLeft
      Offset(rect.center.dx, rect.top), // topCenter
      Offset(rect.right, rect.top), // topRight
      Offset(rect.left, rect.center.dy), // middleLeft
      Offset(rect.right, rect.center.dy), // middleRight
      Offset(rect.left, rect.bottom), // bottomLeft
      Offset(rect.center.dx, rect.bottom), // bottomCenter
      Offset(rect.right, rect.bottom), // bottomRight
    ];

    for (final pos in positions) {
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: _handleSize, height: _handleSize),
        paint,
      );
    }

    // Draw border on top of filled handles so they have a crisp edge.
    final borderPaint = Paint()
      ..color = _borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final pos in positions) {
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: _handleSize, height: _handleSize),
        borderPaint,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<RenderDocumentLayout?>(
      'documentLayout',
      _documentLayout,
      defaultValue: null,
    ));
    properties.add(StringProperty('selectedNodeId', _selectedNodeId, defaultValue: null));
    properties.add(ColorProperty('borderColor', _borderColor));
    properties.add(ColorProperty('handleColor', _handleColor));
    properties.add(DoubleProperty('handleSize', _handleSize));
    properties.add(DiagnosticsProperty<bool>('showHandles', _showHandles));
    properties.add(DiagnosticsProperty<Rect?>(
      'dragPreviewRect',
      _dragPreviewRect,
      defaultValue: null,
    ));
  }
}
