/// A composed property panel that shows editors for the selected document block.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/blockquote_node.dart';
import '../../model/block_alignment.dart';
import '../../model/block_border.dart';
import '../../model/block_dimension.dart';
import '../../model/code_block_node.dart';
import '../../model/document_editing_controller.dart';
import '../../model/document_node.dart';
import '../../model/edit_request.dart';
import '../../model/horizontal_rule_node.dart';
import '../../model/image_node.dart';
import '../../model/list_item_node.dart';
import '../../model/paragraph_node.dart';
import '../../model/table_node.dart';
import '../../model/text_wrap_mode.dart';
import 'block_alignment_editor.dart';
import 'block_border_editor.dart';
import 'block_dimension_editor.dart';
import 'image_properties_editor.dart';
import 'indent_editor.dart';
import 'line_height_editor.dart';
import 'property_section.dart';
import 'spacing_editor.dart';
import 'text_alignment_editor.dart';
import 'text_wrap_editor.dart';

// ---------------------------------------------------------------------------
// DocumentPropertyPanel
// ---------------------------------------------------------------------------

/// A panel that displays property editors for the currently selected block.
///
/// Automatically determines which editors to show based on the selected
/// node type. Uses [DocumentEditingController] for reading state and calls
/// [requestHandler] with appropriate [EditRequest]s when properties change.
///
/// Listens to [controller] via [ListenableBuilder] and rebuilds whenever the
/// selection or document changes.
///
/// ```dart
/// DocumentPropertyPanel(
///   controller: controller,
///   requestHandler: (request) => editor.submit(request),
///   onPickImageFile: () => pickImageFile(),
/// )
/// ```
class DocumentPropertyPanel extends StatelessWidget {
  /// Creates a [DocumentPropertyPanel].
  const DocumentPropertyPanel({
    super.key,
    required this.controller,
    required this.requestHandler,
    this.width = 280.0,
    this.onPickImageFile,
  });

  /// The document editing controller to listen to for selection and document state.
  final DocumentEditingController controller;

  /// Called with an [EditRequest] whenever the user changes a property.
  final void Function(EditRequest) requestHandler;

  /// The preferred width of the panel. Defaults to `280.0`.
  final double width;

  /// Called when the user taps the "Choose File" button in the image editor.
  ///
  /// When `null`, the button is not shown.
  final VoidCallback? onPickImageFile;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selection = controller.selection;
        if (selection == null) return const SizedBox.shrink();

        final nodeId = selection.extent.nodeId;
        final node = controller.document.nodeById(nodeId);
        if (node == null) return const SizedBox.shrink();

        return SizedBox(
          width: width,
          child: _NodePropertyContent(
            node: node,
            onRequest: requestHandler,
            onPickImageFile: onPickImageFile,
          ),
        );
      },
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
    properties.add(DoubleProperty('width', width, defaultValue: 280.0));
    properties.add(ObjectFlagProperty<VoidCallback?>.has('onPickImageFile', onPickImageFile));
  }
}

// ---------------------------------------------------------------------------
// _NodePropertyContent
// ---------------------------------------------------------------------------

/// Builds the property editors for a specific [DocumentNode].
class _NodePropertyContent extends StatelessWidget {
  const _NodePropertyContent({
    required this.node,
    required this.onRequest,
    this.onPickImageFile,
  });

  // ignore: diagnostic_describe_all_properties
  final DocumentNode node;
  // ignore: diagnostic_describe_all_properties
  final void Function(EditRequest) onRequest;
  // ignore: diagnostic_describe_all_properties
  final VoidCallback? onPickImageFile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildSections(context),
        ),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final n = node;

    final isText = n is ParagraphNode || n is ListItemNode || n is BlockquoteNode;
    final isTextOrCode = isText || n is CodeBlockNode;
    final isContainer =
        n is BlockquoteNode || n is CodeBlockNode || n is ImageNode || n is HorizontalRuleNode;
    final hasSpacing = n is ParagraphNode ||
        n is ListItemNode ||
        n is BlockquoteNode ||
        n is CodeBlockNode ||
        n is ImageNode ||
        n is HorizontalRuleNode ||
        n is TableNode;
    final hasBorder = hasSpacing;
    final hasIndent = n is ParagraphNode || n is ListItemNode || n is BlockquoteNode;
    final hasDimensions =
        n is BlockquoteNode || n is CodeBlockNode || n is ImageNode || n is HorizontalRuleNode;

    return [
      if (isText)
        PropertySection(
          label: 'Text Alignment',
          child: TextAlignmentEditor(
            value: _textAlign,
            onChanged: (align) => onRequest(
              ChangeTextAlignRequest(nodeId: n.id, newTextAlign: align),
            ),
          ),
        ),
      if (isTextOrCode)
        PropertySection(
          label: 'Line Height',
          child: LineHeightEditor(
            value: _lineHeight,
            onChanged: (h) => onRequest(
              ChangeLineHeightRequest(nodeId: n.id, newLineHeight: h),
            ),
          ),
        ),
      if (hasSpacing)
        PropertySection(
          label: 'Spacing',
          child: SpacingEditor(
            spaceBefore: _spaceBefore,
            spaceAfter: _spaceAfter,
            onSpaceBeforeChanged: (v) => _handleSpacingChange(spaceBeforeOverride: v),
            onSpaceAfterChanged: (v) => _handleSpacingChange(spaceAfterOverride: v),
          ),
        ),
      if (hasBorder)
        PropertySection(
          label: 'Border',
          child: BlockBorderEditor(
            border: _border,
            onChanged: (border) => _handleBorderChange(border),
          ),
        ),
      if (hasIndent)
        PropertySection(
          label: 'Indent',
          child: IndentEditor(
            indentLeft: _indentLeft,
            indentRight: _indentRight,
            firstLineIndent: _firstLineIndent,
            onIndentLeftChanged: (v) => _handleIndentChange(
              indentLeft: v,
              indentRight: _indentRight,
              firstLineIndent: _firstLineIndent,
            ),
            onIndentRightChanged: (v) => _handleIndentChange(
              indentLeft: _indentLeft,
              indentRight: v,
              firstLineIndent: _firstLineIndent,
            ),
            onFirstLineIndentChanged: (v) => _handleIndentChange(
              indentLeft: _indentLeft,
              indentRight: _indentRight,
              firstLineIndent: v,
            ),
            showFirstLine: n is! ListItemNode,
          ),
        ),
      if (isContainer)
        PropertySection(
          label: 'Block Alignment',
          child: BlockAlignmentEditor(
            value: _blockAlignment,
            onChanged: (align) => _handleBlockAlignmentChange(align),
          ),
        ),
      if (hasDimensions) ...[
        PropertySection(
          label: 'Text Wrap',
          child: TextWrapEditor(
            value: _textWrap,
            onChanged: (mode) => _handleTextWrapChange(mode),
          ),
        ),
        PropertySection(
          label: 'Width \u00d7 Height',
          child: BlockDimensionEditor(
            width: _width,
            height: _height,
            onWidthChanged: (w) => _handleWidthChange(w),
            onHeightChanged: (h) => _handleHeightChange(h),
          ),
        ),
      ],
      if (n is ImageNode)
        PropertySection(
          label: 'Image',
          child: ImagePropertiesEditor(
            imageUrl: n.imageUrl,
            lockAspect: n.lockAspect,
            onUrlChanged: (url) => onRequest(
              ReplaceNodeRequest(
                nodeId: n.id,
                newNode: ImageNode(
                  id: n.id,
                  imageUrl: url,
                  altText: n.altText,
                  width: n.width,
                  height: n.height,
                  alignment: n.alignment,
                  textWrap: n.textWrap,
                  lockAspect: n.lockAspect,
                  spaceBefore: n.spaceBefore,
                  spaceAfter: n.spaceAfter,
                  border: n.border,
                  metadata: n.metadata,
                ),
              ),
            ),
            onLockAspectChanged: (v) => onRequest(
              ReplaceNodeRequest(
                nodeId: n.id,
                newNode: n.copyWith(lockAspect: v),
              ),
            ),
            onPickFile: onPickImageFile,
          ),
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Property readers
  // ---------------------------------------------------------------------------

  TextAlign? get _textAlign => switch (node) {
        ParagraphNode(:final textAlign) => textAlign,
        ListItemNode(:final textAlign) => textAlign,
        BlockquoteNode(:final textAlign) => textAlign,
        _ => null,
      };

  double? get _lineHeight => switch (node) {
        ParagraphNode(:final lineHeight) => lineHeight,
        ListItemNode(:final lineHeight) => lineHeight,
        BlockquoteNode(:final lineHeight) => lineHeight,
        CodeBlockNode(:final lineHeight) => lineHeight,
        _ => null,
      };

  double? get _spaceBefore => switch (node) {
        ParagraphNode(:final spaceBefore) => spaceBefore,
        ListItemNode(:final spaceBefore) => spaceBefore,
        BlockquoteNode(:final spaceBefore) => spaceBefore,
        CodeBlockNode(:final spaceBefore) => spaceBefore,
        ImageNode(:final spaceBefore) => spaceBefore,
        HorizontalRuleNode(:final spaceBefore) => spaceBefore,
        TableNode(:final spaceBefore) => spaceBefore,
        _ => null,
      };

  double? get _spaceAfter => switch (node) {
        ParagraphNode(:final spaceAfter) => spaceAfter,
        ListItemNode(:final spaceAfter) => spaceAfter,
        BlockquoteNode(:final spaceAfter) => spaceAfter,
        CodeBlockNode(:final spaceAfter) => spaceAfter,
        ImageNode(:final spaceAfter) => spaceAfter,
        HorizontalRuleNode(:final spaceAfter) => spaceAfter,
        TableNode(:final spaceAfter) => spaceAfter,
        _ => null,
      };

  BlockBorder? get _border => switch (node) {
        ParagraphNode(:final border) => border,
        ListItemNode(:final border) => border,
        BlockquoteNode(:final border) => border,
        CodeBlockNode(:final border) => border,
        ImageNode(:final border) => border,
        HorizontalRuleNode(:final border) => border,
        TableNode(:final border) => border,
        _ => null,
      };

  double? get _indentLeft => switch (node) {
        ParagraphNode(:final indentLeft) => indentLeft,
        ListItemNode(:final indentLeft) => indentLeft,
        BlockquoteNode(:final indentLeft) => indentLeft,
        _ => null,
      };

  double? get _indentRight => switch (node) {
        ParagraphNode(:final indentRight) => indentRight,
        ListItemNode(:final indentRight) => indentRight,
        BlockquoteNode(:final indentRight) => indentRight,
        _ => null,
      };

  double? get _firstLineIndent => switch (node) {
        ParagraphNode(:final firstLineIndent) => firstLineIndent,
        BlockquoteNode(:final firstLineIndent) => firstLineIndent,
        _ => null,
      };

  BlockAlignment get _blockAlignment => switch (node) {
        BlockquoteNode(:final alignment) => alignment,
        CodeBlockNode(:final alignment) => alignment,
        ImageNode(:final alignment) => alignment,
        HorizontalRuleNode(:final alignment) => alignment,
        _ => BlockAlignment.stretch,
      };

  TextWrapMode get _textWrap => switch (node) {
        BlockquoteNode(:final textWrap) => textWrap,
        CodeBlockNode(:final textWrap) => textWrap,
        ImageNode(:final textWrap) => textWrap,
        HorizontalRuleNode(:final textWrap) => textWrap,
        _ => TextWrapMode.none,
      };

  BlockDimension? get _width => switch (node) {
        BlockquoteNode(:final width) => width,
        CodeBlockNode(:final width) => width,
        ImageNode(:final width) => width,
        HorizontalRuleNode(:final width) => width,
        _ => null,
      };

  BlockDimension? get _height => switch (node) {
        BlockquoteNode(:final height) => height,
        CodeBlockNode(:final height) => height,
        ImageNode(:final height) => height,
        HorizontalRuleNode(:final height) => height,
        _ => null,
      };

  // ---------------------------------------------------------------------------
  // Mutation helpers
  // ---------------------------------------------------------------------------

  void _handleSpacingChange({double? spaceBeforeOverride, double? spaceAfterOverride}) {
    final before = spaceBeforeOverride ?? _spaceBefore;
    final after = spaceAfterOverride ?? _spaceAfter;
    final n = node;
    final DocumentNode updated;
    if (n is ParagraphNode) {
      updated = ParagraphNode(
        id: n.id,
        text: n.text,
        blockType: n.blockType,
        textAlign: n.textAlign,
        lineHeight: n.lineHeight,
        spaceBefore: before,
        spaceAfter: after,
        indentLeft: n.indentLeft,
        indentRight: n.indentRight,
        firstLineIndent: n.firstLineIndent,
        border: n.border,
        metadata: n.metadata,
      );
    } else if (n is ListItemNode) {
      updated = ListItemNode(
        id: n.id,
        text: n.text,
        type: n.type,
        indent: n.indent,
        textAlign: n.textAlign,
        lineHeight: n.lineHeight,
        spaceBefore: before,
        spaceAfter: after,
        indentLeft: n.indentLeft,
        indentRight: n.indentRight,
        border: n.border,
        metadata: n.metadata,
      );
    } else if (n is BlockquoteNode) {
      updated = BlockquoteNode(
        id: n.id,
        text: n.text,
        width: n.width,
        height: n.height,
        alignment: n.alignment,
        textWrap: n.textWrap,
        textAlign: n.textAlign,
        lineHeight: n.lineHeight,
        spaceBefore: before,
        spaceAfter: after,
        indentLeft: n.indentLeft,
        indentRight: n.indentRight,
        firstLineIndent: n.firstLineIndent,
        border: n.border,
        metadata: n.metadata,
      );
    } else if (n is CodeBlockNode) {
      updated = CodeBlockNode(
        id: n.id,
        text: n.text,
        language: n.language,
        width: n.width,
        height: n.height,
        alignment: n.alignment,
        textWrap: n.textWrap,
        lineHeight: n.lineHeight,
        spaceBefore: before,
        spaceAfter: after,
        border: n.border,
        metadata: n.metadata,
      );
    } else if (n is ImageNode) {
      updated = ImageNode(
        id: n.id,
        imageUrl: n.imageUrl,
        altText: n.altText,
        width: n.width,
        height: n.height,
        alignment: n.alignment,
        textWrap: n.textWrap,
        lockAspect: n.lockAspect,
        spaceBefore: before,
        spaceAfter: after,
        border: n.border,
        metadata: n.metadata,
      );
    } else if (n is HorizontalRuleNode) {
      updated = HorizontalRuleNode(
        id: n.id,
        width: n.width,
        height: n.height,
        alignment: n.alignment,
        textWrap: n.textWrap,
        spaceBefore: before,
        spaceAfter: after,
        border: n.border,
        metadata: n.metadata,
      );
    } else if (n is TableNode) {
      final cells = [
        for (var r = 0; r < n.rowCount; r++)
          [for (var c = 0; c < n.columnCount; c++) n.cellAt(r, c)],
      ];
      updated = TableNode(
        id: n.id,
        rowCount: n.rowCount,
        columnCount: n.columnCount,
        cells: cells,
        columnWidths: n.columnWidths,
        alignment: n.alignment,
        spaceBefore: before,
        spaceAfter: after,
        border: n.border,
        metadata: n.metadata,
      );
    } else {
      return;
    }
    onRequest(ReplaceNodeRequest(nodeId: n.id, newNode: updated));
  }

  void _handleBorderChange(BlockBorder? border) {
    final n = node;
    final DocumentNode updated;
    if (n is ParagraphNode) {
      updated = ParagraphNode(
        id: n.id,
        text: n.text,
        blockType: n.blockType,
        textAlign: n.textAlign,
        lineHeight: n.lineHeight,
        spaceBefore: n.spaceBefore,
        spaceAfter: n.spaceAfter,
        indentLeft: n.indentLeft,
        indentRight: n.indentRight,
        firstLineIndent: n.firstLineIndent,
        border: border,
        metadata: n.metadata,
      );
    } else if (n is ListItemNode) {
      updated = ListItemNode(
        id: n.id,
        text: n.text,
        type: n.type,
        indent: n.indent,
        textAlign: n.textAlign,
        lineHeight: n.lineHeight,
        spaceBefore: n.spaceBefore,
        spaceAfter: n.spaceAfter,
        indentLeft: n.indentLeft,
        indentRight: n.indentRight,
        border: border,
        metadata: n.metadata,
      );
    } else if (n is BlockquoteNode) {
      updated = BlockquoteNode(
        id: n.id,
        text: n.text,
        width: n.width,
        height: n.height,
        alignment: n.alignment,
        textWrap: n.textWrap,
        textAlign: n.textAlign,
        lineHeight: n.lineHeight,
        spaceBefore: n.spaceBefore,
        spaceAfter: n.spaceAfter,
        indentLeft: n.indentLeft,
        indentRight: n.indentRight,
        firstLineIndent: n.firstLineIndent,
        border: border,
        metadata: n.metadata,
      );
    } else if (n is CodeBlockNode) {
      updated = CodeBlockNode(
        id: n.id,
        text: n.text,
        language: n.language,
        width: n.width,
        height: n.height,
        alignment: n.alignment,
        textWrap: n.textWrap,
        lineHeight: n.lineHeight,
        spaceBefore: n.spaceBefore,
        spaceAfter: n.spaceAfter,
        border: border,
        metadata: n.metadata,
      );
    } else if (n is ImageNode) {
      updated = ImageNode(
        id: n.id,
        imageUrl: n.imageUrl,
        altText: n.altText,
        width: n.width,
        height: n.height,
        alignment: n.alignment,
        textWrap: n.textWrap,
        lockAspect: n.lockAspect,
        spaceBefore: n.spaceBefore,
        spaceAfter: n.spaceAfter,
        border: border,
        metadata: n.metadata,
      );
    } else if (n is HorizontalRuleNode) {
      updated = HorizontalRuleNode(
        id: n.id,
        width: n.width,
        height: n.height,
        alignment: n.alignment,
        textWrap: n.textWrap,
        spaceBefore: n.spaceBefore,
        spaceAfter: n.spaceAfter,
        border: border,
        metadata: n.metadata,
      );
    } else if (n is TableNode) {
      final cells = [
        for (var r = 0; r < n.rowCount; r++)
          [for (var c = 0; c < n.columnCount; c++) n.cellAt(r, c)],
      ];
      updated = TableNode(
        id: n.id,
        rowCount: n.rowCount,
        columnCount: n.columnCount,
        cells: cells,
        columnWidths: n.columnWidths,
        alignment: n.alignment,
        spaceBefore: n.spaceBefore,
        spaceAfter: n.spaceAfter,
        border: border,
        metadata: n.metadata,
      );
    } else {
      return;
    }
    onRequest(ReplaceNodeRequest(nodeId: n.id, newNode: updated));
  }

  void _handleBlockAlignmentChange(BlockAlignment alignment) {
    final n = node;
    final DocumentNode updated;
    if (n is ImageNode) {
      updated = alignment == BlockAlignment.stretch
          ? ImageNode(
              id: n.id,
              imageUrl: n.imageUrl,
              altText: n.altText,
              width: null,
              height: null,
              alignment: alignment,
              textWrap: n.textWrap,
              border: n.border,
            )
          : n.copyWith(alignment: alignment);
    } else if (n is CodeBlockNode) {
      updated = alignment == BlockAlignment.stretch
          ? CodeBlockNode(
              id: n.id,
              text: n.text,
              language: n.language,
              width: null,
              height: null,
              alignment: alignment,
              textWrap: n.textWrap,
              border: n.border,
            )
          : n.copyWith(alignment: alignment);
    } else if (n is BlockquoteNode) {
      updated = alignment == BlockAlignment.stretch
          ? BlockquoteNode(
              id: n.id,
              text: n.text,
              width: null,
              height: null,
              alignment: alignment,
              textWrap: n.textWrap,
              border: n.border,
            )
          : n.copyWith(alignment: alignment);
    } else if (n is HorizontalRuleNode) {
      updated = alignment == BlockAlignment.stretch
          ? HorizontalRuleNode(
              id: n.id,
              width: null,
              height: null,
              alignment: alignment,
              textWrap: n.textWrap,
              border: n.border,
            )
          : n.copyWith(alignment: alignment);
    } else {
      return;
    }
    onRequest(ReplaceNodeRequest(nodeId: n.id, newNode: updated));
  }

  void _handleTextWrapChange(TextWrapMode textWrap) {
    final n = node;
    final DocumentNode updated;
    if (n is ImageNode) {
      updated = n.copyWith(textWrap: textWrap);
    } else if (n is CodeBlockNode) {
      updated = n.copyWith(textWrap: textWrap);
    } else if (n is BlockquoteNode) {
      updated = n.copyWith(textWrap: textWrap);
    } else if (n is HorizontalRuleNode) {
      updated = n.copyWith(textWrap: textWrap);
    } else {
      return;
    }
    onRequest(ReplaceNodeRequest(nodeId: n.id, newNode: updated));
  }

  void _handleWidthChange(BlockDimension? widthDim) {
    final n = node;
    final alignment = widthDim != null && _blockAlignment == BlockAlignment.stretch
        ? BlockAlignment.start
        : _blockAlignment;
    final DocumentNode updated;
    if (n is ImageNode) {
      updated = ImageNode(
        id: n.id,
        imageUrl: n.imageUrl,
        altText: n.altText,
        width: widthDim,
        height: n.height,
        alignment: alignment,
        textWrap: n.textWrap,
        border: n.border,
      );
    } else if (n is CodeBlockNode) {
      updated = CodeBlockNode(
        id: n.id,
        text: n.text,
        language: n.language,
        width: widthDim,
        height: n.height,
        alignment: alignment,
        textWrap: n.textWrap,
        border: n.border,
      );
    } else if (n is BlockquoteNode) {
      updated = BlockquoteNode(
        id: n.id,
        text: n.text,
        width: widthDim,
        height: n.height,
        alignment: alignment,
        textWrap: n.textWrap,
        border: n.border,
      );
    } else if (n is HorizontalRuleNode) {
      updated = HorizontalRuleNode(
        id: n.id,
        width: widthDim,
        height: n.height,
        alignment: alignment,
        textWrap: n.textWrap,
        border: n.border,
      );
    } else {
      return;
    }
    onRequest(ReplaceNodeRequest(nodeId: n.id, newNode: updated));
  }

  void _handleIndentChange({
    required double? indentLeft,
    required double? indentRight,
    required double? firstLineIndent,
  }) {
    final n = node;
    final DocumentNode updated;
    if (n is ParagraphNode) {
      updated = ParagraphNode(
        id: n.id,
        text: n.text,
        blockType: n.blockType,
        textAlign: n.textAlign,
        lineHeight: n.lineHeight,
        spaceBefore: n.spaceBefore,
        spaceAfter: n.spaceAfter,
        indentLeft: indentLeft,
        indentRight: indentRight,
        firstLineIndent: firstLineIndent,
        border: n.border,
        metadata: n.metadata,
      );
    } else if (n is ListItemNode) {
      updated = ListItemNode(
        id: n.id,
        text: n.text,
        type: n.type,
        indent: n.indent,
        textAlign: n.textAlign,
        lineHeight: n.lineHeight,
        spaceBefore: n.spaceBefore,
        spaceAfter: n.spaceAfter,
        indentLeft: indentLeft,
        indentRight: indentRight,
        border: n.border,
        metadata: n.metadata,
      );
    } else if (n is BlockquoteNode) {
      updated = BlockquoteNode(
        id: n.id,
        text: n.text,
        width: n.width,
        height: n.height,
        alignment: n.alignment,
        textWrap: n.textWrap,
        textAlign: n.textAlign,
        lineHeight: n.lineHeight,
        spaceBefore: n.spaceBefore,
        spaceAfter: n.spaceAfter,
        indentLeft: indentLeft,
        indentRight: indentRight,
        firstLineIndent: firstLineIndent,
        border: n.border,
        metadata: n.metadata,
      );
    } else {
      return;
    }
    onRequest(ReplaceNodeRequest(nodeId: n.id, newNode: updated));
  }

  void _handleHeightChange(BlockDimension? heightDim) {
    final n = node;
    final alignment = heightDim != null && _blockAlignment == BlockAlignment.stretch
        ? BlockAlignment.start
        : _blockAlignment;
    final DocumentNode updated;
    if (n is ImageNode) {
      updated = ImageNode(
        id: n.id,
        imageUrl: n.imageUrl,
        altText: n.altText,
        width: n.width,
        height: heightDim,
        alignment: alignment,
        textWrap: n.textWrap,
        border: n.border,
      );
    } else if (n is CodeBlockNode) {
      updated = CodeBlockNode(
        id: n.id,
        text: n.text,
        language: n.language,
        width: n.width,
        height: heightDim,
        alignment: alignment,
        textWrap: n.textWrap,
        border: n.border,
      );
    } else if (n is BlockquoteNode) {
      updated = BlockquoteNode(
        id: n.id,
        text: n.text,
        width: n.width,
        height: heightDim,
        alignment: alignment,
        textWrap: n.textWrap,
        border: n.border,
      );
    } else if (n is HorizontalRuleNode) {
      updated = HorizontalRuleNode(
        id: n.id,
        width: n.width,
        height: heightDim,
        alignment: alignment,
        textWrap: n.textWrap,
        border: n.border,
      );
    } else {
      return;
    }
    onRequest(ReplaceNodeRequest(nodeId: n.id, newNode: updated));
  }
}
