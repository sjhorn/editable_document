/// Tests for [DocumentToolbarTheme] and [DocumentToolbarThemeData].
library;

import 'package:editable_document/src/widgets/theme/document_toolbar_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentToolbarThemeData', () {
    test('default constructor — all fields are null', () {
      const data = DocumentToolbarThemeData();
      expect(data.backgroundColor, isNull);
      expect(data.borderSide, isNull);
      expect(data.padding, isNull);
      expect(data.iconSize, isNull);
      expect(data.buttonSize, isNull);
      expect(data.dividerColor, isNull);
      expect(data.activeColor, isNull);
      expect(data.activeIconColor, isNull);
      expect(data.disabledColor, isNull);
    });

    test('copyWith — overrides only the provided fields', () {
      const original = DocumentToolbarThemeData(
        iconSize: 18.0,
        buttonSize: 32.0,
      );
      final copy = original.copyWith(iconSize: 24.0);

      expect(copy.iconSize, 24.0);
      expect(copy.buttonSize, 32.0); // unchanged
      expect(copy.backgroundColor, isNull); // still null
    });

    test('copyWith — all null arguments returns identical values', () {
      const original = DocumentToolbarThemeData(
        iconSize: 18.0,
        dividerColor: Color(0xFFCCCCCC),
      );
      final copy = original.copyWith();

      expect(copy.iconSize, 18.0);
      expect(copy.dividerColor, const Color(0xFFCCCCCC));
    });

    test('equality — identical field values are equal', () {
      const a = DocumentToolbarThemeData(
        iconSize: 18.0,
        buttonSize: 32.0,
      );
      const b = DocumentToolbarThemeData(
        iconSize: 18.0,
        buttonSize: 32.0,
      );
      expect(a, equals(b));
    });

    test('equality — different field values are not equal', () {
      const a = DocumentToolbarThemeData(iconSize: 18.0);
      const b = DocumentToolbarThemeData(iconSize: 24.0);
      expect(a, isNot(equals(b)));
    });
  });

  group('DocumentToolbarTheme', () {
    testWidgets('of() returns theme data from nearest ancestor', (tester) async {
      const data = DocumentToolbarThemeData(iconSize: 20.0);
      late DocumentToolbarThemeData captured;

      await tester.pumpWidget(
        MaterialApp(
          home: DocumentToolbarTheme(
            data: data,
            child: Builder(
              builder: (context) {
                captured = DocumentToolbarTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured.iconSize, 20.0);
    });

    testWidgets('maybeOf() returns null when no ancestor exists', (tester) async {
      DocumentToolbarThemeData? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = DocumentToolbarTheme.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(captured, isNull);
    });

    testWidgets('of() returns default instance when no ancestor exists', (tester) async {
      late DocumentToolbarThemeData captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = DocumentToolbarTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // Default has all nulls.
      expect(captured.iconSize, isNull);
      expect(captured.buttonSize, isNull);
    });

    testWidgets('nearer ancestor wins over farther ancestor', (tester) async {
      const outer = DocumentToolbarThemeData(iconSize: 18.0);
      const inner = DocumentToolbarThemeData(iconSize: 24.0);
      late DocumentToolbarThemeData captured;

      await tester.pumpWidget(
        MaterialApp(
          home: DocumentToolbarTheme(
            data: outer,
            child: DocumentToolbarTheme(
              data: inner,
              child: Builder(
                builder: (context) {
                  captured = DocumentToolbarTheme.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(captured.iconSize, 24.0);
    });
  });
}
