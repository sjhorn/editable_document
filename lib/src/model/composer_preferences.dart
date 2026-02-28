/// Transient composer preferences for the editable_document package.
///
/// Provides [ComposerPreferences], which tracks the set of [Attribution]s that
/// should be applied to newly inserted text — analogous to the "current style"
/// concept in rich text editors.
library;

import 'package:flutter/foundation.dart';

import 'attribution.dart';

// ---------------------------------------------------------------------------
// ComposerPreferences
// ---------------------------------------------------------------------------

/// Transient editing preferences such as active attributions that should
/// be applied to newly inserted text.
///
/// This is analogous to the "current style" concept in rich text editors —
/// when bold is toggled on, all new text is bold until toggled off.
///
/// [ComposerPreferences] is intentionally mutable so that callers can
/// [activate], [deactivate], and [toggle] attributions in-place without
/// rebuilding the entire object. The owning [DocumentEditingController]
/// is responsible for notifying listeners when preferences change.
///
/// Example:
/// ```dart
/// final prefs = ComposerPreferences();
/// prefs.activate(NamedAttribution.bold);
/// assert(prefs.isActive(NamedAttribution.bold));
///
/// prefs.toggle(NamedAttribution.bold);
/// assert(!prefs.isActive(NamedAttribution.bold));
/// ```
class ComposerPreferences {
  /// Creates [ComposerPreferences] with the given active [attributions].
  ///
  /// When [attributions] is omitted or `null` the set starts empty.
  ComposerPreferences({Set<Attribution>? attributions})
      : _attributions = attributions != null ? Set<Attribution>.of(attributions) : <Attribution>{};

  final Set<Attribution> _attributions;

  /// The currently active attributions that will be applied to new text.
  ///
  /// Returns an unmodifiable view of the internal set. To mutate the active
  /// attributions use [activate], [deactivate], [toggle], or [clearAll].
  Set<Attribution> get attributions => Set<Attribution>.unmodifiable(_attributions);

  /// Whether [attribution] is currently active.
  bool isActive(Attribution attribution) => _attributions.contains(attribution);

  /// Adds [attribution] to the active set.
  ///
  /// If [attribution] is already active this is a no-op.
  void activate(Attribution attribution) => _attributions.add(attribution);

  /// Removes [attribution] from the active set.
  ///
  /// If [attribution] is not active this is a no-op.
  void deactivate(Attribution attribution) => _attributions.remove(attribution);

  /// Toggles [attribution]: activates if inactive, deactivates if active.
  void toggle(Attribution attribution) {
    if (isActive(attribution)) {
      deactivate(attribution);
    } else {
      activate(attribution);
    }
  }

  /// Removes all active attributions.
  void clearAll() => _attributions.clear();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ComposerPreferences && setEquals(_attributions, other._attributions);
  }

  @override
  int get hashCode => Object.hashAll(_attributions);

  @override
  String toString() => 'ComposerPreferences(attributions: $_attributions)';
}
