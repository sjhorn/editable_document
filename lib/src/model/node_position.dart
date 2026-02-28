import 'dart:ui' show TextAffinity;

/// Abstract marker interface for positions within a [DocumentNode].
///
/// Each node type defines its own position representation.
/// [TextNodePosition] is used for text-based nodes; [BinaryNodePosition]
/// is used for non-text nodes like images and horizontal rules.
abstract class NodePosition {}

/// A position within a text-based [DocumentNode], identified by a
/// character [offset] and [affinity].
///
/// This is analogous to Flutter's [TextPosition] but scoped to a single
/// document node rather than a flat text field.
///
/// Example:
/// ```dart
/// const pos = TextNodePosition(offset: 5);
/// final upstreamPos = pos.copyWith(affinity: TextAffinity.upstream);
/// ```
class TextNodePosition implements NodePosition {
  /// Creates a [TextNodePosition] at [offset] with optional [affinity].
  ///
  /// [affinity] defaults to [TextAffinity.downstream] when not specified.
  const TextNodePosition({
    required this.offset,
    this.affinity = TextAffinity.downstream,
  });

  /// The character offset within the node's text.
  final int offset;

  /// Whether this position is associated with the character before or
  /// after [offset] when the offset falls on a line break.
  final TextAffinity affinity;

  /// Returns a copy of this position with the given fields replaced.
  TextNodePosition copyWith({int? offset, TextAffinity? affinity}) {
    return TextNodePosition(
      offset: offset ?? this.offset,
      affinity: affinity ?? this.affinity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextNodePosition && other.offset == offset && other.affinity == affinity;
  }

  @override
  int get hashCode => Object.hash(offset, affinity);

  @override
  String toString() => 'TextNodePosition(offset: $offset, affinity: $affinity)';
}

/// The type of a [BinaryNodePosition].
enum BinaryNodePositionType {
  /// Before the node's content.
  upstream,

  /// After the node's content.
  downstream,
}

/// A position within a non-text [DocumentNode] that has only two
/// meaningful positions: before ([upstream]) or after ([downstream])
/// its content.
///
/// Used for nodes like images and horizontal rules that don't contain
/// editable text.
///
/// Example:
/// ```dart
/// const before = BinaryNodePosition.upstream();
/// const after = BinaryNodePosition.downstream();
/// ```
class BinaryNodePosition implements NodePosition {
  /// Creates a [BinaryNodePosition] with the given [type].
  const BinaryNodePosition(this.type);

  /// Creates an upstream (before content) position.
  const BinaryNodePosition.upstream() : type = BinaryNodePositionType.upstream;

  /// Creates a downstream (after content) position.
  const BinaryNodePosition.downstream() : type = BinaryNodePositionType.downstream;

  /// Whether this position is upstream or downstream of the node's content.
  final BinaryNodePositionType type;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BinaryNodePosition && other.type == type;
  }

  @override
  int get hashCode => type.hashCode;

  @override
  String toString() => 'BinaryNodePosition(${type.name})';
}
