/// Document editing controller for the editable_document package.
///
/// Provides [DocumentEditingController], the central coordinator for a
/// document editor: it holds the [MutableDocument], the current
/// [DocumentSelection], and the active [ComposerPreferences].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'composer_preferences.dart';
import 'document_node.dart';
import 'document_selection.dart';
import 'mutable_document.dart';
import 'text_node.dart';

// ---------------------------------------------------------------------------
// DocumentEditingController
// ---------------------------------------------------------------------------

/// A controller for a document editor, analogous to [TextEditingController].
///
/// Holds the [document], current [selection], and active
/// [ComposerPreferences]. Notifies listeners when any of these change.
///
/// Example:
/// ```dart
/// final controller = DocumentEditingController(
///   document: MutableDocument([
///     ParagraphNode(id: 'p1', text: AttributedText('Hello world')),
///   ]),
/// );
/// controller.addListener(() {
///   debugPrint('Selection changed: ${controller.selection}');
/// });
/// controller.setSelection(
///   DocumentSelection.collapsed(
///     position: DocumentPosition(
///       nodeId: 'p1',
///       nodePosition: TextNodePosition(offset: 5),
///     ),
///   ),
/// );
/// ```
class DocumentEditingController extends ChangeNotifier {
  /// Creates a controller with the given [document].
  ///
  /// [selection] defaults to `null` (no selection). [preferences] defaults to
  /// an empty [ComposerPreferences].
  DocumentEditingController({
    required MutableDocument document,
    DocumentSelection? selection,
    ComposerPreferences? preferences,
  })  : _document = document,
        _selection = selection,
        _preferences = preferences ?? ComposerPreferences();

  final MutableDocument _document;
  DocumentSelection? _selection;
  final ComposerPreferences _preferences;

  // -------------------------------------------------------------------------
  // Getters
  // -------------------------------------------------------------------------

  /// The document being edited.
  MutableDocument get document => _document;

  /// The current selection, or `null` if nothing is selected.
  DocumentSelection? get selection => _selection;

  /// The active composer preferences (e.g. active attributions for new text).
  ComposerPreferences get preferences => _preferences;

  // -------------------------------------------------------------------------
  // Selection management
  // -------------------------------------------------------------------------

  /// Sets the selection and notifies listeners.
  ///
  /// If [newSelection] equals the current selection (by value), this is a
  /// no-op and listeners are not notified.
  void setSelection(DocumentSelection? newSelection) {
    if (_selection == newSelection) return;
    _selection = newSelection;
    notifyListeners();
  }

  /// Clears the selection (sets to `null`) and notifies listeners.
  ///
  /// Equivalent to `setSelection(null)`.
  void clearSelection() => setSelection(null);

  /// Collapses an expanded selection to the extent position.
  ///
  /// If the selection is already collapsed or `null`, this is a no-op and
  /// listeners are not notified.
  void collapseSelection() {
    if (_selection == null || _selection!.isCollapsed) return;
    setSelection(DocumentSelection.collapsed(position: _selection!.extent));
  }

  // -------------------------------------------------------------------------
  // Span building
  // -------------------------------------------------------------------------

  /// Builds an [InlineSpan] (typically [TextSpan]) for [node], applying
  /// the composing region underline when applicable.
  ///
  /// This is analogous to [TextEditingController.buildTextSpan]. For
  /// non-text nodes, returns `null`.
  ///
  /// [style] is passed directly to the returned [TextSpan] so callers can
  /// supply a base [TextStyle] (e.g. from `DefaultTextStyle.of(context).style`).
  ///
  /// Subclasses may override to provide syntax highlighting or custom
  /// attribution-to-style mapping.
  InlineSpan? buildNodeSpan(DocumentNode node, {TextStyle? style}) {
    if (node is! TextNode) return null;
    return TextSpan(text: node.text.text, style: style);
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void dispose() {
    super.dispose();
  }
}
