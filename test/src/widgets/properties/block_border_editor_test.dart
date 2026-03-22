/// Tests for [BlockBorderEditor].
library;

import 'package:editable_document/src/model/block_border.dart';
import 'package:editable_document/src/widgets/properties/block_border_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('BlockBorderEditor', () {
    testWidgets('renders a style dropdown', (tester) async {
      await tester.pumpWidget(
        _wrap(BlockBorderEditor(border: null, onChanged: (_) {})),
      );
      expect(find.byType(DropdownButton<BlockBorderStyle?>), findsOneWidget);
    });

    testWidgets('shows None when border is null', (tester) async {
      await tester.pumpWidget(
        _wrap(BlockBorderEditor(border: null, onChanged: (_) {})),
      );
      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('hides width and color when border is null', (tester) async {
      await tester.pumpWidget(
        _wrap(BlockBorderEditor(border: null, onChanged: (_) {})),
      );
      expect(find.text('Width'), findsNothing);
      expect(find.text('Color'), findsNothing);
    });

    testWidgets('shows width and color fields when border is set', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BlockBorderEditor(
            border: const BlockBorder(style: BlockBorderStyle.solid, width: 2.0),
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Width'), findsOneWidget);
      expect(find.text('Color'), findsOneWidget);
    });

    testWidgets('calls onChanged(null) when None is selected', (tester) async {
      BlockBorder? result = const BlockBorder();
      await tester.pumpWidget(
        _wrap(
          BlockBorderEditor(
            border: const BlockBorder(style: BlockBorderStyle.solid),
            onChanged: (v) => result = v,
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButton<BlockBorderStyle?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('None').last);
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('calls onChanged with new BlockBorder when style selected', (tester) async {
      BlockBorder? result;
      await tester.pumpWidget(
        _wrap(
          BlockBorderEditor(
            border: null,
            onChanged: (v) => result = v,
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButton<BlockBorderStyle?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solid').last);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.style, BlockBorderStyle.solid);
    });
  });
}
