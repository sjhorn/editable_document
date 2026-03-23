/// Coverage tests for [debugFillProperties] on document editing intents.
///
/// The companion file `document_editing_intents_test.dart` covers construction
/// and field storage.  This file exercises the [debugFillProperties] overrides,
/// which account for most of the uncovered lines in the source.
///
/// The properties are read via [Diagnosticable.toDiagnosticsNode] which is the
/// public API that internally calls [debugFillProperties].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Returns all diagnostic properties for [value] using the public
/// [Diagnosticable.toDiagnosticsNode] API (which internally calls
/// [debugFillProperties]).
List<DiagnosticsNode> _propertiesOf(Diagnosticable value) {
  return value.toDiagnosticsNode().getProperties();
}

/// Returns the [DiagnosticsNode] whose name matches [name], or throws.
DiagnosticsNode _property(List<DiagnosticsNode> props, String name) {
  return props.firstWhere(
    (p) => p.name == name,
    orElse: () => throw StateError('Property "$name" not found'),
  );
}

void main() {
  // -------------------------------------------------------------------------
  // ToggleAttributionIntent.debugFillProperties
  // -------------------------------------------------------------------------

  group('ToggleAttributionIntent.debugFillProperties', () {
    test('includes attribution property', () {
      const intent = ToggleAttributionIntent(NamedAttribution.bold);
      final props = _propertiesOf(intent);
      final prop = _property(props, 'attribution');

      expect(prop.value, equals(NamedAttribution.bold));
    });
  });

  // -------------------------------------------------------------------------
  // ConvertToParagraphIntent.debugFillProperties
  // -------------------------------------------------------------------------

  group('ConvertToParagraphIntent.debugFillProperties', () {
    test('blockType is null by default', () {
      const intent = ConvertToParagraphIntent();
      final props = _propertiesOf(intent);
      final prop = _property(props, 'blockType');

      expect(prop.value, isNull);
    });

    test('blockType is included when set', () {
      const intent = ConvertToParagraphIntent(blockType: ParagraphBlockType.header1);
      final props = _propertiesOf(intent);
      final prop = _property(props, 'blockType');

      expect(prop.value, equals(ParagraphBlockType.header1));
    });
  });

  // -------------------------------------------------------------------------
  // ConvertToListItemIntent.debugFillProperties
  // -------------------------------------------------------------------------

  group('ConvertToListItemIntent.debugFillProperties', () {
    test('listType unordered is included', () {
      const intent = ConvertToListItemIntent(ListItemType.unordered);
      final props = _propertiesOf(intent);
      final prop = _property(props, 'listType');

      expect(prop.value, equals(ListItemType.unordered));
    });

    test('listType ordered is included', () {
      const intent = ConvertToListItemIntent(ListItemType.ordered);
      final props = _propertiesOf(intent);
      final prop = _property(props, 'listType');

      expect(prop.value, equals(ListItemType.ordered));
    });
  });

  // -------------------------------------------------------------------------
  // ChangeTextAlignIntent.debugFillProperties
  // -------------------------------------------------------------------------

  group('ChangeTextAlignIntent.debugFillProperties', () {
    test('textAlign is included', () {
      const intent = ChangeTextAlignIntent(TextAlign.center);
      final props = _propertiesOf(intent);
      final prop = _property(props, 'textAlign');

      expect(prop.value, equals(TextAlign.center));
    });
  });

  // -------------------------------------------------------------------------
  // InsertImageIntent.debugFillProperties
  // -------------------------------------------------------------------------

  group('InsertImageIntent.debugFillProperties', () {
    test('imageUrl and no altText are included', () {
      const intent = InsertImageIntent(imageUrl: 'https://example.com/img.png');
      final props = _propertiesOf(intent);

      expect(_property(props, 'imageUrl').value, equals('https://example.com/img.png'));
      expect(_property(props, 'altText').value, isNull);
    });

    test('altText is included when set', () {
      const intent = InsertImageIntent(imageUrl: 'x.png', altText: 'desc');
      final props = _propertiesOf(intent);

      expect(_property(props, 'altText').value, equals('desc'));
    });
  });

  // -------------------------------------------------------------------------
  // InsertTableIntent.debugFillProperties
  // -------------------------------------------------------------------------

  group('InsertTableIntent.debugFillProperties', () {
    test('rows and columns are included', () {
      const intent = InsertTableIntent(rows: 2, columns: 5);
      final props = _propertiesOf(intent);

      expect(_property(props, 'rows').value, equals(2));
      expect(_property(props, 'columns').value, equals(5));
    });
  });

  // -------------------------------------------------------------------------
  // MoveToNodeBoundaryIntent.debugFillProperties
  // -------------------------------------------------------------------------

  group('MoveToNodeBoundaryIntent.debugFillProperties', () {
    test('forward flag is included', () {
      const intent = MoveToNodeBoundaryIntent(forward: true);
      final props = _propertiesOf(intent);

      expect(_property(props, 'forward'), isNotNull);
    });

    test('extend flag is included', () {
      const intent = MoveToNodeBoundaryIntent(forward: false, extend: true);
      final props = _propertiesOf(intent);

      expect(_property(props, 'extend'), isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // MoveToAdjacentTableCellIntent.debugFillProperties
  // -------------------------------------------------------------------------

  group('MoveToAdjacentTableCellIntent.debugFillProperties', () {
    test('forward flag is included for next cell', () {
      const intent = MoveToAdjacentTableCellIntent(forward: true);
      final props = _propertiesOf(intent);

      expect(_property(props, 'forward'), isNotNull);
    });

    test('forward flag is included for previous cell', () {
      const intent = MoveToAdjacentTableCellIntent(forward: false);
      final props = _propertiesOf(intent);

      expect(_property(props, 'forward'), isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // InsertTableRowIntent.debugFillProperties
  // -------------------------------------------------------------------------

  group('InsertTableRowIntent.debugFillProperties', () {
    test('below flag is included when true', () {
      const intent = InsertTableRowIntent(below: true);
      final props = _propertiesOf(intent);

      expect(_property(props, 'below'), isNotNull);
    });

    test('below flag is included when false', () {
      const intent = InsertTableRowIntent(below: false);
      final props = _propertiesOf(intent);

      expect(_property(props, 'below'), isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // InsertTableColumnIntent.debugFillProperties
  // -------------------------------------------------------------------------

  group('InsertTableColumnIntent.debugFillProperties', () {
    test('after flag is included when true', () {
      const intent = InsertTableColumnIntent(after: true);
      final props = _propertiesOf(intent);

      expect(_property(props, 'after'), isNotNull);
    });

    test('after flag is included when false', () {
      const intent = InsertTableColumnIntent(after: false);
      final props = _propertiesOf(intent);

      expect(_property(props, 'after'), isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Enter / Tab intents -- no debugFillProperties, just const-constructible
  // -------------------------------------------------------------------------

  group('DocumentTabIntent', () {
    test('is const-constructible', () {
      const intent = DocumentTabIntent();
      expect(intent, isA<Intent>());
    });
  });

  group('DocumentShiftTabIntent', () {
    test('is const-constructible', () {
      const intent = DocumentShiftTabIntent();
      expect(intent, isA<Intent>());
    });
  });

  group('DocumentEnterIntent', () {
    test('is const-constructible', () {
      const intent = DocumentEnterIntent();
      expect(intent, isA<Intent>());
    });
  });

  group('DocumentShiftEnterIntent', () {
    test('is const-constructible', () {
      const intent = DocumentShiftEnterIntent();
      expect(intent, isA<Intent>());
    });
  });
}
