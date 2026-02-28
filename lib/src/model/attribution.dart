/// Attribution model for the editable_document package.
///
/// Attributions are named markers that can be applied to spans of text within
/// an [AttributedText]. This file defines the core [Attribution] interface and
/// the two concrete implementations shipped with the package:
/// [NamedAttribution] for common inline styles and [LinkAttribution] for
/// hyperlinks.
library;

/// A named attribution that can be applied to spans of text.
///
/// An [Attribution] has an [id] string that identifies its type, and a
/// [canMergeWith] predicate that controls whether two adjacent or overlapping
/// spans carrying the same attribution kind may be collapsed into a single
/// span.
///
/// Built-in attributions are provided via [NamedAttribution] static constants.
/// Custom attributions can be created by implementing this interface directly.
abstract class Attribution {
  /// The identifier for this attribution type.
  ///
  /// Two [Attribution] objects with the same [id] are not necessarily equal —
  /// for example, [LinkAttribution] always returns `'link'` regardless of the
  /// target [Uri]. Use [==] for full equality.
  String get id;

  /// Whether this attribution can be merged with [other].
  ///
  /// When two spans are adjacent or overlapping and both return `true` from
  /// [canMergeWith], [AttributedText] will automatically collapse them into a
  /// single span. A typical implementation returns `this == other`.
  bool canMergeWith(Attribution other);
}

/// Built-in named attributions for common text styles.
///
/// Each constant is a lightweight, `const`-safe value object whose [id] is
/// the style name. Two [NamedAttribution]s are equal when their [id]s match.
///
/// ```dart
/// final bold = NamedAttribution.bold;
/// final also = const NamedAttribution('bold');
/// assert(bold == also); // true
/// ```
class NamedAttribution implements Attribution {
  /// Creates a named attribution with the given [id].
  const NamedAttribution(this.id);

  /// Bold text.
  static const bold = NamedAttribution('bold');

  /// Italic text.
  static const italics = NamedAttribution('italics');

  /// Underlined text.
  static const underline = NamedAttribution('underline');

  /// Strikethrough text.
  static const strikethrough = NamedAttribution('strikethrough');

  /// Inline code text.
  static const code = NamedAttribution('code');

  @override
  final String id;

  @override
  bool canMergeWith(Attribution other) => this == other;

  @override
  bool operator ==(Object other) => other is NamedAttribution && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NamedAttribution($id)';
}

/// An attribution that associates a hyperlink [url] with a span of text.
///
/// Two [LinkAttribution]s are equal only when their [url]s are equal, so
/// spans with different URLs are stored and rendered independently.
class LinkAttribution implements Attribution {
  /// Creates a link attribution for [url].
  const LinkAttribution(this.url);

  /// The hyperlink target.
  final Uri url;

  @override
  String get id => 'link';

  @override
  bool canMergeWith(Attribution other) => other is LinkAttribution && other.url == url;

  @override
  bool operator ==(Object other) => other is LinkAttribution && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'LinkAttribution($url)';
}
