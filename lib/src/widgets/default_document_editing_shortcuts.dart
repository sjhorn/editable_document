/// Default keyboard shortcuts for document editing.
///
/// [DefaultDocumentEditingShortcuts] wraps its child with a [Shortcuts] widget
/// that maps document-specific key combinations to document-specific [Intent]s.
///
/// Flutter's `DefaultTextEditingShortcuts` (already injected by [MaterialApp]
/// and [WidgetsApp]) handles the standard text editing shortcuts (arrow keys,
/// Home/End, Ctrl+A select-all, Ctrl+C copy, etc.). This widget adds only the
/// shortcuts that are unique to block documents:
///
/// * **Cmd/Ctrl+B** — [ToggleAttributionIntent] for bold.
/// * **Cmd/Ctrl+I** — [ToggleAttributionIntent] for italics.
/// * **Cmd/Ctrl+U** — [ToggleAttributionIntent] for underline.
/// * **Escape** — [CollapseSelectionIntent].
/// * **Tab** — [DocumentTabIntent].
/// * **Shift+Tab** — [DocumentShiftTabIntent].
///
/// The primary modifier is platform-adaptive: `Meta` on macOS/iOS, `Control`
/// on all other platforms.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../model/attribution.dart';
import 'document_editing_intents.dart';

// ---------------------------------------------------------------------------
// DefaultDocumentEditingShortcuts
// ---------------------------------------------------------------------------

/// A widget that installs document-specific keyboard shortcut bindings.
///
/// Wraps [child] in a [Shortcuts] widget whose map covers formatting
/// shortcuts (bold, italic, underline), selection collapse (Escape), and
/// Tab/Shift+Tab document navigation.
///
/// Standard text-editing shortcuts (arrows, Home/End, Copy/Cut/Paste,
/// Select-All) are already provided by Flutter's
/// `DefaultTextEditingShortcuts`, which is injected by [MaterialApp].
///
/// Use [shortcutsFor] to inspect the full map for a given platform without
/// instantiating the widget.
class DefaultDocumentEditingShortcuts extends StatelessWidget {
  /// Creates a [DefaultDocumentEditingShortcuts] that wraps [child].
  const DefaultDocumentEditingShortcuts({super.key, required this.child});

  /// The widget below this widget in the tree.
  final Widget child;

  // -------------------------------------------------------------------------
  // Shortcut maps
  // -------------------------------------------------------------------------

  /// Returns the shortcut map for [platform].
  ///
  /// The map covers:
  /// - Formatting: bold (B), italic (I), underline (U).
  /// - Collapse: Escape → [CollapseSelectionIntent].
  /// - Tab navigation: Tab → [DocumentTabIntent], Shift+Tab →
  ///   [DocumentShiftTabIntent].
  ///
  /// The primary modifier (`meta` on macOS/iOS, `control` elsewhere) is
  /// chosen based on [platform].
  static Map<ShortcutActivator, Intent> shortcutsFor(TargetPlatform platform) {
    final meta = platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
    return {
      SingleActivator(LogicalKeyboardKey.keyB, meta: meta, control: !meta):
          const ToggleAttributionIntent(NamedAttribution.bold),
      SingleActivator(LogicalKeyboardKey.keyI, meta: meta, control: !meta):
          const ToggleAttributionIntent(NamedAttribution.italics),
      SingleActivator(LogicalKeyboardKey.keyU, meta: meta, control: !meta):
          const ToggleAttributionIntent(NamedAttribution.underline),
      const SingleActivator(LogicalKeyboardKey.escape): const CollapseSelectionIntent(),
      const SingleActivator(LogicalKeyboardKey.tab): const DocumentTabIntent(),
      const SingleActivator(LogicalKeyboardKey.tab, shift: true): const DocumentShiftTabIntent(),
    };
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: shortcutsFor(defaultTargetPlatform),
      child: child,
    );
  }
}
