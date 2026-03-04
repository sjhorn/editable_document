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

/// An attribution that applies a custom font family to a span of text.
///
/// Two [FontFamilyAttribution]s are equal only when their [fontFamily] strings
/// match, so spans styled with different typefaces are stored independently.
///
/// ```dart
/// final roboto = const FontFamilyAttribution('Roboto');
/// final merri  = const FontFamilyAttribution('Merriweather');
/// assert(roboto != merri); // different families — not mergeable
/// ```
class FontFamilyAttribution implements Attribution {
  /// Creates a font-family attribution for [fontFamily].
  const FontFamilyAttribution(this.fontFamily);

  /// The name of the font family, e.g. `'Roboto'` or `'Merriweather'`.
  final String fontFamily;

  @override
  String get id => 'fontFamily';

  @override
  bool canMergeWith(Attribution other) =>
      other is FontFamilyAttribution && other.fontFamily == fontFamily;

  @override
  bool operator ==(Object other) =>
      other is FontFamilyAttribution && other.fontFamily == fontFamily;

  @override
  int get hashCode => fontFamily.hashCode;

  @override
  String toString() => 'FontFamilyAttribution($fontFamily)';
}

/// An attribution that applies a specific font size to a span of text.
///
/// Two [FontSizeAttribution]s are equal only when their [fontSize] values
/// match, so spans with distinct sizes are stored independently.
///
/// ```dart
/// final heading = const FontSizeAttribution(24.0);
/// final body    = const FontSizeAttribution(16.0);
/// assert(heading != body); // different sizes — not mergeable
/// ```
class FontSizeAttribution implements Attribution {
  /// Creates a font-size attribution for [fontSize] logical pixels.
  const FontSizeAttribution(this.fontSize);

  /// The font size in logical pixels.
  final double fontSize;

  @override
  String get id => 'fontSize';

  @override
  bool canMergeWith(Attribution other) =>
      other is FontSizeAttribution && other.fontSize == fontSize;

  @override
  bool operator ==(Object other) => other is FontSizeAttribution && other.fontSize == fontSize;

  @override
  int get hashCode => fontSize.hashCode;

  @override
  String toString() => 'FontSizeAttribution($fontSize)';
}

/// An attribution that applies a foreground (text) colour to a span of text.
///
/// The colour is stored as an ARGB 32-bit integer to avoid importing
/// `dart:ui` in the model layer. Convert to/from `Color` at the widget
/// boundary: `Color(attribution.colorValue)` / `color.value`.
///
/// Two [TextColorAttribution]s are equal only when their [colorValue]s match.
///
/// ```dart
/// const red  = TextColorAttribution(0xFFFF0000);
/// const blue = TextColorAttribution(0xFF0000FF);
/// assert(red != blue);
/// ```
class TextColorAttribution implements Attribution {
  /// Creates a text-colour attribution from an ARGB 32-bit [colorValue].
  const TextColorAttribution(this.colorValue);

  /// The ARGB 32-bit colour value (e.g. `0xFFFF0000` for opaque red).
  final int colorValue;

  @override
  String get id => 'textColor';

  @override
  bool canMergeWith(Attribution other) =>
      other is TextColorAttribution && other.colorValue == colorValue;

  @override
  bool operator ==(Object other) => other is TextColorAttribution && other.colorValue == colorValue;

  @override
  int get hashCode => colorValue.hashCode;

  @override
  String toString() => 'TextColorAttribution($colorValue)';
}

/// An attribution that applies a background (highlight) colour to a span of
/// text.
///
/// The colour is stored as an ARGB 32-bit integer to avoid importing
/// `dart:ui` in the model layer. Convert to/from `Color` at the widget
/// boundary: `Color(attribution.colorValue)` / `color.value`.
///
/// Two [BackgroundColorAttribution]s are equal only when their [colorValue]s
/// match. A [BackgroundColorAttribution] never merges with a
/// [TextColorAttribution] even when the integer values are the same.
///
/// ```dart
/// const yellow = BackgroundColorAttribution(0xFFFFFF00);
/// const green  = BackgroundColorAttribution(0xFF00FF00);
/// assert(yellow != green);
/// ```
class BackgroundColorAttribution implements Attribution {
  /// Creates a background-colour attribution from an ARGB 32-bit [colorValue].
  const BackgroundColorAttribution(this.colorValue);

  /// The ARGB 32-bit colour value (e.g. `0xFFFFFF00` for opaque yellow).
  final int colorValue;

  @override
  String get id => 'backgroundColor';

  @override
  bool canMergeWith(Attribution other) =>
      other is BackgroundColorAttribution && other.colorValue == colorValue;

  @override
  bool operator ==(Object other) =>
      other is BackgroundColorAttribution && other.colorValue == colorValue;

  @override
  int get hashCode => colorValue.hashCode;

  @override
  String toString() => 'BackgroundColorAttribution($colorValue)';
}
