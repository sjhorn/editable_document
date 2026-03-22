/// Tests for [PropertyPanelTheme] and [PropertyPanelThemeData].
library;

import 'package:editable_document/src/widgets/theme/property_panel_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PropertyPanelThemeData', () {
    test('default constructor — all fields are null', () {
      const data = PropertyPanelThemeData();
      expect(data.backgroundColor, isNull);
      expect(data.borderSide, isNull);
      expect(data.width, isNull);
      expect(data.padding, isNull);
      expect(data.sectionLabelStyle, isNull);
      expect(data.fieldLabelStyle, isNull);
      expect(data.sectionSpacing, isNull);
    });

    test('copyWith — overrides only provided fields', () {
      const original = PropertyPanelThemeData(
        width: 280.0,
        sectionSpacing: 12.0,
      );
      final copy = original.copyWith(width: 320.0);

      expect(copy.width, 320.0);
      expect(copy.sectionSpacing, 12.0); // unchanged
      expect(copy.backgroundColor, isNull); // still null
    });

    test('copyWith — no arguments preserves all fields', () {
      const original = PropertyPanelThemeData(
        width: 280.0,
        sectionSpacing: 12.0,
        backgroundColor: Color(0xFFFFFFFF),
      );
      final copy = original.copyWith();

      expect(copy.width, 280.0);
      expect(copy.sectionSpacing, 12.0);
      expect(copy.backgroundColor, const Color(0xFFFFFFFF));
    });

    test('equality — identical field values are equal', () {
      const a = PropertyPanelThemeData(width: 280.0, sectionSpacing: 12.0);
      const b = PropertyPanelThemeData(width: 280.0, sectionSpacing: 12.0);
      expect(a, equals(b));
    });

    test('equality — different field values are not equal', () {
      const a = PropertyPanelThemeData(width: 280.0);
      const b = PropertyPanelThemeData(width: 320.0);
      expect(a, isNot(equals(b)));
    });

    test('hashCode — equal objects have equal hashCode', () {
      const a = PropertyPanelThemeData(width: 280.0, sectionSpacing: 12.0);
      const b = PropertyPanelThemeData(width: 280.0, sectionSpacing: 12.0);
      expect(a.hashCode, b.hashCode);
    });

    test('debugFillProperties — includes key fields', () {
      const data = PropertyPanelThemeData(
        width: 280.0,
        sectionSpacing: 12.0,
        backgroundColor: Color(0xFFFFFFFF),
      );
      final builder = DiagnosticPropertiesBuilder();
      data.debugFillProperties(builder);

      final names = builder.properties.map((DiagnosticsNode p) => p.name).toList();
      expect(names, containsAll(['width', 'sectionSpacing', 'backgroundColor']));
    });
  });

  group('PropertyPanelTheme widget', () {
    testWidgets('of() returns default when no ancestor', (tester) async {
      late PropertyPanelThemeData captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = PropertyPanelTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(captured.width, isNull);
      expect(captured.backgroundColor, isNull);
    });

    testWidgets('of() returns data from ancestor', (tester) async {
      const data = PropertyPanelThemeData(width: 300.0, sectionSpacing: 16.0);
      late PropertyPanelThemeData captured;

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyPanelTheme(
            data: data,
            child: Builder(
              builder: (context) {
                captured = PropertyPanelTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured.width, 300.0);
      expect(captured.sectionSpacing, 16.0);
    });

    testWidgets('maybeOf() returns null when no ancestor', (tester) async {
      PropertyPanelThemeData? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = PropertyPanelTheme.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(captured, isNull);
    });

    testWidgets('maybeOf() returns data when ancestor exists', (tester) async {
      const data = PropertyPanelThemeData(width: 280.0);
      PropertyPanelThemeData? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyPanelTheme(
            data: data,
            child: Builder(
              builder: (context) {
                captured = PropertyPanelTheme.maybeOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured, isNotNull);
      expect(captured!.width, 280.0);
    });

    testWidgets('nearer ancestor wins over farther', (tester) async {
      const outer = PropertyPanelThemeData(width: 280.0);
      const inner = PropertyPanelThemeData(width: 320.0);
      late PropertyPanelThemeData captured;

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyPanelTheme(
            data: outer,
            child: PropertyPanelTheme(
              data: inner,
              child: Builder(
                builder: (context) {
                  captured = PropertyPanelTheme.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(captured.width, 320.0);
    });

    testWidgets('updateShouldNotify — rebuilds when data differs', (tester) async {
      var buildCount = 0;
      const dataA = PropertyPanelThemeData(width: 280.0);
      const dataB = PropertyPanelThemeData(width: 320.0);

      final notifier = ValueNotifier<PropertyPanelThemeData>(dataA);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<PropertyPanelThemeData>(
            valueListenable: notifier,
            builder: (context, data, _) => PropertyPanelTheme(
              data: data,
              child: Builder(
                builder: (context) {
                  PropertyPanelTheme.of(context);
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
  });
}
