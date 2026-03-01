/// [DocumentLayout] widget and related types for the editable_document package.
///
/// This file provides [DocumentLayout], a [StatefulWidget] that maps each
/// [DocumentNode] in a [MutableDocument] to a rendered block widget via
/// [ComponentBuilder]s, and lays them out using [RenderDocumentLayout].
///
/// The state object [DocumentLayoutState] exposes geometry query methods that
/// delegate to the underlying [RenderDocumentLayout]:
///
/// - [DocumentLayoutState.componentForNode] — returns the [RenderDocumentBlock]
///   for a given node id.
/// - [DocumentLayoutState.rectForDocumentPosition] — converts a
///   [DocumentPosition] to a [Rect] in local coordinates.
/// - [DocumentLayoutState.documentPositionAtOffset] — hit-tests a local offset
///   and returns the nearest [DocumentPosition], or `null`.
/// - [DocumentLayoutState.documentPositionNearestToOffset] — always returns a
///   [DocumentPosition], clamping when the offset is outside all children.
/// - [DocumentLayoutState.computeMaxScrollExtent] — returns the maximum scroll
///   offset for a given viewport height.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../model/document.dart';
import '../model/document_editing_controller.dart';
import '../model/document_position.dart';
import '../model/mutable_document.dart';
import '../rendering/render_document_block.dart';
import '../rendering/render_document_layout.dart';
import 'component_builder.dart';

// ---------------------------------------------------------------------------
// DocumentLayout
// ---------------------------------------------------------------------------

/// A widget that renders a [MutableDocument] as a vertical stack of block
/// components.
///
/// Each [DocumentNode] in the document is converted to a widget via the
/// [componentBuilders] list (first non-null result wins). The resulting
/// widgets are arranged by [RenderDocumentLayout] using [blockSpacing] pixels
/// of vertical gap between consecutive blocks.
///
/// [DocumentLayout] listens to [document.changes] and [controller] so it
/// rebuilds whenever the document structure or selection changes.
///
/// Access geometry queries through [DocumentLayoutState] using a [GlobalKey]:
///
/// ```dart
/// final layoutKey = GlobalKey<DocumentLayoutState>();
///
/// DocumentLayout(
///   key: layoutKey,
///   document: myDocument,
///   controller: myController,
///   componentBuilders: defaultComponentBuilders,
/// )
///
/// // Later:
/// final rect = layoutKey.currentState!.rectForDocumentPosition(position);
/// ```
class DocumentLayout extends StatefulWidget {
  /// Creates a [DocumentLayout].
  ///
  /// [document] is the [MutableDocument] to render. [controller] provides the
  /// current selection and notifies the layout of selection changes.
  /// [componentBuilders] is the ordered list of builders used to create block
  /// widgets; the first builder that handles a node type wins.
  ///
  /// [blockSpacing] is the vertical gap between consecutive blocks (default
  /// `12.0`). [stylesheet] is an optional map of style-key strings to
  /// [TextStyle]s passed to every [ComponentContext].
  const DocumentLayout({
    super.key,
    required this.document,
    required this.controller,
    required this.componentBuilders,
    this.blockSpacing = 12.0,
    this.stylesheet,
  });

  /// The document whose nodes are rendered.
  final MutableDocument document;

  /// The editing controller that holds the current selection.
  final DocumentEditingController controller;

  /// The ordered list of [ComponentBuilder]s used to create block widgets.
  ///
  /// Builders are tried in list order; the first non-null result wins.
  /// Prepend custom builders to override defaults for specific node types.
  final List<ComponentBuilder> componentBuilders;

  /// The vertical gap in logical pixels between consecutive block children.
  ///
  /// Defaults to `12.0`. No spacing is added before the first child or after
  /// the last child.
  final double blockSpacing;

  /// An optional map of style-key strings to [TextStyle]s.
  ///
  /// Passed to every [ComponentContext] so builders can apply consistent
  /// typography using well-known keys such as `'body'`, `'h1'`, or `'code'`.
  final Map<String, TextStyle>? stylesheet;

  @override
  State<DocumentLayout> createState() => DocumentLayoutState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Document>('document', document));
    properties.add(DiagnosticsProperty<DocumentEditingController>('controller', controller));
    properties.add(IntProperty('componentBuilders', componentBuilders.length));
    properties.add(DoubleProperty('blockSpacing', blockSpacing));
    properties.add(DiagnosticsProperty<Map<String, TextStyle>>('stylesheet', stylesheet));
  }
}

// ---------------------------------------------------------------------------
// DocumentLayoutState
// ---------------------------------------------------------------------------

/// State object for [DocumentLayout].
///
/// Exposes geometry queries that delegate to the underlying
/// [RenderDocumentLayout]. Manages listeners on [DocumentLayout.document] and
/// [DocumentLayout.controller] so the widget tree stays in sync.
class DocumentLayoutState extends State<DocumentLayout> {
  // The render-widget key is kept stable across rebuilds so Flutter can
  // compare old and new child lists efficiently.
  final _renderWidgetKey = GlobalKey();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    widget.document.changes.addListener(_onDocumentChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(DocumentLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.document, widget.document)) {
      oldWidget.document.changes.removeListener(_onDocumentChanged);
      widget.document.changes.addListener(_onDocumentChanged);
    }
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.document.changes.removeListener(_onDocumentChanged);
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Change handlers
  // ---------------------------------------------------------------------------

  void _onDocumentChanged() {
    setState(() {
      // Rebuild child list to reflect inserted/deleted/replaced nodes.
    });
  }

  void _onControllerChanged() {
    setState(() {
      // Rebuild child list to update selection-related view models.
    });
  }

  // ---------------------------------------------------------------------------
  // Geometry queries — delegate to RenderDocumentLayout
  // ---------------------------------------------------------------------------

  /// Returns the [RenderDocumentBlock] for [nodeId], or `null` if no rendered
  /// block matches.
  RenderDocumentBlock? componentForNode(String nodeId) {
    return _renderObject?.getComponentByNodeId(nodeId);
  }

  /// Returns the [Rect], in [DocumentLayout]'s local coordinates, for
  /// [position], or `null` if [position.nodeId] is not rendered.
  Rect? rectForDocumentPosition(DocumentPosition position) {
    return _renderObject?.getRectForDocumentPosition(position);
  }

  /// Returns the [DocumentPosition] at [localOffset], or `null` if the offset
  /// falls outside all rendered blocks (e.g. in a gap or past the last block).
  DocumentPosition? documentPositionAtOffset(Offset localOffset) {
    return _renderObject?.getDocumentPositionAtOffset(localOffset);
  }

  /// Returns the [DocumentPosition] nearest to [localOffset].
  ///
  /// Always returns a valid position by clamping to the nearest block when the
  /// offset falls outside all rendered children.
  ///
  /// Throws [StateError] when called on an empty document.
  DocumentPosition documentPositionNearestToOffset(Offset localOffset) {
    final ro = _renderObject;
    if (ro == null) {
      throw StateError('documentPositionNearestToOffset called before layout');
    }
    return ro.getDocumentPositionNearestToOffset(localOffset);
  }

  /// Returns the maximum scroll offset for a viewport of [viewportHeight]
  /// pixels.
  ///
  /// Returns `0.0` when called before the first layout.
  double computeMaxScrollExtent(double viewportHeight) {
    return _renderObject?.computeMaxScrollExtent(viewportHeight) ?? 0.0;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Retrieves the underlying [RenderDocumentLayout] via the render-widget key.
  RenderDocumentLayout? get _renderObject {
    final ctx = _renderWidgetKey.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is RenderDocumentLayout) return ro;
    return null;
  }

  /// Builds the ordered list of child widgets for the current document state.
  List<Widget> _buildChildren() {
    final selection = widget.controller.selection;
    final context = ComponentContext(
      document: widget.document,
      selection: selection,
      stylesheet: widget.stylesheet,
    );

    final children = <Widget>[];
    for (final node in widget.document.nodes) {
      // Try each builder in order; first non-null result wins.
      Widget? child;
      for (final builder in widget.componentBuilders) {
        final vm = builder.createViewModel(widget.document, node);
        if (vm == null) continue;
        child = builder.createComponent(vm, context);
        if (child != null) break;
      }
      if (child != null) {
        children.add(child);
      }
    }
    return children;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return _DocumentLayoutRenderWidget(
      key: _renderWidgetKey,
      blockSpacing: widget.blockSpacing,
      children: _buildChildren(),
    );
  }
}

// ---------------------------------------------------------------------------
// _DocumentLayoutRenderWidget
// ---------------------------------------------------------------------------

/// A [MultiChildRenderObjectWidget] that creates and updates a
/// [RenderDocumentLayout].
///
/// This is an implementation detail of [DocumentLayout] and is not part of the
/// public API.
class _DocumentLayoutRenderWidget extends MultiChildRenderObjectWidget {
  const _DocumentLayoutRenderWidget({
    super.key,
    required this.blockSpacing,
    super.children,
  });

  final double blockSpacing;

  @override
  RenderDocumentLayout createRenderObject(BuildContext context) {
    return RenderDocumentLayout(blockSpacing: blockSpacing);
  }

  @override
  void updateRenderObject(BuildContext context, RenderDocumentLayout renderObject) {
    renderObject.blockSpacing = blockSpacing;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('blockSpacing', blockSpacing));
  }
}

// ---------------------------------------------------------------------------
// DocumentLayoutElement
// ---------------------------------------------------------------------------

/// The [Element] produced by [_DocumentLayoutRenderWidget].
///
/// Extends [MultiChildRenderObjectElement] to inherit standard multi-child
/// reconciliation. The name is exposed for widget inspector visibility.
class DocumentLayoutElement extends MultiChildRenderObjectElement {
  /// Creates a [DocumentLayoutElement] for [widget].
  DocumentLayoutElement(_DocumentLayoutRenderWidget super.widget);
}
