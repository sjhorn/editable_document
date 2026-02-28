import 'package:editable_document/src/model/attributed_text.dart';
import 'package:editable_document/src/model/attribution.dart';
import 'package:editable_document/src/model/document_node.dart';
import 'package:editable_document/src/model/text_node.dart';
import 'package:editable_document/src/model/paragraph_node.dart';
import 'package:editable_document/src/model/list_item_node.dart';
import 'package:editable_document/src/model/image_node.dart';
import 'package:editable_document/src/model/code_block_node.dart';
import 'package:editable_document/src/model/horizontal_rule_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // generateNodeId
  // ---------------------------------------------------------------------------
  group('generateNodeId', () {
    test('returns unique ids on consecutive calls', () {
      final id1 = generateNodeId();
      final id2 = generateNodeId();
      final id3 = generateNodeId();
      expect(id1, isNot(id2));
      expect(id2, isNot(id3));
      expect(id1, isNot(id3));
    });

    test('ids are non-empty strings', () {
      final id = generateNodeId();
      expect(id, isA<String>());
      expect(id.isNotEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // DocumentNode (via TextNode since DocumentNode is abstract)
  // ---------------------------------------------------------------------------
  group('DocumentNode', () {
    test('creation with explicit id', () {
      final node = TextNode(id: 'my-node-id');
      expect(node.id, 'my-node-id');
    });

    test('metadata defaults to empty map', () {
      final node = TextNode(id: 'n1');
      expect(node.metadata, isEmpty);
    });

    test('metadata is unmodifiable', () {
      final node = TextNode(id: 'n1');
      expect(() => node.metadata['key'] = 'value', throwsUnsupportedError);
    });

    test('metadata is unmodifiable when passed explicitly', () {
      final node = TextNode(id: 'n1', metadata: {'key': 'value'});
      expect(() => node.metadata['key2'] = 'other', throwsUnsupportedError);
    });

    test('copyWith replaces id', () {
      final node = TextNode(id: 'original');
      final copy = node.copyWith(id: 'replaced');
      expect(copy.id, 'replaced');
    });

    test('copyWith replaces metadata', () {
      final node = TextNode(id: 'n1');
      final copy = node.copyWith(metadata: {'block': 'paragraph'});
      expect(copy.metadata['block'], 'paragraph');
    });

    test('copyWith preserves id when not specified', () {
      final node = TextNode(id: 'keep-me', metadata: {'a': '1'});
      final copy = node.copyWith(metadata: {'b': '2'});
      expect(copy.id, 'keep-me');
    });

    test('equality: same fields are equal', () {
      final a = TextNode(id: 'n1');
      final b = TextNode(id: 'n1');
      expect(a, equals(b));
    });

    test('equality: different id not equal', () {
      final a = TextNode(id: 'n1');
      final b = TextNode(id: 'n2');
      expect(a, isNot(equals(b)));
    });

    test('hashCode matches for equal nodes', () {
      final a = TextNode(id: 'n1');
      final b = TextNode(id: 'n1');
      expect(a.hashCode, b.hashCode);
    });

    test('toString includes type and id', () {
      final node = TextNode(id: 'my-id');
      final str = node.toString();
      expect(str, contains('TextNode'));
      expect(str, contains('my-id'));
    });
  });

  // ---------------------------------------------------------------------------
  // TextNode
  // ---------------------------------------------------------------------------
  group('TextNode', () {
    test('creation with default empty text', () {
      final node = TextNode(id: 'n1');
      expect(node.text.text, '');
      expect(node.text.length, 0);
    });

    test('creation with explicit AttributedText', () {
      final text = AttributedText('hello world');
      final node = TextNode(id: 'n1', text: text);
      expect(node.text.text, 'hello world');
    });

    test('copyWith replaces text', () {
      final node = TextNode(id: 'n1', text: AttributedText('original'));
      final newText = AttributedText('replaced');
      final copy = node.copyWith(text: newText);
      expect(copy.text.text, 'replaced');
      expect(copy.id, 'n1');
    });

    test('copyWith preserves text when not specified', () {
      final text = AttributedText('keep me');
      final node = TextNode(id: 'n1', text: text);
      final copy = node.copyWith(id: 'n2');
      expect(copy.text.text, 'keep me');
    });

    test('equality includes text comparison', () {
      final a = TextNode(id: 'n1', text: AttributedText('hello'));
      final b = TextNode(id: 'n1', text: AttributedText('hello'));
      final c = TextNode(id: 'n1', text: AttributedText('world'));
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('TextNode with attributions round-trips correctly', () {
      final text = AttributedText('hello world').applyAttribution(NamedAttribution.bold, 0, 4);
      final node = TextNode(id: 'n1', text: text);
      expect(node.text.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      expect(node.text.hasAttributionAt(4, NamedAttribution.bold), isTrue);
      expect(node.text.hasAttributionAt(5, NamedAttribution.bold), isFalse);

      final copy = node.copyWith(id: 'n2');
      expect(copy.text.hasAttributionAt(2, NamedAttribution.bold), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // ParagraphNode
  // ---------------------------------------------------------------------------
  group('ParagraphNode', () {
    test('default blockType is paragraph', () {
      final node = ParagraphNode(id: 'p1');
      expect(node.blockType, ParagraphBlockType.paragraph);
    });

    test('creation with header1 blockType', () {
      final node = ParagraphNode(id: 'p1', blockType: ParagraphBlockType.header1);
      expect(node.blockType, ParagraphBlockType.header1);
    });

    test('copyWith replaces blockType', () {
      final node = ParagraphNode(id: 'p1', blockType: ParagraphBlockType.paragraph);
      final copy = node.copyWith(blockType: ParagraphBlockType.header2);
      expect(copy.blockType, ParagraphBlockType.header2);
      expect(copy.id, 'p1');
    });

    test('copyWith preserves blockType when not specified', () {
      final node = ParagraphNode(id: 'p1', blockType: ParagraphBlockType.header3);
      final copy = node.copyWith(id: 'p2');
      expect(copy.blockType, ParagraphBlockType.header3);
    });

    test('equality includes blockType', () {
      final a = ParagraphNode(id: 'p1', blockType: ParagraphBlockType.header1);
      final b = ParagraphNode(id: 'p1', blockType: ParagraphBlockType.header1);
      final c = ParagraphNode(id: 'p1', blockType: ParagraphBlockType.header2);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('all ParagraphBlockType values exist', () {
      expect(
        ParagraphBlockType.values,
        containsAll([
          ParagraphBlockType.paragraph,
          ParagraphBlockType.header1,
          ParagraphBlockType.header2,
          ParagraphBlockType.header3,
          ParagraphBlockType.header4,
          ParagraphBlockType.header5,
          ParagraphBlockType.header6,
          ParagraphBlockType.blockquote,
          ParagraphBlockType.codeBlock,
        ]),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ListItemNode
  // ---------------------------------------------------------------------------
  group('ListItemNode', () {
    test('default type is unordered', () {
      final node = ListItemNode(id: 'li1');
      expect(node.type, ListItemType.unordered);
    });

    test('default indent is 0', () {
      final node = ListItemNode(id: 'li1');
      expect(node.indent, 0);
    });

    test('creation with ordered type and indent', () {
      final node = ListItemNode(id: 'li1', type: ListItemType.ordered, indent: 2);
      expect(node.type, ListItemType.ordered);
      expect(node.indent, 2);
    });

    test('copyWith replaces type and indent', () {
      final node = ListItemNode(id: 'li1', type: ListItemType.unordered, indent: 0);
      final copy = node.copyWith(type: ListItemType.ordered, indent: 3);
      expect(copy.type, ListItemType.ordered);
      expect(copy.indent, 3);
      expect(copy.id, 'li1');
    });

    test('copyWith preserves type and indent when not specified', () {
      final node = ListItemNode(id: 'li1', type: ListItemType.ordered, indent: 2);
      final copy = node.copyWith(id: 'li2');
      expect(copy.type, ListItemType.ordered);
      expect(copy.indent, 2);
    });

    test('equality includes type and indent', () {
      final a = ListItemNode(id: 'li1', type: ListItemType.ordered, indent: 1);
      final b = ListItemNode(id: 'li1', type: ListItemType.ordered, indent: 1);
      final c = ListItemNode(id: 'li1', type: ListItemType.unordered, indent: 1);
      final d = ListItemNode(id: 'li1', type: ListItemType.ordered, indent: 2);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });
  });

  // ---------------------------------------------------------------------------
  // ImageNode
  // ---------------------------------------------------------------------------
  group('ImageNode', () {
    test('creation with required fields', () {
      final node = ImageNode(id: 'img1', imageUrl: 'https://example.com/img.png');
      expect(node.id, 'img1');
      expect(node.imageUrl, 'https://example.com/img.png');
    });

    test('optional fields default to null', () {
      final node = ImageNode(id: 'img1', imageUrl: 'https://example.com/img.png');
      expect(node.altText, isNull);
      expect(node.width, isNull);
      expect(node.height, isNull);
    });

    test('creation with all fields', () {
      final node = ImageNode(
        id: 'img1',
        imageUrl: 'https://example.com/img.png',
        altText: 'A photo',
        width: 800.0,
        height: 600.0,
      );
      expect(node.altText, 'A photo');
      expect(node.width, 800.0);
      expect(node.height, 600.0);
    });

    test('copyWith replaces all fields', () {
      final node = ImageNode(
        id: 'img1',
        imageUrl: 'https://example.com/old.png',
        altText: 'Old alt',
        width: 100.0,
        height: 50.0,
      );
      final copy = node.copyWith(
        id: 'img2',
        imageUrl: 'https://example.com/new.png',
        altText: 'New alt',
        width: 200.0,
        height: 150.0,
      );
      expect(copy.id, 'img2');
      expect(copy.imageUrl, 'https://example.com/new.png');
      expect(copy.altText, 'New alt');
      expect(copy.width, 200.0);
      expect(copy.height, 150.0);
    });

    test('copyWith preserves fields when not specified', () {
      final node = ImageNode(
        id: 'img1',
        imageUrl: 'https://example.com/img.png',
        altText: 'My alt',
        width: 300.0,
        height: 200.0,
      );
      final copy = node.copyWith(id: 'img2');
      expect(copy.imageUrl, 'https://example.com/img.png');
      expect(copy.altText, 'My alt');
      expect(copy.width, 300.0);
      expect(copy.height, 200.0);
    });

    test('equality includes all image fields', () {
      final a = ImageNode(
        id: 'img1',
        imageUrl: 'https://example.com/img.png',
        altText: 'Alt',
        width: 100.0,
        height: 50.0,
      );
      final b = ImageNode(
        id: 'img1',
        imageUrl: 'https://example.com/img.png',
        altText: 'Alt',
        width: 100.0,
        height: 50.0,
      );
      final c = ImageNode(
        id: 'img1',
        imageUrl: 'https://example.com/other.png',
        altText: 'Alt',
        width: 100.0,
        height: 50.0,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode
  // ---------------------------------------------------------------------------
  group('CodeBlockNode', () {
    test('creation with no language', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node.id, 'cb1');
      expect(node.language, isNull);
    });

    test('creation with language', () {
      final node = CodeBlockNode(id: 'cb1', language: 'dart');
      expect(node.language, 'dart');
    });

    test('copyWith replaces language', () {
      final node = CodeBlockNode(id: 'cb1', language: 'dart');
      final copy = node.copyWith(language: 'python');
      expect(copy.language, 'python');
      expect(copy.id, 'cb1');
    });

    test('copyWith preserves language when not specified', () {
      final node = CodeBlockNode(id: 'cb1', language: 'kotlin');
      final copy = node.copyWith(id: 'cb2');
      expect(copy.language, 'kotlin');
    });

    test('equality includes language', () {
      final a = CodeBlockNode(id: 'cb1', language: 'dart');
      final b = CodeBlockNode(id: 'cb1', language: 'dart');
      final c = CodeBlockNode(id: 'cb1', language: 'python');
      final d = CodeBlockNode(id: 'cb1');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });
  });

  // ---------------------------------------------------------------------------
  // HorizontalRuleNode
  // ---------------------------------------------------------------------------
  group('HorizontalRuleNode', () {
    test('creation with id', () {
      final node = HorizontalRuleNode(id: 'hr1');
      expect(node.id, 'hr1');
    });

    test('metadata defaults to empty', () {
      final node = HorizontalRuleNode(id: 'hr1');
      expect(node.metadata, isEmpty);
    });

    test('copyWith replaces id', () {
      final node = HorizontalRuleNode(id: 'hr1');
      final copy = node.copyWith(id: 'hr2');
      expect(copy.id, 'hr2');
    });

    test('copyWith replaces metadata', () {
      final node = HorizontalRuleNode(id: 'hr1');
      final copy = node.copyWith(metadata: {'style': 'thick'});
      expect(copy.metadata['style'], 'thick');
    });

    test('equality: same id and metadata are equal', () {
      final a = HorizontalRuleNode(id: 'hr1');
      final b = HorizontalRuleNode(id: 'hr1');
      expect(a, equals(b));
    });

    test('equality: different id not equal', () {
      final a = HorizontalRuleNode(id: 'hr1');
      final b = HorizontalRuleNode(id: 'hr2');
      expect(a, isNot(equals(b)));
    });
  });
}
