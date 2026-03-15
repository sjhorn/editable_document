/// List item document node for the editable_document package.
///
/// Provides [ListItemType] and [ListItemNode] for representing ordered and
/// unordered list items with nesting support.
library;

import 'dart:ui' show TextAlign;

import 'package:flutter/foundation.dart';

import 'attributed_text.dart';
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
  /// and [textAlign] defaults to [TextAlign.start].
  ListItemNode({
    required super.id,
    super.text,
    this.type = ListItemType.unordered,
    this.indent = 0,
    this.textAlign = TextAlign.start,
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

  @override
  ListItemNode copyWith({
    String? id,
    AttributedText? text,
    ListItemType? type,
    int? indent,
    TextAlign? textAlign,
    Map<String, dynamic>? metadata,
  }) {
    return ListItemNode(
      id: id ?? this.id,
      text: text ?? this.text,
      type: type ?? this.type,
      indent: indent ?? this.indent,
      textAlign: textAlign ?? this.textAlign,
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
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        text,
        type,
        indent,
        textAlign,
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
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'ListItemNode(id: $id, type: $type, indent: $indent, textAlign: $textAlign, '
      'text: $text, metadata: $metadata)';
}
