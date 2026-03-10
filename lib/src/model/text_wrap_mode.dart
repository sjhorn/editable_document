/// Text wrap mode for container document nodes.
///
/// Provides [TextWrapMode], which controls how surrounding text interacts with
/// a sized block element such as [ImageNode], [CodeBlockNode], [BlockquoteNode],
/// and [HorizontalRuleNode].
library;

/// Text wrap mode for container document nodes.
///
/// Determines how surrounding text interacts with a sized block element.
/// Used by [ImageNode], [CodeBlockNode], [BlockquoteNode], and
/// [HorizontalRuleNode].
///
/// The default mode everywhere in the framework is [none], which causes the
/// block to occupy a full vertical row — matching the existing full-width
/// layout behavior.
///
/// ```dart
/// final image = ImageNode(
///   id: 'img-1',
///   imageUrl: 'https://example.com/photo.jpg',
///   textWrap: TextWrapMode.wrap,
/// );
/// ```
enum TextWrapMode {
  /// No wrapping — block occupies a full vertical row.
  none,

  /// Text wraps around the block (float with exclusion zone).
  wrap,

  /// Block positioned like a float but painted behind text, no exclusion.
  behindText,

  /// Block positioned like a float but painted on top of text, no exclusion.
  inFrontOfText,
}
