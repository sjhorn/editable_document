/// Tests for [DocumentSettingsPanel].
library;

import 'package:editable_document/src/rendering/render_document_layout.dart';
import 'package:editable_document/src/widgets/properties/document_settings_panel.dart';
import 'package:editable_document/src/widgets/theme/property_panel_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  group('DocumentSettingsPanel — construction', () {
    testWidgets('renders without error with minimum required parameters', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(DocumentSettingsPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders "Document Settings" heading', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Document Settings'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Block Spacing section
  // ---------------------------------------------------------------------------

  group('DocumentSettingsPanel — Block Spacing', () {
    testWidgets('renders Block Spacing section label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Block Spacing'), findsOneWidget);
    });

    testWidgets('shows current blockSpacing selection in dropdown', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Single'), findsWidgets);
    });

    testWidgets('block spacing dropdown fires callback with new value', (tester) async {
      double? result;
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (v) => result = v,
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButton<double>).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Double').last);
      await tester.pumpAndSettle();

      expect(result, 24.0);
    });
  });

  // ---------------------------------------------------------------------------
  // Default Line Height section
  // ---------------------------------------------------------------------------

  group('DocumentSettingsPanel — Default Line Height', () {
    testWidgets('renders Default Line Height section label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Default Line Height'), findsOneWidget);
    });

    testWidgets('line height dropdown fires callback with new value', (tester) async {
      double? result = 1.15;
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: 1.15,
            onDefaultLineHeightChanged: (v) => result = v,
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
          ),
        ),
      );

      // Open the line height dropdown.
      await tester.tap(find.byType(DropdownButton<double?>).first);
      await tester.pumpAndSettle();

      // Select "Double" (2.0).
      await tester.tap(find.text('Double').last);
      await tester.pumpAndSettle();

      expect(result, 2.0);
    });
  });

  // ---------------------------------------------------------------------------
  // Document Padding section
  // ---------------------------------------------------------------------------

  group('DocumentSettingsPanel — Document Padding', () {
    testWidgets('renders Document Padding section label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Document Padding'), findsOneWidget);
    });

    testWidgets('horizontal slider fires onDocumentPaddingChanged with updated H', (tester) async {
      EdgeInsets? result;
      const initialPadding = EdgeInsets.symmetric(horizontal: 0, vertical: 20);

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            child: DocumentSettingsPanel(
              blockSpacing: 0.0,
              onBlockSpacingChanged: (_) {},
              defaultLineHeight: null,
              onDefaultLineHeightChanged: (_) {},
              documentPadding: initialPadding,
              onDocumentPaddingChanged: (v) => result = v,
            ),
          ),
        ),
      );

      // Drag the horizontal slider.
      final sliders = find.byType(Slider);
      expect(sliders, findsNWidgets(2));

      // Drag the first slider (horizontal) to the right.
      await tester.drag(sliders.first, const Offset(100, 0));
      await tester.pump();

      expect(result, isNotNull);
      // Vertical component should remain unchanged.
      expect(result!.top, 20.0);
      expect(result!.bottom, 20.0);
    });

    testWidgets('vertical slider fires onDocumentPaddingChanged with updated V', (tester) async {
      EdgeInsets? result;
      const initialPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 0);

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            child: DocumentSettingsPanel(
              blockSpacing: 0.0,
              onBlockSpacingChanged: (_) {},
              defaultLineHeight: null,
              onDefaultLineHeightChanged: (_) {},
              documentPadding: initialPadding,
              onDocumentPaddingChanged: (v) => result = v,
            ),
          ),
        ),
      );

      // Drag the second slider (vertical) to the right.
      final sliders = find.byType(Slider);
      await tester.drag(sliders.last, const Offset(100, 0));
      await tester.pump();

      expect(result, isNotNull);
      // Horizontal component should remain unchanged.
      expect(result!.left, 20.0);
      expect(result!.right, 20.0);
    });
  });

  // ---------------------------------------------------------------------------
  // Line Numbers section
  // ---------------------------------------------------------------------------

  group('DocumentSettingsPanel — Line Numbers', () {
    testWidgets('Line Numbers section is hidden when onShowLineNumbersChanged is null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Line Numbers'), findsNothing);
    });

    testWidgets('Line Numbers section shows when onShowLineNumbersChanged is provided',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
            onShowLineNumbersChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Line Numbers'), findsOneWidget);
    });

    testWidgets('line numbers toggle fires callback', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
            showLineNumbers: false,
            onShowLineNumbersChanged: (v) => result = v,
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(result, isTrue);
    });

    testWidgets('alignment controls hidden when showLineNumbers is false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
            showLineNumbers: false,
            onShowLineNumbersChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Vertical Alignment'), findsNothing);
    });

    testWidgets('alignment controls shown when showLineNumbers is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
            showLineNumbers: true,
            onShowLineNumbersChanged: (_) {},
            lineNumberAlignment: LineNumberAlignment.top,
            onLineNumberAlignmentChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Vertical Alignment'), findsOneWidget);
    });

    testWidgets('alignment button fires onLineNumberAlignmentChanged', (tester) async {
      LineNumberAlignment? result;
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
            showLineNumbers: true,
            onShowLineNumbersChanged: (_) {},
            lineNumberAlignment: LineNumberAlignment.top,
            onLineNumberAlignmentChanged: (v) => result = v,
          ),
        ),
      );

      // Tap the "middle" alignment button (Icons.vertical_align_center).
      await tester.tap(find.byIcon(Icons.vertical_align_center));
      await tester.pump();

      expect(result, LineNumberAlignment.middle);
    });

    testWidgets('font family dropdown fires callback', (tester) async {
      String? result = 'Georgia';
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
            showLineNumbers: true,
            onShowLineNumbersChanged: (_) {},
            lineNumberFontFamily: 'Georgia',
            onLineNumberFontFamilyChanged: (v) => result = v,
          ),
        ),
      );

      // Open font family dropdown.
      await tester.tap(find.byType(DropdownButton<String?>).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Default').last);
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('font size dropdown fires callback', (tester) async {
      double? result;
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
            showLineNumbers: true,
            onShowLineNumbersChanged: (_) {},
            lineNumberFontSize: null,
            onLineNumberFontSizeChanged: (v) => result = v,
          ),
        ),
      );

      // There are two DropdownButton<double?> widgets: line height and font size.
      // The font size dropdown is the last one.
      await tester.tap(find.byType(DropdownButton<double?>).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('12').last);
      await tester.pumpAndSettle();

      expect(result, 12.0);
    });
  });

  // ---------------------------------------------------------------------------
  // PropertyPanelTheme width
  // ---------------------------------------------------------------------------

  group('DocumentSettingsPanel — PropertyPanelTheme width', () {
    testWidgets('uses PropertyPanelTheme width when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PropertyPanelTheme(
            data: const PropertyPanelThemeData(width: 320.0),
            child: DocumentSettingsPanel(
              blockSpacing: 0.0,
              onBlockSpacingChanged: (_) {},
              defaultLineHeight: null,
              onDefaultLineHeightChanged: (_) {},
              documentPadding: EdgeInsets.zero,
              onDocumentPaddingChanged: (_) {},
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(DocumentSettingsPanel),
              matching: find.byWidgetPredicate(
                (w) => w is SizedBox && w.width == 320.0,
              ),
            )
            .first,
      );
      expect(sizedBox.width, 320.0);
    });

    testWidgets('falls back to width parameter when no PropertyPanelTheme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
            width: 300.0,
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(DocumentSettingsPanel),
              matching: find.byWidgetPredicate(
                (w) => w is SizedBox && w.width == 300.0,
              ),
            )
            .first,
      );
      expect(sizedBox.width, 300.0);
    });
  });

  // ---------------------------------------------------------------------------
  // Color pickers
  // ---------------------------------------------------------------------------

  group('DocumentSettingsPanel — color pickers', () {
    testWidgets('number color picker visible when showLineNumbers is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSettingsPanel(
            blockSpacing: 0.0,
            onBlockSpacingChanged: (_) {},
            defaultLineHeight: null,
            onDefaultLineHeightChanged: (_) {},
            documentPadding: EdgeInsets.zero,
            onDocumentPaddingChanged: (_) {},
            showLineNumbers: true,
            onShowLineNumbersChanged: (_) {},
            lineNumberColor: null,
            onLineNumberColorChanged: (_) {},
            lineNumberBackgroundColor: null,
            onLineNumberBackgroundColorChanged: (_) {},
          ),
        ),
      );

      // Both color pickers (number + gutter bg) should be present.
      expect(find.text('Color'), findsOneWidget);
    });
  });
}
