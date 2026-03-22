/// Tests for [DocumentJsonSerializer].
library;

import 'dart:convert';
import 'dart:ui' show TextAlign;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const serializer = DocumentJsonSerializer();

  // ---------------------------------------------------------------------------
  // BlockDimension round-trips
  // ---------------------------------------------------------------------------

  group('BlockDimension serialization', () {
    test('null dimension serializes to null', () {
      expect(serializer.blockDimensionToJson(null), isNull);
    });

    test('PixelDimension round-trips', () {
      const dim = PixelDimension(400.0);
      final json = serializer.blockDimensionToJson(dim);
      expect(json, {'type': 'pixels', 'value': 400.0});
      expect(serializer.parseBlockDimension(json), dim);
    });

    test('PercentDimension round-trips', () {
      const dim = PercentDimension(0.5);
      final json = serializer.blockDimensionToJson(dim);
      expect(json, {'type': 'percent', 'value': 0.5});
      expect(serializer.parseBlockDimension(json), dim);
    });

    test('parseBlockDimension returns null when raw is null', () {
      expect(serializer.parseBlockDimension(null), isNull);
    });

    test('parseBlockDimension defaults to PixelDimension for unknown type', () {
      final result = serializer.parseBlockDimension({'type': 'unknown', 'value': 100.0});
      expect(result, const PixelDimension(100.0));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockBorder round-trips
  // ---------------------------------------------------------------------------

  group('BlockBorder serialization', () {
    test('null border produces no border keys', () {
      final map = <String, Object?>{};
      serializer.addBorderFields(map, null);
      expect(map.containsKey('borderStyle'), isFalse);
    });

    test('solid border with color round-trips', () {
      const border = BlockBorder(
        style: BlockBorderStyle.solid,
        width: 2.0,
        color: Color(0xFFFF0000),
      );
      final map = <String, Object?>{};
      serializer.addBorderFields(map, border);
      expect(map['borderStyle'], 'solid');
      expect(map['borderWidth'], 2.0);
      expect(map['borderColor'], 0xFFFF0000);

      final parsed = serializer.parseBorder(map);
      expect(parsed, border);
    });

    test('dashed border without color round-trips', () {
      const border = BlockBorder(style: BlockBorderStyle.dashed, width: 1.5);
      final map = <String, Object?>{};
      serializer.addBorderFields(map, border);
      expect(map['borderStyle'], 'dashed');
      expect(map['borderWidth'], 1.5);
      expect(map.containsKey('borderColor'), isFalse);

      final parsed = serializer.parseBorder(map);
      expect(parsed?.style, BlockBorderStyle.dashed);
      expect(parsed?.width, 1.5);
      expect(parsed?.color, isNull);
    });

    test('parseBorder returns null when borderStyle key is absent', () {
      expect(serializer.parseBorder({}), isNull);
    });

    test('parseBorder defaults to solid for unknown style', () {
      final parsed = serializer.parseBorder({
        'borderStyle': 'nonexistent',
        'borderWidth': 1.0,
      });
      expect(parsed?.style, BlockBorderStyle.solid);
    });
  });

  // ---------------------------------------------------------------------------
  // Attribution span round-trips
  // ---------------------------------------------------------------------------

  group('AttributedText serialization', () {
    test('plain text with no attributions omits attributions key', () {
      final text = AttributedText('Hello');
      final map = <String, Object?>{'text': text.text};
      serializer.addAttributionSpans(map, text);
      expect(map.containsKey('attributions'), isFalse);
    });

    test('bold attribution round-trips', () {
      final text = AttributedText('Hello').applyAttribution(NamedAttribution.bold, 0, 4);
      final map = <String, Object?>{'text': text.text};
      serializer.addAttributionSpans(map, text);

      final spans = map['attributions'] as List<Object?>;
      expect(spans, hasLength(1));
      final span = spans[0] as Map<String, Object?>;
      expect(span['attribution'], 'bold');
      expect(span['start'], 0);
      expect(span['end'], 4);
    });

    test('FontFamilyAttribution round-trips via textFromJson', () {
      final original =
          AttributedText('Styled').applyAttribution(const FontFamilyAttribution('Roboto'), 0, 5);
      final map = <String, Object?>{'text': original.text};
      serializer.addAttributionSpans(map, original);

      final restored = serializer.textFromJson(map);
      expect(restored.text, 'Styled');
      final spans = restored.getAttributionSpansInRange(0, restored.text.length).toList();
      expect(spans, hasLength(1));
      expect(spans[0].attribution, const FontFamilyAttribution('Roboto'));
    });

    test('FontSizeAttribution round-trips via textFromJson', () {
      final original =
          AttributedText('Big').applyAttribution(const FontSizeAttribution(24.0), 0, 2);
      final map = <String, Object?>{'text': original.text};
      serializer.addAttributionSpans(map, original);

      final restored = serializer.textFromJson(map);
      final spans = restored.getAttributionSpansInRange(0, restored.text.length).toList();
      expect(spans[0].attribution, const FontSizeAttribution(24.0));
    });

    test('TextColorAttribution round-trips via textFromJson', () {
      final original =
          AttributedText('Red').applyAttribution(const TextColorAttribution(0xFFFF0000), 0, 2);
      final map = <String, Object?>{'text': original.text};
      serializer.addAttributionSpans(map, original);

      final restored = serializer.textFromJson(map);
      final spans = restored.getAttributionSpansInRange(0, restored.text.length).toList();
      expect(spans[0].attribution, const TextColorAttribution(0xFFFF0000));
    });

    test('BackgroundColorAttribution round-trips via textFromJson', () {
      final original = AttributedText('Highlight')
          .applyAttribution(const BackgroundColorAttribution(0xFFFFFF00), 0, 8);
      final map = <String, Object?>{'text': original.text};
      serializer.addAttributionSpans(map, original);

      final restored = serializer.textFromJson(map);
      final spans = restored.getAttributionSpansInRange(0, restored.text.length).toList();
      expect(spans[0].attribution, const BackgroundColorAttribution(0xFFFFFF00));
    });
  });

  // ---------------------------------------------------------------------------
  // toJson / fromJson full document round-trips
  // ---------------------------------------------------------------------------

  group('DocumentJsonSerializer.toJson / fromJson', () {
    test('empty document round-trips', () {
      final doc = Document([]);
      final json = serializer.toJson(doc);
      expect(json['nodes'], isEmpty);
      final nodes = serializer.fromJson(json);
      expect(nodes, isEmpty);
    });

    test('single plain paragraph round-trips', () {
      const id = 'p1';
      final doc = Document([
        ParagraphNode(id: id, text: AttributedText('Hello world')),
      ]);
      final json = serializer.toJson(doc);
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final nodes = serializer.fromJson(decoded);

      expect(nodes, hasLength(1));
      final para = nodes[0] as ParagraphNode;
      expect(para.id, id);
      expect(para.text.text, 'Hello world');
      expect(para.blockType, ParagraphBlockType.paragraph);
      expect(para.textAlign, TextAlign.start);
    });

    test('paragraph with heading block type round-trips', () {
      const id = 'h1';
      final doc = Document([
        ParagraphNode(
          id: id,
          text: AttributedText('My Heading'),
          blockType: ParagraphBlockType.header1,
          textAlign: TextAlign.center,
        ),
      ]);
      final json = serializer.toJson(doc);
      final nodes = serializer.fromJson(json);
      final para = nodes[0] as ParagraphNode;
      expect(para.blockType, ParagraphBlockType.header1);
      expect(para.textAlign, TextAlign.center);
    });

    test('paragraph with attributions round-trips', () {
      final text = AttributedText('Bold and italic')
          .applyAttribution(NamedAttribution.bold, 0, 3)
          .applyAttribution(NamedAttribution.italics, 9, 14);
      final doc = Document([
        ParagraphNode(id: 'p-attr', text: text),
      ]);
      final json = serializer.toJson(doc);
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final nodes = serializer.fromJson(decoded);

      final para = nodes[0] as ParagraphNode;
      final spans = para.text.getAttributionSpansInRange(0, para.text.text.length).toList();
      expect(spans, hasLength(2));
      expect(spans.any((s) => s.attribution == NamedAttribution.bold), isTrue);
      expect(spans.any((s) => s.attribution == NamedAttribution.italics), isTrue);
    });

    test('paragraph with spacing / indent fields round-trips', () {
      final doc = Document([
        ParagraphNode(
          id: 'p-spacing',
          text: AttributedText('Indented'),
          lineHeight: 1.5,
          spaceBefore: 8.0,
          spaceAfter: 16.0,
          indentLeft: 24.0,
          indentRight: 12.0,
          firstLineIndent: 20.0,
        ),
      ]);
      final json = serializer.toJson(doc);
      final nodes = serializer.fromJson(json);
      final para = nodes[0] as ParagraphNode;
      expect(para.lineHeight, 1.5);
      expect(para.spaceBefore, 8.0);
      expect(para.spaceAfter, 16.0);
      expect(para.indentLeft, 24.0);
      expect(para.indentRight, 12.0);
      expect(para.firstLineIndent, 20.0);
    });

    test('paragraph with border round-trips', () {
      final doc = Document([
        ParagraphNode(
          id: 'p-border',
          text: AttributedText('Bordered'),
          border: const BlockBorder(
            style: BlockBorderStyle.dotted,
            width: 3.0,
            color: Color(0xFF0000FF),
          ),
        ),
      ]);
      final json = serializer.toJson(doc);
      final nodes = serializer.fromJson(json);
      final para = nodes[0] as ParagraphNode;
      expect(para.border?.style, BlockBorderStyle.dotted);
      expect(para.border?.width, 3.0);
      expect(para.border?.color, const Color(0xFF0000FF));
    });

    test('ordered list item round-trips', () {
      final doc = Document([
        ListItemNode(
          id: 'li-1',
          text: AttributedText('Item one'),
          type: ListItemType.ordered,
          indent: 1,
          lineHeight: 1.2,
          spaceBefore: 4.0,
          spaceAfter: 4.0,
          indentLeft: 16.0,
          indentRight: 8.0,
        ),
      ]);
      final json = serializer.toJson(doc);
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final nodes = serializer.fromJson(decoded);

      final item = nodes[0] as ListItemNode;
      expect(item.id, 'li-1');
      expect(item.text.text, 'Item one');
      expect(item.type, ListItemType.ordered);
      expect(item.indent, 1);
      expect(item.lineHeight, 1.2);
      expect(item.spaceBefore, 4.0);
      expect(item.spaceAfter, 4.0);
      expect(item.indentLeft, 16.0);
      expect(item.indentRight, 8.0);
    });

    test('unordered list item with zero indent omits indent key', () {
      final doc = Document([
        ListItemNode(
          id: 'li-2',
          text: AttributedText('Bullet'),
          type: ListItemType.unordered,
        ),
      ]);
      final json = serializer.toJson(doc);
      final nodeMap = (json['nodes'] as List<Object?>)[0] as Map<String, Object?>;
      // indent: 0 should not be stored (optional compactness)
      expect(nodeMap.containsKey('indent'), isFalse);

      final nodes = serializer.fromJson(json);
      final item = nodes[0] as ListItemNode;
      expect(item.type, ListItemType.unordered);
      expect(item.indent, 0);
    });

    test('image node with all fields round-trips', () {
      final doc = Document([
        ImageNode(
          id: 'img-1',
          imageUrl: 'https://example.com/photo.jpg',
          altText: 'A photo',
          width: const PixelDimension(800.0),
          height: const PercentDimension(0.5),
          alignment: BlockAlignment.center,
          textWrap: TextWrapMode.wrap,
          lockAspect: false,
          spaceBefore: 10.0,
          spaceAfter: 10.0,
          border: const BlockBorder(style: BlockBorderStyle.solid, width: 1.0),
        ),
      ]);
      final json = serializer.toJson(doc);
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final nodes = serializer.fromJson(decoded);

      final img = nodes[0] as ImageNode;
      expect(img.id, 'img-1');
      expect(img.imageUrl, 'https://example.com/photo.jpg');
      expect(img.altText, 'A photo');
      expect(img.width, const PixelDimension(800.0));
      expect(img.height, const PercentDimension(0.5));
      expect(img.alignment, BlockAlignment.center);
      expect(img.textWrap, TextWrapMode.wrap);
      expect(img.lockAspect, false);
      expect(img.spaceBefore, 10.0);
      expect(img.spaceAfter, 10.0);
      expect(img.border?.style, BlockBorderStyle.solid);
    });

    test('code block with language round-trips', () {
      final doc = Document([
        CodeBlockNode(
          id: 'code-1',
          text: AttributedText('void main() {}'),
          language: 'dart',
          lineHeight: 1.4,
          spaceBefore: 12.0,
          spaceAfter: 12.0,
          width: const PixelDimension(640.0),
          height: const PixelDimension(200.0),
          alignment: BlockAlignment.center,
          textWrap: TextWrapMode.none,
          border: const BlockBorder(style: BlockBorderStyle.dashed),
        ),
      ]);
      final json = serializer.toJson(doc);
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final nodes = serializer.fromJson(decoded);

      final code = nodes[0] as CodeBlockNode;
      expect(code.id, 'code-1');
      expect(code.text.text, 'void main() {}');
      expect(code.language, 'dart');
      expect(code.lineHeight, 1.4);
      expect(code.spaceBefore, 12.0);
      expect(code.spaceAfter, 12.0);
      expect(code.width, const PixelDimension(640.0));
      expect(code.height, const PixelDimension(200.0));
      expect(code.alignment, BlockAlignment.center);
      expect(code.border?.style, BlockBorderStyle.dashed);
    });

    test('blockquote with indent fields round-trips', () {
      final doc = Document([
        BlockquoteNode(
          id: 'bq-1',
          text: AttributedText('To be or not to be'),
          textAlign: TextAlign.center,
          lineHeight: 1.6,
          spaceBefore: 8.0,
          spaceAfter: 8.0,
          indentLeft: 32.0,
          indentRight: 32.0,
          firstLineIndent: 16.0,
          width: const PixelDimension(500.0),
          height: const PixelDimension(100.0),
          alignment: BlockAlignment.center,
          textWrap: TextWrapMode.wrap,
          border: const BlockBorder(style: BlockBorderStyle.solid, width: 2.0),
        ),
      ]);
      final json = serializer.toJson(doc);
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final nodes = serializer.fromJson(decoded);

      final bq = nodes[0] as BlockquoteNode;
      expect(bq.id, 'bq-1');
      expect(bq.text.text, 'To be or not to be');
      expect(bq.textAlign, TextAlign.center);
      expect(bq.lineHeight, 1.6);
      expect(bq.spaceBefore, 8.0);
      expect(bq.spaceAfter, 8.0);
      expect(bq.indentLeft, 32.0);
      expect(bq.indentRight, 32.0);
      expect(bq.firstLineIndent, 16.0);
      expect(bq.width, const PixelDimension(500.0));
      expect(bq.height, const PixelDimension(100.0));
      expect(bq.alignment, BlockAlignment.center);
      expect(bq.textWrap, TextWrapMode.wrap);
      expect(bq.border?.style, BlockBorderStyle.solid);
      expect(bq.border?.width, 2.0);
    });

    test('horizontal rule round-trips', () {
      final doc = Document([
        HorizontalRuleNode(
          id: 'hr-1',
          width: const PixelDimension(300.0),
          height: const PixelDimension(2.0),
          alignment: BlockAlignment.center,
          textWrap: TextWrapMode.none,
          spaceBefore: 16.0,
          spaceAfter: 16.0,
          border: const BlockBorder(style: BlockBorderStyle.solid),
        ),
      ]);
      final json = serializer.toJson(doc);
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final nodes = serializer.fromJson(decoded);

      final hr = nodes[0] as HorizontalRuleNode;
      expect(hr.id, 'hr-1');
      expect(hr.width, const PixelDimension(300.0));
      expect(hr.height, const PixelDimension(2.0));
      expect(hr.alignment, BlockAlignment.center);
      expect(hr.textWrap, TextWrapMode.none);
      expect(hr.spaceBefore, 16.0);
      expect(hr.spaceAfter, 16.0);
      expect(hr.border?.style, BlockBorderStyle.solid);
    });

    test('table node with cells, column widths, row heights, alignments round-trips', () {
      final cells = [
        [AttributedText('r0c0'), AttributedText('r0c1')],
        [AttributedText('r1c0'), AttributedText('r1c1')],
      ];
      final doc = Document([
        TableNode(
          id: 'tbl-1',
          rowCount: 2,
          columnCount: 2,
          cells: cells,
          columnWidths: [120.0, null],
          rowHeights: [null, 60.0],
          cellTextAligns: [
            [TextAlign.left, TextAlign.center],
            [TextAlign.right, TextAlign.start],
          ],
          cellVerticalAligns: [
            [TableVerticalAlignment.top, TableVerticalAlignment.middle],
            [TableVerticalAlignment.bottom, TableVerticalAlignment.top],
          ],
          alignment: BlockAlignment.center,
          textWrap: TextWrapMode.wrap,
          width: const PixelDimension(400.0),
          height: const PixelDimension(200.0),
          spaceBefore: 8.0,
          spaceAfter: 8.0,
          border: const BlockBorder(style: BlockBorderStyle.solid, width: 1.0),
        ),
      ]);
      final json = serializer.toJson(doc);
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final nodes = serializer.fromJson(decoded);

      final tbl = nodes[0] as TableNode;
      expect(tbl.id, 'tbl-1');
      expect(tbl.rowCount, 2);
      expect(tbl.columnCount, 2);
      expect(tbl.cellAt(0, 0).text, 'r0c0');
      expect(tbl.cellAt(0, 1).text, 'r0c1');
      expect(tbl.cellAt(1, 0).text, 'r1c0');
      expect(tbl.cellAt(1, 1).text, 'r1c1');
      expect(tbl.columnWidths, [120.0, null]);
      expect(tbl.rowHeights, [null, 60.0]);
      expect(tbl.cellTextAligns![0][0], TextAlign.left);
      expect(tbl.cellTextAligns![0][1], TextAlign.center);
      expect(tbl.cellTextAligns![1][0], TextAlign.right);
      expect(tbl.cellTextAligns![1][1], TextAlign.start);
      expect(tbl.cellVerticalAligns![0][0], TableVerticalAlignment.top);
      expect(tbl.cellVerticalAligns![0][1], TableVerticalAlignment.middle);
      expect(tbl.cellVerticalAligns![1][0], TableVerticalAlignment.bottom);
      expect(tbl.alignment, BlockAlignment.center);
      expect(tbl.textWrap, TextWrapMode.wrap);
      expect(tbl.width, const PixelDimension(400.0));
      expect(tbl.height, const PixelDimension(200.0));
      expect(tbl.spaceBefore, 8.0);
      expect(tbl.spaceAfter, 8.0);
      expect(tbl.border?.style, BlockBorderStyle.solid);
    });

    test('table node without optional lists round-trips', () {
      final doc = Document([
        TableNode(
          id: 'tbl-2',
          rowCount: 1,
          columnCount: 1,
          cells: [
            [AttributedText('cell')],
          ],
        ),
      ]);
      final json = serializer.toJson(doc);
      final nodes = serializer.fromJson(json);
      final tbl = nodes[0] as TableNode;
      expect(tbl.columnWidths, isNull);
      expect(tbl.rowHeights, isNull);
      expect(tbl.cellTextAligns, isNull);
      expect(tbl.cellVerticalAligns, isNull);
    });

    test('unknown node type falls back to plain paragraph', () {
      final json = <String, Object?>{
        'nodes': [
          {'id': 'x1', 'type': 'unknown', 'text': 'Fallback'},
        ],
      };
      final nodes = serializer.fromJson(json);
      expect(nodes, hasLength(1));
      expect(nodes[0], isA<ParagraphNode>());
      expect((nodes[0] as ParagraphNode).text.text, 'Fallback');
    });

    test('full mixed document round-trips', () {
      final doc = Document([
        ParagraphNode(
          id: 'p-1',
          text: AttributedText('Intro'),
          blockType: ParagraphBlockType.header1,
        ),
        ListItemNode(
          id: 'li-1',
          text: AttributedText('Point one'),
          type: ListItemType.unordered,
        ),
        ListItemNode(
          id: 'li-2',
          text: AttributedText('Point two'),
          type: ListItemType.ordered,
          indent: 1,
        ),
        ImageNode(
          id: 'img-1',
          imageUrl: 'https://example.com/img.png',
        ),
        CodeBlockNode(
          id: 'code-1',
          text: AttributedText('print("hi")'),
          language: 'dart',
        ),
        BlockquoteNode(
          id: 'bq-1',
          text: AttributedText('Quote'),
        ),
        HorizontalRuleNode(id: 'hr-1'),
        TableNode(
          id: 'tbl-1',
          rowCount: 2,
          columnCount: 2,
          cells: [
            [AttributedText('a'), AttributedText('b')],
            [AttributedText('c'), AttributedText('d')],
          ],
        ),
      ]);

      final json = serializer.toJson(doc);
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final nodes = serializer.fromJson(decoded);

      expect(nodes, hasLength(8));
      expect(nodes[0], isA<ParagraphNode>());
      expect((nodes[0] as ParagraphNode).blockType, ParagraphBlockType.header1);
      expect(nodes[1], isA<ListItemNode>());
      expect((nodes[1] as ListItemNode).type, ListItemType.unordered);
      expect(nodes[2], isA<ListItemNode>());
      expect((nodes[2] as ListItemNode).type, ListItemType.ordered);
      expect(nodes[3], isA<ImageNode>());
      expect(nodes[4], isA<CodeBlockNode>());
      expect((nodes[4] as CodeBlockNode).language, 'dart');
      expect(nodes[5], isA<BlockquoteNode>());
      expect(nodes[6], isA<HorizontalRuleNode>());
      expect(nodes[7], isA<TableNode>());
      expect((nodes[7] as TableNode).rowCount, 2);
    });
  });
}
