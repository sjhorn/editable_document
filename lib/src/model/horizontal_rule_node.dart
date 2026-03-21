/// Horizontal rule document node for the editable_document package.
///
/// Provides [HorizontalRuleNode], a content-less thematic break node.
/// Cursor placement uses [BinaryNodePosition] (upstream / downstream).
library;

import 'package:flutter/foundation.dart';

import 'block_alignment.dart';
import 'block_border.dart';
import 'block_layout.dart';
import 'document_node.dart';
import 'text_wrap_mode.dart';

/// A [DocumentNode] representing a horizontal rule (thematic break).
///
/// [HorizontalRuleNode] carries no text content — it is a purely visual
/// divider analogous to the HTML `<hr>` element. Because the node has no
/// editable content, cursor placement is handled by [BinaryNodePosition]
/// (either before or after the rule).
///
/// The [alignment] field controls how the rule is positioned within the
/// available layout width when the rule has an explicit [width] smaller than
/// the full layout (controlled by the rendering layer).
///
/// The optional [width] and [height] fields provide sizing hints to the
/// rendering layer. When `null`, the rendering layer applies its default
/// auto-sizing behaviour (typically full-width, thin line).
///
/// The [textWrap] field controls how surrounding text interacts with this rule.
///
/// ```dart
/// final rule = HorizontalRuleNode(
///   id: generateNodeId(),
///   width: 400.0,
///   height: 2.0,
///   alignment: BlockAlignment.center,
///   textWrap: TextWrapMode.none,
/// );
/// ```
class HorizontalRuleNode extends DocumentNode implements HasBlockLayout {
  /// Creates a [HorizontalRuleNode] with the given [id], optional [metadata],
  /// optional [alignment], optional [width], optional [height], optional
  /// [textWrap], optional [spaceBefore], optional [spaceAfter], and optional
  /// [border].
  ///
  /// [alignment] defaults to [BlockAlignment.stretch].
  /// [textWrap] defaults to [TextWrapMode.none].
  /// [spaceBefore] and [spaceAfter] default to `null` (use document-level
  /// default spacing).
  /// [border] defaults to `null` (no border drawn).
  HorizontalRuleNode({
    required super.id,
    this.width,
    this.height,
    this.alignment = BlockAlignment.stretch,
    this.textWrap = TextWrapMode.none,
    this.spaceBefore,
    this.spaceAfter,
    this.border,
    super.metadata,
  });

  /// Preferred display width in logical pixels, or `null` for auto sizing.
  final double? width;

  /// Preferred display height in logical pixels, or `null` for auto sizing.
  final double? height;

  /// How the horizontal rule is aligned within the available layout width.
  ///
  /// Defaults to [BlockAlignment.stretch], which stretches the rule to fill
  /// the entire available width. Use other values when the rendering layer
  /// constrains the rule to a narrower width.
  final BlockAlignment alignment;

  /// How surrounding text interacts with this horizontal rule.
  ///
  /// Defaults to [TextWrapMode.none], which causes the rule to occupy a full
  /// vertical row. Use [TextWrapMode.wrap] to enable float-like layout
  /// (similar to CSS `float`).
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
  bool get isDraggable => true;

  @override
  bool get isResizable => alignment != BlockAlignment.stretch;

  @override
  DocumentNode copyWithSize({double? width, double? height, BlockAlignment? alignment}) => copyWith(
        width: width ?? this.width,
        height: height ?? this.height,
        alignment: alignment ?? this.alignment,
      );

  @override
  HorizontalRuleNode copyWith({
    String? id,
    double? width,
    double? height,
    BlockAlignment? alignment,
    TextWrapMode? textWrap,
    double? spaceBefore,
    double? spaceAfter,
    BlockBorder? border,
    Map<String, dynamic>? metadata,
  }) {
    return HorizontalRuleNode(
      id: id ?? this.id,
      width: width ?? this.width,
      height: height ?? this.height,
      alignment: alignment ?? this.alignment,
      textWrap: textWrap ?? this.textWrap,
      spaceBefore: spaceBefore ?? this.spaceBefore,
      spaceAfter: spaceAfter ?? this.spaceAfter,
      border: border ?? this.border,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is HorizontalRuleNode &&
        other.id == id &&
        other.width == width &&
        other.height == height &&
        other.alignment == alignment &&
        other.textWrap == textWrap &&
        other.spaceBefore == spaceBefore &&
        other.spaceAfter == spaceAfter &&
        other.border == border &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        width,
        height,
        alignment,
        textWrap,
        spaceBefore,
        spaceAfter,
        border,
        Object.hashAll(metadata.entries.map((e) => e)),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DoubleProperty('height', height, defaultValue: null));
    properties.add(
      EnumProperty<BlockAlignment>('alignment', alignment, defaultValue: BlockAlignment.stretch),
    );
    properties.add(
      EnumProperty<TextWrapMode>('textWrap', textWrap, defaultValue: TextWrapMode.none),
    );
    properties.add(DoubleProperty('spaceBefore', spaceBefore, defaultValue: null));
    properties.add(DoubleProperty('spaceAfter', spaceAfter, defaultValue: null));
    properties.add(DiagnosticsProperty<BlockBorder?>('border', border, defaultValue: null));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'HorizontalRuleNode(id: $id, width: $width, height: $height, '
      'alignment: ${alignment.name}, textWrap: $textWrap, '
      'spaceBefore: $spaceBefore, spaceAfter: $spaceAfter, border: $border, metadata: $metadata)';
}
