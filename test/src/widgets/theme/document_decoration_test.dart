/// Tests for [DocumentDecoration], [DocumentToolbarPosition], and
/// [DocumentPanelPosition].
library;

import 'package:editable_document/src/widgets/theme/document_decoration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentDecoration', () {
    test('default values are correct', () {
      const decoration = DocumentDecoration();

      expect(decoration.backgroundColor, isNull);
      expect(decoration.border, isNull);
      expect(decoration.borderRadius, isNull);
      expect(decoration.padding, isNull);
      expect(decoration.showToolbar, isFalse);
      expect(decoration.showPropertyPanel, isFalse);
      expect(decoration.showStatusBar, isFalse);
      expect(decoration.toolbarPosition, DocumentToolbarPosition.top);
      expect(decoration.propertyPanelPosition, DocumentPanelPosition.end);
    });

    test('copyWith — overrides only provided fields', () {
      const original = DocumentDecoration(
        showToolbar: true,
        toolbarPosition: DocumentToolbarPosition.bottom,
      );
      final copy = original.copyWith(showToolbar: false);

      expect(copy.showToolbar, isFalse);
      expect(copy.toolbarPosition, DocumentToolbarPosition.bottom); // unchanged
      expect(copy.backgroundColor, isNull); // still null
    });

    test('copyWith — no arguments preserves all fields', () {
      const original = DocumentDecoration(
        backgroundColor: Color(0xFFFFFFFF),
        showToolbar: true,
        showPropertyPanel: true,
        toolbarPosition: DocumentToolbarPosition.bottom,
        propertyPanelPosition: DocumentPanelPosition.start,
      );
      final copy = original.copyWith();

      expect(copy.backgroundColor, const Color(0xFFFFFFFF));
      expect(copy.showToolbar, isTrue);
      expect(copy.showPropertyPanel, isTrue);
      expect(copy.toolbarPosition, DocumentToolbarPosition.bottom);
      expect(copy.propertyPanelPosition, DocumentPanelPosition.start);
    });

    test('equality — identical values are equal', () {
      const a = DocumentDecoration(
        showToolbar: true,
        toolbarPosition: DocumentToolbarPosition.top,
      );
      const b = DocumentDecoration(
        showToolbar: true,
        toolbarPosition: DocumentToolbarPosition.top,
      );
      expect(a, equals(b));
    });

    test('equality — different values are not equal', () {
      const a = DocumentDecoration(showToolbar: true);
      const b = DocumentDecoration(showToolbar: false);
      expect(a, isNot(equals(b)));
    });

    test('hashCode — equal objects have equal hashCode', () {
      const a = DocumentDecoration(
        showToolbar: true,
        toolbarPosition: DocumentToolbarPosition.bottom,
      );
      const b = DocumentDecoration(
        showToolbar: true,
        toolbarPosition: DocumentToolbarPosition.bottom,
      );
      expect(a.hashCode, b.hashCode);
    });

    test('debugFillProperties — includes all boolean flags and positions', () {
      const decoration = DocumentDecoration(
        showToolbar: true,
        showPropertyPanel: false,
        showStatusBar: true,
        toolbarPosition: DocumentToolbarPosition.bottom,
        propertyPanelPosition: DocumentPanelPosition.start,
      );
      final builder = DiagnosticPropertiesBuilder();
      decoration.debugFillProperties(builder);

      final names = builder.properties.map((DiagnosticsNode p) => p.name).toList();
      expect(
        names,
        containsAll([
          'showToolbar',
          'showPropertyPanel',
          'showStatusBar',
          'toolbarPosition',
          'propertyPanelPosition',
        ]),
      );
    });
  });

  group('DocumentToolbarPosition', () {
    test('has top and bottom values', () {
      expect(DocumentToolbarPosition.values, contains(DocumentToolbarPosition.top));
      expect(DocumentToolbarPosition.values, contains(DocumentToolbarPosition.bottom));
    });
  });

  group('DocumentPanelPosition', () {
    test('has start and end values', () {
      expect(DocumentPanelPosition.values, contains(DocumentPanelPosition.start));
      expect(DocumentPanelPosition.values, contains(DocumentPanelPosition.end));
    });
  });
}
