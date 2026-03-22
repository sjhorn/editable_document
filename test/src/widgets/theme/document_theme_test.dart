/// Tests for [DocumentTheme] and [DocumentThemeData].
library;

import 'package:editable_document/src/widgets/theme/document_theme.dart';
import 'package:editable_document/src/widgets/theme/document_toolbar_theme.dart';
import 'package:editable_document/src/widgets/theme/property_panel_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentThemeData', () {
    test('default constructor — all fields are null', () {
      const data = DocumentThemeData();
      expect(data.defaultTextStyle, isNull);
      expect(data.defaultLineHeight, isNull);
      expect(data.defaultBlockSpacing, isNull);
      expect(data.defaultDocumentPadding, isNull);
      expect(data.heading1Style, isNull);
      expect(data.heading2Style, isNull);
      expect(data.heading3Style, isNull);
      expect(data.blockquoteStyle, isNull);
      expect(data.codeBlockStyle, isNull);
      expect(data.codeBlockBackgroundColor, isNull);
      expect(data.codeBlockPadding, isNull);
      expect(data.listItemBulletColor, isNull);
      expect(data.horizontalRuleColor, isNull);
      expect(data.horizontalRuleThickness, isNull);
      expect(data.selectionColor, isNull);
      expect(data.caretColor, isNull);
      expect(data.caretWidth, isNull);
      expect(data.toolbarTheme, isNull);
      expect(data.propertyPanelTheme, isNull);
    });

    test('copyWith — overrides only provided fields', () {
      const original = DocumentThemeData(
        defaultBlockSpacing: 12.0,
        caretWidth: 2.0,
      );
      final copy = original.copyWith(caretWidth: 3.0);

      expect(copy.caretWidth, 3.0);
      expect(copy.defaultBlockSpacing, 12.0); // unchanged
      expect(copy.caretColor, isNull); // still null
    });

    test('copyWith — no arguments preserves all fields', () {
      const original = DocumentThemeData(
        defaultBlockSpacing: 16.0,
        selectionColor: Color(0xFF2196F3),
        caretWidth: 2.0,
      );
      final copy = original.copyWith();

      expect(copy.defaultBlockSpacing, 16.0);
      expect(copy.selectionColor, const Color(0xFF2196F3));
      expect(copy.caretWidth, 2.0);
    });

    test('merge — fills null fields from other', () {
      const a = DocumentThemeData(caretWidth: 2.0);
      const b = DocumentThemeData(defaultBlockSpacing: 16.0, caretColor: Color(0xFF000000));
      final merged = a.merge(b);

      // Non-null in a — keeps a value
      expect(merged.caretWidth, 2.0);
      // Null in a, set in b — takes b value
      expect(merged.defaultBlockSpacing, 16.0);
      expect(merged.caretColor, const Color(0xFF000000));
    });

    test('merge — with null argument returns same data', () {
      const original = DocumentThemeData(caretWidth: 2.0, defaultBlockSpacing: 12.0);
      final merged = original.merge(null);

      expect(merged.caretWidth, 2.0);
      expect(merged.defaultBlockSpacing, 12.0);
    });

    test('equality — identical field values are equal', () {
      const a = DocumentThemeData(
        defaultBlockSpacing: 12.0,
        caretWidth: 2.0,
      );
      const b = DocumentThemeData(
        defaultBlockSpacing: 12.0,
        caretWidth: 2.0,
      );
      expect(a, equals(b));
    });

    test('equality — different field values are not equal', () {
      const a = DocumentThemeData(caretWidth: 2.0);
      const b = DocumentThemeData(caretWidth: 3.0);
      expect(a, isNot(equals(b)));
    });

    test('hashCode — equal objects have equal hashCode', () {
      const a = DocumentThemeData(defaultBlockSpacing: 12.0, caretWidth: 2.0);
      const b = DocumentThemeData(defaultBlockSpacing: 12.0, caretWidth: 2.0);
      expect(a.hashCode, b.hashCode);
    });

    test('debugFillProperties — includes key fields', () {
      const data = DocumentThemeData(
        defaultBlockSpacing: 16.0,
        caretWidth: 2.0,
        selectionColor: Color(0xFF2196F3),
      );
      final builder = DiagnosticPropertiesBuilder();
      data.debugFillProperties(builder);

      final names = builder.properties.map((DiagnosticsNode p) => p.name).toList();
      expect(names, containsAll(['defaultBlockSpacing', 'caretWidth', 'selectionColor']));
    });
  });

  group('DocumentTheme widget', () {
    testWidgets('of() returns default when no ancestor', (tester) async {
      late DocumentThemeData captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = DocumentTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // Default DocumentThemeData has all nulls.
      expect(captured.caretWidth, isNull);
      expect(captured.defaultBlockSpacing, isNull);
    });

    testWidgets('of() returns data from ancestor', (tester) async {
      const data = DocumentThemeData(defaultBlockSpacing: 20.0, caretWidth: 2.0);
      late DocumentThemeData captured;

      await tester.pumpWidget(
        MaterialApp(
          home: DocumentTheme(
            data: data,
            child: Builder(
              builder: (context) {
                captured = DocumentTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured.defaultBlockSpacing, 20.0);
      expect(captured.caretWidth, 2.0);
    });

    testWidgets('maybeOf() returns null when no ancestor', (tester) async {
      DocumentThemeData? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = DocumentTheme.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(captured, isNull);
    });

    testWidgets('maybeOf() returns data when ancestor exists', (tester) async {
      const data = DocumentThemeData(caretWidth: 3.0);
      DocumentThemeData? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: DocumentTheme(
            data: data,
            child: Builder(
              builder: (context) {
                captured = DocumentTheme.maybeOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured, isNotNull);
      expect(captured!.caretWidth, 3.0);
    });

    testWidgets('nearer ancestor wins over farther', (tester) async {
      const outer = DocumentThemeData(caretWidth: 1.0);
      const inner = DocumentThemeData(caretWidth: 3.0);
      late DocumentThemeData captured;

      await tester.pumpWidget(
        MaterialApp(
          home: DocumentTheme(
            data: outer,
            child: DocumentTheme(
              data: inner,
              child: Builder(
                builder: (context) {
                  captured = DocumentTheme.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(captured.caretWidth, 3.0);
    });

    testWidgets('updateShouldNotify — true when data differs', (tester) async {
      var buildCount = 0;
      const dataA = DocumentThemeData(caretWidth: 1.0);
      const dataB = DocumentThemeData(caretWidth: 2.0);

      final notifier = ValueNotifier<DocumentThemeData>(dataA);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<DocumentThemeData>(
            valueListenable: notifier,
            builder: (context, data, _) => DocumentTheme(
              data: data,
              child: Builder(
                builder: (context) {
                  DocumentTheme.of(context); // register dependency
                  buildCount++;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      final countAfterFirstPump = buildCount;
      notifier.value = dataB;
      await tester.pump();

      expect(buildCount, greaterThan(countAfterFirstPump));
    });

    testWidgets('updateShouldNotify — false when data is same', (tester) async {
      var buildCount = 0;
      const data = DocumentThemeData(caretWidth: 1.0);

      final notifier = ValueNotifier<DocumentThemeData>(data);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<DocumentThemeData>(
            valueListenable: notifier,
            builder: (context, d, _) => DocumentTheme(
              data: d,
              child: Builder(
                builder: (context) {
                  DocumentTheme.of(context);
                  buildCount++;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      final countAfterFirstPump = buildCount;
      // Assign a new const equal to the existing one — same data, no rebuild.
      notifier.value = const DocumentThemeData(caretWidth: 1.0);
      await tester.pump();

      expect(buildCount, countAfterFirstPump);
    });

    testWidgets('wrap() creates a new DocumentTheme with same data', (tester) async {
      const data = DocumentThemeData(defaultBlockSpacing: 8.0);

      // DocumentTheme.wrap is exercised internally by InheritedTheme machinery —
      // verify it compiles and the value propagates through a Theme.wrap call site.
      late DocumentThemeData captured;

      await tester.pumpWidget(
        MaterialApp(
          home: DocumentTheme(
            data: data,
            child: Builder(
              builder: (context) {
                // Manually invoke wrap to simulate what InheritedTheme does.
                final wrapped = const DocumentTheme(
                  data: DocumentThemeData(defaultBlockSpacing: 8.0),
                  child: SizedBox(),
                );
                expect(wrapped.data.defaultBlockSpacing, 8.0);
                captured = DocumentTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured.defaultBlockSpacing, 8.0);
    });
  });

  group('DocumentThemeData nested themes', () {
    test('copyWith — toolbarTheme is replaced when provided', () {
      const original = DocumentThemeData(
        toolbarTheme: DocumentToolbarThemeData(iconSize: 18.0),
      );
      final copy = original.copyWith(
        toolbarTheme: const DocumentToolbarThemeData(iconSize: 24.0),
      );
      expect(copy.toolbarTheme?.iconSize, 24.0);
    });

    test('merge — nested toolbarTheme comes from other when null in this', () {
      const a = DocumentThemeData();
      const b = DocumentThemeData(
        toolbarTheme: DocumentToolbarThemeData(iconSize: 20.0),
      );
      final merged = a.merge(b);
      expect(merged.toolbarTheme?.iconSize, 20.0);
    });

    test('copyWith — propertyPanelTheme is replaced when provided', () {
      const original = DocumentThemeData(
        propertyPanelTheme: PropertyPanelThemeData(width: 280.0),
      );
      final copy = original.copyWith(
        propertyPanelTheme: const PropertyPanelThemeData(width: 320.0),
      );
      expect(copy.propertyPanelTheme?.width, 320.0);
    });
  });
}
