/// Tests for document-specific [Intent] classes.
///
/// These are pure data-class tests — they verify construction and field storage
/// only. No widget pump is needed.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

void main() {
  // -------------------------------------------------------------------------
  // Formatting intents
  // -------------------------------------------------------------------------

  group('ToggleAttributionIntent', () {
    test('is const-constructible and stores attribution', () {
      const attribution = NamedAttribution.bold;
      const intent = ToggleAttributionIntent(attribution);

      expect(intent.attribution, same(attribution));
    });

    test('stores a custom attribution', () {
      const attribution = NamedAttribution('highlight');
      const intent = ToggleAttributionIntent(attribution);

      expect(intent.attribution.id, equals('highlight'));
    });
  });

  group('ClearFormattingIntent', () {
    test('is const-constructible', () {
      const intent = ClearFormattingIntent();

      expect(intent, isA<Intent>());
    });
  });

  // -------------------------------------------------------------------------
  // Block type intents
  // -------------------------------------------------------------------------

  group('ConvertToParagraphIntent', () {
    test('is const-constructible with no block type', () {
      const intent = ConvertToParagraphIntent();

      expect(intent.blockType, isNull);
    });

    test('stores optional block type', () {
      const intent = ConvertToParagraphIntent(blockType: ParagraphBlockType.header1);

      expect(intent.blockType, equals(ParagraphBlockType.header1));
    });
  });

  group('ConvertToBlockquoteIntent', () {
    test('is const-constructible', () {
      const intent = ConvertToBlockquoteIntent();

      expect(intent, isA<Intent>());
    });
  });

  group('ConvertToCodeBlockIntent', () {
    test('is const-constructible', () {
      const intent = ConvertToCodeBlockIntent();

      expect(intent, isA<Intent>());
    });
  });

  group('ConvertToListItemIntent', () {
    test('stores unordered list type', () {
      const intent = ConvertToListItemIntent(ListItemType.unordered);

      expect(intent.listType, equals(ListItemType.unordered));
    });

    test('stores ordered list type', () {
      const intent = ConvertToListItemIntent(ListItemType.ordered);

      expect(intent.listType, equals(ListItemType.ordered));
    });
  });

  // -------------------------------------------------------------------------
  // Text alignment intent
  // -------------------------------------------------------------------------

  group('ChangeTextAlignIntent', () {
    test('stores TextAlign.left', () {
      const intent = ChangeTextAlignIntent(TextAlign.left);

      expect(intent.textAlign, equals(TextAlign.left));
    });

    test('stores TextAlign.center', () {
      const intent = ChangeTextAlignIntent(TextAlign.center);

      expect(intent.textAlign, equals(TextAlign.center));
    });

    test('stores TextAlign.right', () {
      const intent = ChangeTextAlignIntent(TextAlign.right);

      expect(intent.textAlign, equals(TextAlign.right));
    });

    test('stores TextAlign.justify', () {
      const intent = ChangeTextAlignIntent(TextAlign.justify);

      expect(intent.textAlign, equals(TextAlign.justify));
    });
  });

  // -------------------------------------------------------------------------
  // List indentation intents
  // -------------------------------------------------------------------------

  group('IndentListItemIntent', () {
    test('is const-constructible', () {
      const intent = IndentListItemIntent();

      expect(intent, isA<Intent>());
    });
  });

  group('UnindentListItemIntent', () {
    test('is const-constructible', () {
      const intent = UnindentListItemIntent();

      expect(intent, isA<Intent>());
    });
  });

  // -------------------------------------------------------------------------
  // Block insertion intents
  // -------------------------------------------------------------------------

  group('InsertHorizontalRuleIntent', () {
    test('is const-constructible', () {
      const intent = InsertHorizontalRuleIntent();

      expect(intent, isA<Intent>());
    });
  });

  group('InsertImageIntent', () {
    test('stores imageUrl and no altText by default', () {
      const intent = InsertImageIntent(imageUrl: 'https://example.com/photo.png');

      expect(intent.imageUrl, equals('https://example.com/photo.png'));
      expect(intent.altText, isNull);
    });

    test('stores altText when provided', () {
      const intent = InsertImageIntent(
        imageUrl: 'https://example.com/photo.png',
        altText: 'A photo',
      );

      expect(intent.altText, equals('A photo'));
    });
  });

  group('InsertTableIntent', () {
    test('stores rows and columns', () {
      const intent = InsertTableIntent(rows: 3, columns: 4);

      expect(intent.rows, equals(3));
      expect(intent.columns, equals(4));
    });
  });

  // -------------------------------------------------------------------------
  // Document-specific navigation intents
  // -------------------------------------------------------------------------

  group('MoveToNodeBoundaryIntent', () {
    test('stores forward=true and extend defaults to false', () {
      const intent = MoveToNodeBoundaryIntent(forward: true);

      expect(intent.forward, isTrue);
      expect(intent.extend, isFalse);
    });

    test('stores forward=false', () {
      const intent = MoveToNodeBoundaryIntent(forward: false);

      expect(intent.forward, isFalse);
    });

    test('stores extend=true', () {
      const intent = MoveToNodeBoundaryIntent(forward: true, extend: true);

      expect(intent.extend, isTrue);
    });
  });

  group('MoveToAdjacentTableCellIntent', () {
    test('stores forward=true', () {
      const intent = MoveToAdjacentTableCellIntent(forward: true);

      expect(intent.forward, isTrue);
    });

    test('stores forward=false', () {
      const intent = MoveToAdjacentTableCellIntent(forward: false);

      expect(intent.forward, isFalse);
    });
  });

  group('CollapseSelectionIntent', () {
    test('is const-constructible', () {
      const intent = CollapseSelectionIntent();

      expect(intent, isA<Intent>());
    });
  });

  // -------------------------------------------------------------------------
  // Table editing intents
  // -------------------------------------------------------------------------

  group('InsertTableRowIntent', () {
    test('stores below=true', () {
      const intent = InsertTableRowIntent(below: true);

      expect(intent.below, isTrue);
    });

    test('stores below=false', () {
      const intent = InsertTableRowIntent(below: false);

      expect(intent.below, isFalse);
    });
  });

  group('InsertTableColumnIntent', () {
    test('stores after=true', () {
      const intent = InsertTableColumnIntent(after: true);

      expect(intent.after, isTrue);
    });

    test('stores after=false', () {
      const intent = InsertTableColumnIntent(after: false);

      expect(intent.after, isFalse);
    });
  });

  group('DeleteTableRowIntent', () {
    test('is const-constructible', () {
      const intent = DeleteTableRowIntent();

      expect(intent, isA<Intent>());
    });
  });

  group('DeleteTableColumnIntent', () {
    test('is const-constructible', () {
      const intent = DeleteTableColumnIntent();

      expect(intent, isA<Intent>());
    });
  });

  group('DeleteTableIntent', () {
    test('is const-constructible', () {
      const intent = DeleteTableIntent();

      expect(intent, isA<Intent>());
    });
  });
}
