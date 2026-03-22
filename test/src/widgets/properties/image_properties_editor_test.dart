/// Tests for [ImagePropertiesEditor].
library;

import 'package:editable_document/src/widgets/properties/image_properties_editor.dart';
import 'package:editable_document/src/widgets/toolbar/url_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );

void main() {
  group('ImagePropertiesEditor', () {
    testWidgets('renders a UrlField', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ImagePropertiesEditor(
            imageUrl: 'https://example.com/img.png',
            lockAspect: false,
            onUrlChanged: (_) {},
            onLockAspectChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(UrlField), findsOneWidget);
    });

    testWidgets('renders a Lock Aspect checkbox', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ImagePropertiesEditor(
            imageUrl: '',
            lockAspect: false,
            onUrlChanged: (_) {},
            onLockAspectChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('fires onLockAspectChanged when checkbox toggled', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          ImagePropertiesEditor(
            imageUrl: '',
            lockAspect: false,
            onUrlChanged: (_) {},
            onLockAspectChanged: (v) => result = v,
          ),
        ),
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(result, isTrue);
    });

    testWidgets('shows Choose File button when onPickFile is provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ImagePropertiesEditor(
            imageUrl: '',
            lockAspect: false,
            onUrlChanged: (_) {},
            onLockAspectChanged: (_) {},
            onPickFile: () {},
          ),
        ),
      );
      expect(find.text('Choose File'), findsOneWidget);
    });

    testWidgets('hides Choose File button when onPickFile is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ImagePropertiesEditor(
            imageUrl: '',
            lockAspect: false,
            onUrlChanged: (_) {},
            onLockAspectChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Choose File'), findsNothing);
    });

    testWidgets('fires onPickFile when button tapped', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        _wrap(
          ImagePropertiesEditor(
            imageUrl: '',
            lockAspect: false,
            onUrlChanged: (_) {},
            onLockAspectChanged: (_) {},
            onPickFile: () => called = true,
          ),
        ),
      );

      await tester.tap(find.text('Choose File'));
      await tester.pump();

      expect(called, isTrue);
    });
  });
}
