/// Tests for [UrlField].
library;

import 'package:editable_document/src/widgets/toolbar/url_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] using [InkRipple] to avoid the ink_sparkle shader error.
Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('UrlField', () {
    testWidgets('shows https placeholder hint', (tester) async {
      await tester.pumpWidget(
        _wrap(UrlField(value: '', onChanged: (_) {})),
      );

      expect(find.text('https://...'), findsOneWidget);
    });

    testWidgets('shows existing value', (tester) async {
      await tester.pumpWidget(
        _wrap(UrlField(value: 'https://example.com', onChanged: (_) {})),
      );

      expect(find.text('https://example.com'), findsOneWidget);
    });

    testWidgets('calls onChanged on submit with non-empty trimmed value', (tester) async {
      String? result;

      await tester.pumpWidget(
        _wrap(UrlField(value: '', onChanged: (v) => result = v)),
      );

      await tester.enterText(find.byType(TextField), 'https://flutter.dev');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(result, 'https://flutter.dev');
    });

    testWidgets('does not call onChanged for empty submit', (tester) async {
      String? result;

      await tester.pumpWidget(
        _wrap(UrlField(value: '', onChanged: (v) => result = v)),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(result, isNull);
    });
  });
}
