/// List item document node for the editable_document package.
///
/// Provides [ListItemType] and [ListItemNode] for representing ordered and
/// unordered list items with nesting support.
library;

import 'dart:ui' show TextAlign;

import 'package:flutter/foundation.dart';

import 'attributed_text.dart';
import 'block_border.dart';
import 'text_node.dart';

// ---------------------------------------------------------------------------
// ListItemType
// ---------------------------------------------------------------------------

/// The kind of list marker for a [ListItemNode].
enum ListItemType {
  /// A bulleted (unordered) list item.
  unordered,

  /// A numbered (ordered) list item.
  ordered,
}

// ---------------------------------------------------------------------------
// ListItemNode
// ---------------------------------------------------------------------------

/// A [TextNode] representing a single item within an ordered or unordered list.
///
/// The [type] field distinguishes bullet lists from numbered lists, and [indent]
/// tracks nesting depth (0 = top level, 1 = first level of indentation, etc.).
///
/// ```dart
/// final item = ListItemNode(
///   id: generateNodeId(),
///   text: AttributedText('First item'),
///   type: ListItemType.ordered,
///   indent: 0,
/// );
/// ```
class ListItemNode extends TextNode {
  /// Creates a [ListItemNode].
  ///
  /// [type] defaults to [ListItemType.unordered], [indent] defaults to `0`,
  /// [textAlign] defaults to [TextAlign.start], `lineHeight` defaults to
  /// `null` (inherit document default), `spaceBefore` / `spaceAfter`
  /// default to `null` (use document-level default spacing),
  /// [indentLeft] / [indentRight] default to `null` (no extra indent), and
  /// [border] defaults to `null` (no border drawn).
  ListItemNode({
    required super.id,
    super.text,
    this.type = ListItemType.unordered,
    this.indent = 0,
    this.textAlign = TextAlign.start,
    this.lineHeight,
    this.spaceBefore,
    this.spaceAfter,
    this.indentLeft,
    this.indentRight,
    this.border,
    super.metadata,
  });

  /// Whether this item belongs to an ordered or unordered list.
  final ListItemType type;

  /// The nesting depth of this list item.
  ///
  /// `0` is the top level; each increment represents one additional level of
  /// indentation inside a nested list.
  final int indent;

  /// The horizontal text alignment within this list item.
  ///
  /// Defaults to [TextAlign.start], which aligns text to the leading edge for
  /// the current text direction.
  final TextAlign textAlign;

  /// Line-height multiplier for this list item, or `null` to inherit the
  /// document default.
  ///
  /// A value of `1.0` uses the font's natural line height. `1.5` adds
  /// 50 % extra leading. `null` defers to whatever default the renderer
  /// applies for the document as a whole.
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
  ListItemNode copyWith({
    String? id,
    AttributedText? text,
    ListItemType? type,
    int? indent,
    TextAlign? textAlign,
    double? lineHeight,
    double? spaceBefore,
    double? spaceAfter,
    double? indentLeft,
    double? indentRight,
    BlockBorder? border,
    Map<String, dynamic>? metadata,
  }) {
    return ListItemNode(
      id: id ?? this.id,
      text: text ?? this.text,
      type: type ?? this.type,
      indent: indent ?? this.indent,
      textAlign: textAlign ?? this.textAlign,
      lineHeight: lineHeight ?? this.lineHeight,
      spaceBefore: spaceBefore ?? this.spaceBefore,
      spaceAfter: spaceAfter ?? this.spaceAfter,
      indentLeft: indentLeft ?? this.indentLeft,
      indentRight: indentRight ?? this.indentRight,
      border: border ?? this.border,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is ListItemNode &&
        other.id == id &&
        other.text == text &&
        other.type == type &&
        other.indent == indent &&
        other.textAlign == textAlign &&
        other.lineHeight == lineHeight &&
        other.spaceBefore == spaceBefore &&
        other.spaceAfter == spaceAfter &&
        other.indentLeft == indentLeft &&
        other.indentRight == indentRight &&
        other.border == border &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        text,
        type,
        indent,
        textAlign,
        lineHeight,
        spaceBefore,
        spaceAfter,
        indentLeft,
        indentRight,
        border,
        Object.hashAll(metadata.entries.map((e) => e)),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<ListItemType>('type', type));
    properties.add(IntProperty('indent', indent));
    properties.add(
      EnumProperty<TextAlign>('textAlign', textAlign, defaultValue: TextAlign.start),
    );
    properties.add(DoubleProperty('lineHeight', lineHeight, defaultValue: null));
    properties.add(DoubleProperty('spaceBefore', spaceBefore, defaultValue: null));
    properties.add(DoubleProperty('spaceAfter', spaceAfter, defaultValue: null));
    properties.add(DoubleProperty('indentLeft', indentLeft, defaultValue: null));
    properties.add(DoubleProperty('indentRight', indentRight, defaultValue: null));
    properties.add(DiagnosticsProperty<BlockBorder?>('border', border, defaultValue: null));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'ListItemNode(id: $id, type: $type, indent: $indent, textAlign: $textAlign, '
      'lineHeight: $lineHeight, spaceBefore: $spaceBefore, spaceAfter: $spaceAfter, '
      'indentLeft: $indentLeft, indentRight: $indentRight, border: $border, '
      'text: $text, metadata: $metadata)';
}
