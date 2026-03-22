/// Tests verifying that toolbar and property panel widgets read
/// [DocumentToolbarTheme] and [PropertyPanelTheme] for their visual styling.
library;

import 'package:editable_document/src/model/document_editing_controller.dart';
import 'package:editable_document/src/model/mutable_document.dart';
import 'package:editable_document/src/widgets/properties/document_property_panel.dart';
import 'package:editable_document/src/widgets/properties/property_section.dart';
import 'package:editable_document/src/widgets/theme/document_toolbar_theme.dart';
import 'package:editable_document/src/widgets/theme/property_panel_theme.dart';
import 'package:editable_document/src/widgets/toolbar/document_format_toggle.dart';
import 'package:editable_document/src/widgets/toolbar/document_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _toolbarWithTheme({
  required DocumentToolbarThemeData themeData,
  required DocumentEditingController controller,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DocumentToolbarTheme(
          data: themeData,
          child: DocumentToolbar(
            controller: controller,
            requestHandler: (_) {},
          ),
        ),
      ),
    ),
  );
}

Widget _toggleWithTheme({
  required DocumentToolbarThemeData themeData,
  required bool isActive,
  VoidCallback? onPressed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: DocumentToolbarTheme(
        data: themeData,
        child: DocumentFormatToggle(
          icon: Icons.format_bold,
          tooltip: 'Bold',
          isActive: isActive,
          onPressed: onPressed,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// DocumentFormatToggle theme wiring
// ---------------------------------------------------------------------------

void main() {
  group('DocumentFormatToggle theme wiring', () {
    testWidgets('uses theme iconSize', (tester) async {
      await tester.pumpWidget(
        _toggleWithTheme(
          themeData: const DocumentToolbarThemeData(iconSize: 24.0),
          isActive: false,
          onPressed: () {},
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, 24.0);
    });

    testWidgets('uses theme buttonSize', (tester) async {
      await tester.pumpWidget(
        _toggleWithTheme(
          themeData: const DocumentToolbarThemeData(buttonSize: 40.0),
          isActive: false,
          onPressed: () {},
        ),
      );

      final sized = tester.widget<SizedBox>(
        find.descendant(of: find.byType(InkWell), matching: find.byType(SizedBox)).first,
      );
      expect(sized.width, 40.0);
      expect(sized.height, 40.0);
    });

    testWidgets('uses theme activeColor when isActive=true', (tester) async {
      const activeColor = Color(0xFFFF5722);

      await tester.pumpWidget(
        _toggleWithTheme(
          themeData: const DocumentToolbarThemeData(activeColor: activeColor),
          isActive: true,
          onPressed: () {},
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(of: find.byType(Tooltip), matching: find.byType(Material)).first,
      );
      expect(material.color, activeColor);
    });

    testWidgets('background is transparent when isActive=false', (tester) async {
      await tester.pumpWidget(
        _toggleWithTheme(
          themeData: const DocumentToolbarThemeData(activeColor: Color(0xFFFF5722)),
          isActive: false,
          onPressed: () {},
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(of: find.byType(Tooltip), matching: find.byType(Material)).first,
      );
      expect(material.color, Colors.transparent);
    });
  });

  // ---------------------------------------------------------------------------
  // DocumentToolbar theme wiring
  // ---------------------------------------------------------------------------

  group('DocumentToolbar theme wiring', () {
    testWidgets('uses theme backgroundColor', (tester) async {
      final controller = DocumentEditingController(document: MutableDocument());
      addTearDown(controller.dispose);
      const bgColor = Color(0xFFE0E0E0);

      await tester.pumpWidget(
        _toolbarWithTheme(
          themeData: const DocumentToolbarThemeData(backgroundColor: bgColor),
          controller: controller,
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, bgColor);
    });

    testWidgets('uses theme borderSide color', (tester) async {
      final controller = DocumentEditingController(document: MutableDocument());
      addTearDown(controller.dispose);
      const borderColor = Color(0xFFFF0000);

      await tester.pumpWidget(
        _toolbarWithTheme(
          themeData: const DocumentToolbarThemeData(
            borderSide: BorderSide(color: borderColor, width: 2.0),
          ),
          controller: controller,
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration?;
      final border = decoration?.border as Border?;
      expect(border?.bottom.color, borderColor);
      expect(border?.bottom.width, 2.0);
    });

    testWidgets('uses theme padding', (tester) async {
      final controller = DocumentEditingController(document: MutableDocument());
      addTearDown(controller.dispose);
      const customPadding = EdgeInsets.all(8.0);

      await tester.pumpWidget(
        _toolbarWithTheme(
          themeData: const DocumentToolbarThemeData(padding: customPadding),
          controller: controller,
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.padding, customPadding);
    });
  });

  // ---------------------------------------------------------------------------
  // PropertySection theme wiring
  // ---------------------------------------------------------------------------

  group('PropertySection theme wiring', () {
    testWidgets('uses PropertyPanelTheme sectionLabelStyle when provided', (tester) async {
      const labelStyle = TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PropertyPanelTheme(
              data: PropertyPanelThemeData(sectionLabelStyle: labelStyle),
              child: PropertySection(
                label: 'Test Section',
                child: SizedBox(),
              ),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Test Section'));
      expect(text.style?.fontSize, 14.0);
      expect(text.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('uses PropertyPanelTheme sectionSpacing when provided', (tester) async {
      final sectionKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyPanelTheme(
              data: const PropertyPanelThemeData(sectionSpacing: 24.0),
              child: PropertySection(
                key: sectionKey,
                label: 'Test',
                child: const SizedBox(),
              ),
            ),
          ),
        ),
      );

      // Find SizedBoxes that are direct descendants of the PropertySection Column.
      final sizedBoxes = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: find.byKey(sectionKey),
              matching: find.byType(SizedBox),
            ),
          )
          .toList();
      // First SizedBox inside PropertySection is the top spacer.
      expect(sizedBoxes.first.height, 24.0);
    });

    testWidgets('falls back to default spacing when no theme', (tester) async {
      final sectionKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertySection(
              key: sectionKey,
              label: 'Test',
              child: const SizedBox(),
            ),
          ),
        ),
      );

      // Find SizedBoxes inside PropertySection — first is the top spacer (default 12).
      final sizedBoxes = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: find.byKey(sectionKey),
              matching: find.byType(SizedBox),
            ),
          )
          .toList();
      expect(sizedBoxes.first.height, 12.0);
    });
  });

  // ---------------------------------------------------------------------------
  // DocumentPropertyPanel theme wiring
  // ---------------------------------------------------------------------------

  group('DocumentPropertyPanel theme wiring', () {
    testWidgets('effectiveWidth uses theme width over constructor width', (tester) async {
      final controller = DocumentEditingController(document: MutableDocument());
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyPanelTheme(
              data: const PropertyPanelThemeData(width: 350.0),
              child: DocumentPropertyPanel(
                controller: controller,
                requestHandler: (_) {},
              ),
            ),
          ),
        ),
      );

      final panel = tester.widget<DocumentPropertyPanel>(find.byType(DocumentPropertyPanel));
      // Theme width (350) overrides the widget's constructor width (280 default).
      expect(panel.effectiveWidth(const PropertyPanelThemeData(width: 350.0)), 350.0);
      // Without theme, falls back to the widget's constructor width.
      expect(panel.effectiveWidth(null), 280.0);
    });

    testWidgets('effectiveWidth falls back to constructor width when theme has no width',
        (tester) async {
      final controller = DocumentEditingController(document: MutableDocument());
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentPropertyPanel(
              controller: controller,
              requestHandler: (_) {},
              width: 300.0,
            ),
          ),
        ),
      );

      final panel = tester.widget<DocumentPropertyPanel>(find.byType(DocumentPropertyPanel));
      expect(panel.effectiveWidth(null), 300.0);
      expect(panel.effectiveWidth(const PropertyPanelThemeData()), 300.0);
    });
  });
}
