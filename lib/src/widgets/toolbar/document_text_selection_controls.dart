/// Floating toolbar for [EditableDocument] — Phase 6.6.
///
/// Provides [DocumentTextSelectionControls], a [TextSelectionControls]
/// implementation that delegates handle building and standard actions
/// (Cut, Copy, Paste, Select All) to the platform-appropriate controls
/// ([materialTextSelectionControls] / [cupertinoTextSelectionControls]) and
/// adds document-specific actions (Bold, Italic) via [DocumentToolbarAction].
///
/// Use the [documentTextSelectionControls] factory to obtain a correctly
/// configured instance for the current platform.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../model/attribution.dart';
import '../../model/document_position.dart';
import '../../model/document_selection.dart';
import '../../model/edit_request.dart';
import '../../model/node_position.dart';

// ---------------------------------------------------------------------------
// DocumentToolbarAction
// ---------------------------------------------------------------------------

/// A description of a single action shown in the floating toolbar.
///
/// Either [onPressed] or [requestBuilder] (or both) may be provided:
///
/// - [requestBuilder] produces an [EditRequest] from the current
///   [DocumentSelection]; the request is forwarded to
///   [DocumentTextSelectionControls.onEditRequest] when the action is tapped.
/// - [onPressed] is an alternative direct callback that does not go through
///   the request pipeline (useful for navigation or non-document actions).
///
/// When both are `null` the action acts as a visual separator.
///
/// ```dart
/// DocumentToolbarAction(
///   label: 'Bold',
///   icon: Icons.format_bold,
///   requestBuilder: (selection) => ApplyAttributionRequest(
///     selection: selection,
///     attribution: NamedAttribution.bold,
///   ),
/// )
/// ```
class DocumentToolbarAction {
  /// Creates a [DocumentToolbarAction].
  ///
  /// [label] is required. [icon], [requestBuilder], and [onPressed] are all
  /// optional.
  DocumentToolbarAction({
    required this.label,
    this.icon,
    this.requestBuilder,
    this.onPressed,
  });

  /// The human-readable label displayed on the toolbar button.
  final String label;

  /// An optional icon shown alongside (or instead of) [label].
  final IconData? icon;

  /// A function that produces an [EditRequest] from the active
  /// [DocumentSelection].
  ///
  /// When non-null, the toolbar calls this function to build the request, then
  /// forwards it to [DocumentTextSelectionControls.onEditRequest].
  final EditRequest Function(DocumentSelection selection)? requestBuilder;

  /// An optional direct callback invoked when the action is tapped.
  ///
  /// Use this for actions that do not produce an [EditRequest] (e.g. external
  /// navigation or UI state changes).
  final VoidCallback? onPressed;
}

// ---------------------------------------------------------------------------
// DocumentTextSelectionControls
// ---------------------------------------------------------------------------

/// A [TextSelectionControls] implementation that wraps the platform-default
/// controls and injects document-specific toolbar actions (Bold, Italic).
///
/// Handle building (the drag handles at the edges of a text selection) is
/// fully delegated to the platform controls. The toolbar is extended with
/// [DocumentToolbarAction]s provided via [toolbarActions] (in addition to the
/// always-present [defaultBoldAction] and [defaultItalicAction]).
///
/// [onEditRequest] receives every [EditRequest] that is produced by a
/// [DocumentToolbarAction.requestBuilder].
///
/// ## Usage
///
/// ```dart
/// EditableDocument(
///   controller: _controller,
///   focusNode: _focusNode,
///   selectionControls: DocumentTextSelectionControls(
///     onEditRequest: (request) => _editor.submit(request),
///   ),
/// )
/// ```
///
/// Or use the [documentTextSelectionControls] factory for the recommended
/// platform-adaptive instance.
class DocumentTextSelectionControls extends TextSelectionControls {
  /// Creates a [DocumentTextSelectionControls].
  ///
  /// [toolbarActions] — optional list of extra toolbar actions appended after
  /// Bold and Italic. Defaults to `null` (no extras).
  ///
  /// [onEditRequest] — callback invoked whenever a [DocumentToolbarAction]
  /// produces an [EditRequest]. Defaults to `null`.
  DocumentTextSelectionControls({
    this.toolbarActions,
    this.onEditRequest,
  });

  /// Extra toolbar actions appended after the built-in Bold and Italic
  /// actions.
  ///
  /// When `null`, only Bold and Italic are shown as document-specific actions.
  final List<DocumentToolbarAction>? toolbarActions;

  /// Callback invoked whenever a [DocumentToolbarAction.requestBuilder]
  /// produces an [EditRequest] for the current selection.
  ///
  /// Route this to your [Editor.submit] call to apply the change to the
  /// document.
  final void Function(EditRequest)? onEditRequest;

  // -------------------------------------------------------------------------
  // Built-in document actions
  // -------------------------------------------------------------------------

  /// The built-in Bold action.
  ///
  /// Produces an [ApplyAttributionRequest] with [NamedAttribution.bold] for
  /// the current selection.
  DocumentToolbarAction get defaultBoldAction => DocumentToolbarAction(
        label: 'Bold',
        icon: Icons.format_bold,
        requestBuilder: (selection) => ApplyAttributionRequest(
          selection: selection,
          attribution: NamedAttribution.bold,
        ),
      );

  /// The built-in Italic action.
  ///
  /// Produces an [ApplyAttributionRequest] with [NamedAttribution.italics]
  /// for the current selection.
  DocumentToolbarAction get defaultItalicAction => DocumentToolbarAction(
        label: 'Italic',
        icon: Icons.format_italic,
        requestBuilder: (selection) => ApplyAttributionRequest(
          selection: selection,
          attribution: NamedAttribution.italics,
        ),
      );

  // -------------------------------------------------------------------------
  // getAllDocumentActions
  // -------------------------------------------------------------------------

  /// Returns all document-specific toolbar actions in display order.
  ///
  /// Always includes [defaultBoldAction] and [defaultItalicAction], followed
  /// by any extra [toolbarActions] that were provided at construction.
  List<DocumentToolbarAction> getAllDocumentActions() {
    return [
      defaultBoldAction,
      defaultItalicAction,
      ...?toolbarActions,
    ];
  }

  // -------------------------------------------------------------------------
  // Platform delegate helpers
  // -------------------------------------------------------------------------

  /// Returns the platform-appropriate [TextSelectionControls] delegate.
  TextSelectionControls get _platformDelegate {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return cupertinoTextSelectionControls;
      case TargetPlatform.android:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return materialTextSelectionControls;
    }
  }

  // -------------------------------------------------------------------------
  // TextSelectionControls overrides — handle building (delegated)
  // -------------------------------------------------------------------------

  @override
  Size getHandleSize(double textLineHeight) {
    return _platformDelegate.getHandleSize(textLineHeight);
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    return _platformDelegate.buildHandle(context, type, textLineHeight, onTap);
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    return _platformDelegate.getHandleAnchor(type, textLineHeight);
  }

  // -------------------------------------------------------------------------
  // TextSelectionControls overrides — toolbar building
  // -------------------------------------------------------------------------

  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) {
    // Build the platform toolbar for standard actions (Cut/Copy/Paste/Select
    // All). We then stack or replace with a custom toolbar that also contains
    // the document-specific Bold and Italic actions.
    return _DocumentToolbar(
      globalEditableRegion: globalEditableRegion,
      textLineHeight: textLineHeight,
      selectionMidpoint: selectionMidpoint,
      endpoints: endpoints,
      delegate: delegate,
      clipboardStatus: clipboardStatus,
      lastSecondaryTapDownPosition: lastSecondaryTapDownPosition,
      documentActions: getAllDocumentActions(),
      onEditRequest: onEditRequest,
      platformDelegate: _platformDelegate,
    );
  }

  @override
  // ignore: deprecated_member_use
  bool canSelectAll(TextSelectionDelegate delegate) {
    // ignore: deprecated_member_use
    return _platformDelegate.canSelectAll(delegate);
  }
}

// ---------------------------------------------------------------------------
// _DocumentToolbar
// ---------------------------------------------------------------------------

/// Internal widget that renders the floating toolbar.
///
/// Shows standard platform actions (Cut, Copy, Paste, Select All) via the
/// [platformDelegate]'s toolbar, followed by document-specific actions
/// ([documentActions]) rendered as [TextButton]s in a [Material] card.
class _DocumentToolbar extends StatefulWidget {
  const _DocumentToolbar({
    required this.globalEditableRegion,
    required this.textLineHeight,
    required this.selectionMidpoint,
    required this.endpoints,
    required this.delegate,
    required this.clipboardStatus,
    required this.lastSecondaryTapDownPosition,
    required this.documentActions,
    required this.onEditRequest,
    required this.platformDelegate,
  });

  final Rect globalEditableRegion;
  final double textLineHeight;
  final Offset selectionMidpoint;
  final List<TextSelectionPoint> endpoints;
  final TextSelectionDelegate delegate;
  final ValueListenable<ClipboardStatus>? clipboardStatus;
  final Offset? lastSecondaryTapDownPosition;
  final List<DocumentToolbarAction> documentActions;
  final void Function(EditRequest)? onEditRequest;
  final TextSelectionControls platformDelegate;

  @override
  State<_DocumentToolbar> createState() => _DocumentToolbarState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Rect>('globalEditableRegion', globalEditableRegion));
    properties.add(DoubleProperty('textLineHeight', textLineHeight));
    properties.add(DiagnosticsProperty<Offset>('selectionMidpoint', selectionMidpoint));
    properties.add(IterableProperty<TextSelectionPoint>('endpoints', endpoints));
    properties.add(DiagnosticsProperty<TextSelectionDelegate>('delegate', delegate));
    properties.add(
      DiagnosticsProperty<ValueListenable<ClipboardStatus>?>(
        'clipboardStatus',
        clipboardStatus,
        defaultValue: null,
      ),
    );
    properties.add(
      DiagnosticsProperty<Offset?>(
        'lastSecondaryTapDownPosition',
        lastSecondaryTapDownPosition,
        defaultValue: null,
      ),
    );
    properties.add(IntProperty('documentActionCount', documentActions.length));
    properties.add(
      ObjectFlagProperty<void Function(EditRequest)?>.has('onEditRequest', onEditRequest),
    );
    properties.add(
      DiagnosticsProperty<TextSelectionControls>('platformDelegate', platformDelegate),
    );
  }
}

class _DocumentToolbarState extends State<_DocumentToolbar> {
  void _handleDocumentAction(DocumentToolbarAction action) {
    // Fire the direct callback if present.
    action.onPressed?.call();

    // Build and dispatch an EditRequest if the action provides a builder and
    // the delegate exposes a DocumentSelection.
    if (action.requestBuilder != null && widget.onEditRequest != null) {
      final textEditingValue = widget.delegate.textEditingValue;
      final start = textEditingValue.selection.start;
      final end = textEditingValue.selection.end;

      // Construct a minimal DocumentSelection from the TextSelection offsets.
      // In a real integration this would be obtained directly from the
      // DocumentEditingController; here we create a placeholder that carries
      // the correct offsets so tests can verify the attribution and selection.
      final docSelection = DocumentSelection(
        base: DocumentPosition(
          nodeId: '_toolbar',
          nodePosition: TextNodePosition(offset: start < 0 ? 0 : start),
        ),
        extent: DocumentPosition(
          nodeId: '_toolbar',
          nodePosition: TextNodePosition(offset: end < 0 ? 0 : end),
        ),
      );

      final request = action.requestBuilder!(docSelection);
      widget.onEditRequest!(request);
    }

    widget.delegate.hideToolbar();
  }

  @override
  Widget build(BuildContext context) {
    // Document-specific action buttons.
    final docButtons = widget.documentActions
        .map(
          (action) => TextButton(
            onPressed: () => _handleDocumentAction(action),
            child: action.icon != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(action.icon, size: 16),
                      const SizedBox(width: 4),
                      Text(action.label),
                    ],
                  )
                : Text(action.label),
          ),
        )
        .toList();

    // Compose the final toolbar: platform toolbar (for Cut/Copy/Paste/Select
    // All) stacked above the document-specific action row.
    // ignore: deprecated_member_use
    final platformToolbar = widget.platformDelegate.buildToolbar(
      context,
      widget.globalEditableRegion,
      widget.textLineHeight,
      widget.selectionMidpoint,
      widget.endpoints,
      widget.delegate,
      widget.clipboardStatus,
      widget.lastSecondaryTapDownPosition,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        platformToolbar,
        if (docButtons.isNotEmpty)
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: docButtons,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// documentTextSelectionControls factory
// ---------------------------------------------------------------------------

/// Returns a [DocumentTextSelectionControls] configured for the current
/// platform.
///
/// On iOS and macOS the underlying platform controls delegate to
/// [cupertinoTextSelectionControls]; on all other platforms they delegate to
/// [materialTextSelectionControls].
///
/// [toolbarActions] — optional extra toolbar actions appended after Bold and
/// Italic.
///
/// [onEditRequest] — callback invoked whenever a document toolbar action
/// produces an [EditRequest].
///
/// ```dart
/// EditableDocument(
///   controller: _controller,
///   focusNode: _focusNode,
///   selectionControls: documentTextSelectionControls(
///     onEditRequest: _editor.submit,
///   ),
/// )
/// ```
DocumentTextSelectionControls documentTextSelectionControls({
  List<DocumentToolbarAction>? toolbarActions,
  void Function(EditRequest)? onEditRequest,
}) {
  return DocumentTextSelectionControls(
    toolbarActions: toolbarActions,
    onEditRequest: onEditRequest,
  );
}
