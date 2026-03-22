/// Tests for [DefaultDocumentEditingShortcuts].
///
/// Verifies that the shortcuts map is correctly populated for each platform
/// and that all document-specific shortcut activators map to the expected
/// [Intent] types.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Finds the [Intent] in [map] whose key is a [SingleActivator] matching
/// [trigger] and the given modifier flags.
///
/// [SingleActivator] does not override `==` / `hashCode`, so direct map
/// lookup `map[SingleActivator(...)]` always returns `null`. We iterate
/// instead and compare the activator's fields.
Intent? _findIntent(
  Map<ShortcutActivator, Intent> map,
  LogicalKeyboardKey trigger, {
  bool meta = false,
  bool control = false,
  bool shift = false,
  bool alt = false,
}) {
  for (final entry in map.entries) {
    final activator = entry.key;
    if (activator is SingleActivator &&
        activator.trigger == trigger &&
        activator.meta == meta &&
        activator.control == control &&
        activator.shift == shift &&
        activator.alt == alt) {
      return entry.value;
    }
  }
  return null;
}

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  // =========================================================================
  // Widget presence
  // =========================================================================

  group('DefaultDocumentEditingShortcuts widget', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DefaultDocumentEditingShortcuts(
            child: Placeholder(),
          ),
        ),
      );
      expect(find.byType(Placeholder), findsOneWidget);
    });

    testWidgets('shortcutsFor returns non-empty map for macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.macOS);
      expect(map, isNotEmpty);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('shortcutsFor returns non-empty map for Linux', (tester) async {
      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.linux);
      expect(map, isNotEmpty);
    });
  });

  // =========================================================================
  // macOS shortcuts
  // =========================================================================

  group('macOS shortcuts', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    });

    test('Cmd+B maps to ToggleAttributionIntent(bold)', () {
      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.macOS);
      final intent = _findIntent(map, LogicalKeyboardKey.keyB, meta: true);
      expect(intent, isA<ToggleAttributionIntent>());
      expect((intent as ToggleAttributionIntent).attribution, NamedAttribution.bold);
    });

    test('Cmd+I maps to ToggleAttributionIntent(italics)', () {
      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.macOS);
      final intent = _findIntent(map, LogicalKeyboardKey.keyI, meta: true);
      expect(intent, isA<ToggleAttributionIntent>());
      expect((intent as ToggleAttributionIntent).attribution, NamedAttribution.italics);
    });

    test('Cmd+U maps to ToggleAttributionIntent(underline)', () {
      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.macOS);
      final intent = _findIntent(map, LogicalKeyboardKey.keyU, meta: true);
      expect(intent, isA<ToggleAttributionIntent>());
      expect((intent as ToggleAttributionIntent).attribution, NamedAttribution.underline);
    });

    test('Escape maps to CollapseSelectionIntent', () {
      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.macOS);
      final intent = _findIntent(map, LogicalKeyboardKey.escape);
      expect(intent, isA<CollapseSelectionIntent>());
    });

    test('Tab maps to DocumentTabIntent', () {
      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.macOS);
      final intent = _findIntent(map, LogicalKeyboardKey.tab);
      expect(intent, isA<DocumentTabIntent>());
    });

    test('Shift+Tab maps to DocumentShiftTabIntent', () {
      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.macOS);
      final intent = _findIntent(map, LogicalKeyboardKey.tab, shift: true);
      expect(intent, isA<DocumentShiftTabIntent>());
    });
  });

  // =========================================================================
  // Linux/Windows shortcuts
  // =========================================================================

  group('Linux shortcuts', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    });

    test('Ctrl+B maps to ToggleAttributionIntent(bold)', () {
      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.linux);
      final intent = _findIntent(map, LogicalKeyboardKey.keyB, control: true);
      expect(intent, isA<ToggleAttributionIntent>());
      expect((intent as ToggleAttributionIntent).attribution, NamedAttribution.bold);
    });

    test('Ctrl+I maps to ToggleAttributionIntent(italics)', () {
      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.linux);
      final intent = _findIntent(map, LogicalKeyboardKey.keyI, control: true);
      expect(intent, isA<ToggleAttributionIntent>());
      expect((intent as ToggleAttributionIntent).attribution, NamedAttribution.italics);
    });

    test('Ctrl+U maps to ToggleAttributionIntent(underline)', () {
      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.linux);
      final intent = _findIntent(map, LogicalKeyboardKey.keyU, control: true);
      expect(intent, isA<ToggleAttributionIntent>());
      expect((intent as ToggleAttributionIntent).attribution, NamedAttribution.underline);
    });

    test('Escape maps to CollapseSelectionIntent', () {
      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.linux);
      final intent = _findIntent(map, LogicalKeyboardKey.escape);
      expect(intent, isA<CollapseSelectionIntent>());
    });
  });

  // =========================================================================
  // Windows shortcuts
  // =========================================================================

  group('Windows shortcuts', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    });

    test('Ctrl+B maps to ToggleAttributionIntent(bold)', () {
      final map = DefaultDocumentEditingShortcuts.shortcutsFor(TargetPlatform.windows);
      final intent = _findIntent(map, LogicalKeyboardKey.keyB, control: true);
      expect(intent, isA<ToggleAttributionIntent>());
    });
  });
}
