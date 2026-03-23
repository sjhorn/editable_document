/// JSON serialization and deserialization of [Document] instances.
///
/// Provides [DocumentJsonSerializer], a const-constructible utility class that
/// converts a [Document] to a JSON-compatible map and restores a list of
/// [DocumentNode]s from the same map structure.
library;

import 'dart:ui' show TextAlign;

import 'package:flutter/painting.dart' show Color;

import 'attribution.dart';
import 'attributed_text.dart';
import 'block_alignment.dart';
import 'block_border.dart';
import 'block_dimension.dart';
import 'block_layout.dart';
import 'blockquote_node.dart';
import 'code_block_node.dart';
import 'document.dart';
import 'document_node.dart';
import 'horizontal_rule_node.dart';
import 'image_node.dart';
import 'list_item_node.dart';
import 'paragraph_node.dart';
import 'table_node.dart';
import 'table_vertical_alignment.dart';
import 'text_wrap_mode.dart';

/// Serializes and deserializes [Document] instances to/from JSON maps.
///
/// Supports all built-in node types: [ParagraphNode], [ListItemNode],
/// [ImageNode], [CodeBlockNode], [BlockquoteNode], [HorizontalRuleNode],
/// and [TableNode].
///
/// ```dart
/// const serializer = DocumentJsonSerializer();
///
/// // Serialize
/// final json = serializer.toJson(document);
/// final encoded = jsonEncode(json);
///
/// // Deserialize
/// final decoded = jsonDecode(encoded) as Map<String, Object?>;
/// final nodes = serializer.fromJson(decoded);
/// ```
class DocumentJsonSerializer {
  /// Creates a const [DocumentJsonSerializer].
  const DocumentJsonSerializer();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Serializes [document] to a JSON-compatible map.
  ///
  /// The returned map has a single `'nodes'` key whose value is a list of
  /// node maps. Each node map contains at minimum an `'id'` key and a `'type'`
  /// key identifying the node subtype.
  ///
  /// Only non-default field values are written to keep the output compact.
  Map<String, Object?> toJson(Document document) {
    final nodes = <Map<String, Object?>>[];
    for (final node in document.nodes) {
      nodes.add(_nodeToJson(node));
    }
    return {'nodes': nodes};
  }

  /// Deserializes a list of [DocumentNode]s from a JSON map.
  ///
  /// The map must have a `'nodes'` key containing a list of node maps,
  /// each of which was produced by [toJson]. Missing or unrecognised node
  /// types fall back to a plain [ParagraphNode].
  ///
  /// When the `'id'` key is absent a fresh id is generated via
  /// [generateNodeId].
  List<DocumentNode> fromJson(Map<String, Object?> json) {
    final nodeList = json['nodes'] as List<Object?>? ?? const [];
    final nodes = <DocumentNode>[];
    for (final raw in nodeList) {
      final map = raw! as Map<String, Object?>;
      nodes.add(_nodeFromJson(map));
    }
    return nodes;
  }

  // ---------------------------------------------------------------------------
  // Helper methods exposed as non-private so test code can unit-test each
  // helper individually without going through the full round-trip path.
  // ---------------------------------------------------------------------------

  /// Serializes [border] fields into [map].
  ///
  /// Writes three keys when [border] is non-null:
  /// - `'borderStyle'` — the `BlockBorderStyle.name` string.
  /// - `'borderWidth'` — the stroke width as a [double].
  /// - `'borderColor'` — the ARGB 32-bit integer (omitted when `border.color`
  ///   is `null`).
  ///
  /// Does nothing when [border] is `null`.
  void addBorderFields(Map<String, Object?> map, BlockBorder? border) {
    if (border == null) return;
    map['borderStyle'] = border.style.name;
    map['borderWidth'] = border.width;
    if (border.color != null) map['borderColor'] = border.color!.toARGB32();
  }

  /// Deserializes a [BlockBorder] from [map], or returns `null` when the
  /// `'borderStyle'` key is absent.
  ///
  /// Falls back to [BlockBorderStyle.solid] for unrecognised style names.
  BlockBorder? parseBorder(Map<String, Object?> map) {
    final styleName = map['borderStyle'] as String?;
    if (styleName == null) return null;
    final style = BlockBorderStyle.values.firstWhere(
      (s) => s.name == styleName,
      orElse: () => BlockBorderStyle.solid,
    );
    return BlockBorder(
      style: style,
      width: (map['borderWidth'] as num?)?.toDouble() ?? 1.0,
      color: map['borderColor'] != null ? Color(map['borderColor']! as int) : null,
    );
  }

  /// Serializes a [BlockDimension] into a JSON-safe map, or returns `null`
  /// when [dim] is `null`.
  ///
  /// - [PixelDimension] → `{'type': 'pixels', 'value': <double>}`
  /// - [PercentDimension] → `{'type': 'percent', 'value': <double>}` where
  ///   the stored value is the fractional representation (e.g. `0.5` for 50%).
  Map<String, Object?>? blockDimensionToJson(BlockDimension? dim) {
    return switch (dim) {
      PixelDimension(:final value) => {'type': 'pixels', 'value': value},
      PercentDimension(:final value) => {'type': 'percent', 'value': value},
      null => null,
    };
  }

  /// Deserializes a [BlockDimension] from a raw JSON value, or returns `null`
  /// when [raw] is `null`.
  ///
  /// Unknown `'type'` strings are treated as pixel dimensions.
  BlockDimension? parseBlockDimension(Object? raw) {
    if (raw == null) return null;
    final map = raw as Map<String, Object?>;
    final type = map['type'] as String?;
    final value = (map['value'] as num?)?.toDouble() ?? 0.0;
    return switch (type) {
      'percent' => BlockDimension.percent(value),
      _ => BlockDimension.pixels(value),
    };
  }

  /// Serializes attribution spans from [text] into [map] under the key
  /// `'attributions'`.
  ///
  /// Parameterized attributions ([FontFamilyAttribution],
  /// [FontSizeAttribution], [TextColorAttribution],
  /// [BackgroundColorAttribution]) include an additional `'value'` key so
  /// the round-trip can reconstruct the correct type.
  ///
  /// Does nothing when [text] carries no attributions.
  void addAttributionSpans(Map<String, Object?> map, AttributedText text) {
    final spans = text.getAttributionSpansInRange(0, text.text.length).toList();
    if (spans.isEmpty) return;
    map['attributions'] = spans.map((s) {
      final spanMap = <String, Object?>{
        'attribution': s.attribution.id,
        'start': s.start,
        'end': s.end,
      };
      final attr = s.attribution;
      if (attr is FontFamilyAttribution) {
        spanMap['value'] = attr.fontFamily;
      } else if (attr is FontSizeAttribution) {
        spanMap['value'] = attr.fontSize;
      } else if (attr is TextColorAttribution) {
        spanMap['value'] = attr.colorValue;
      } else if (attr is BackgroundColorAttribution) {
        spanMap['value'] = attr.colorValue;
      }
      return spanMap;
    }).toList();
  }

  /// Deserializes an [AttributedText] from a JSON node map.
  ///
  /// Handles plain [NamedAttribution]s (identified by their `'attribution'`
  /// id string) and the four parameterized attribution types
  /// ([FontFamilyAttribution], [FontSizeAttribution], [TextColorAttribution],
  /// [BackgroundColorAttribution]), which also carry a `'value'` key.
  AttributedText textFromJson(Map<String, Object?> map) {
    var text = AttributedText(map['text'] as String? ?? '');
    final attributions = map['attributions'] as List<Object?>?;
    if (attributions != null) {
      for (final raw in attributions) {
        final span = raw! as Map<String, Object?>;
        final attrId = span['attribution'] as String;
        final start = span['start'] as int;
        final end = span['end'] as int;
        final attribution = _attributionFromSpanMap(attrId, span);
        text = text.applyAttribution(attribution, start, end);
      }
    }
    return text;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Serializes a single [node] to a JSON map.
  Map<String, Object?> _nodeToJson(DocumentNode node) {
    final map = <String, Object?>{'id': node.id};

    if (node is ParagraphNode) {
      _serializeParagraph(map, node);
    } else if (node is ListItemNode) {
      _serializeListItem(map, node);
    } else if (node is BlockquoteNode) {
      _serializeBlockquote(map, node);
    } else if (node is CodeBlockNode) {
      _serializeCodeBlock(map, node);
    } else if (node is ImageNode) {
      _serializeImage(map, node);
    } else if (node is HorizontalRuleNode) {
      _serializeHorizontalRule(map, node);
    } else if (node is TableNode) {
      _serializeTable(map, node);
    }

    return map;
  }

  void _serializeParagraph(Map<String, Object?> map, ParagraphNode node) {
    map['type'] = 'paragraph';
    map['text'] = node.text.text;
    if (node.blockType != ParagraphBlockType.paragraph) {
      map['blockType'] = node.blockType.name;
    }
    if (node.textAlign != TextAlign.start) {
      map['textAlign'] = node.textAlign.name;
    }
    if (node.lineHeight != null) map['lineHeight'] = node.lineHeight;
    if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
    if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
    if (node.indentLeft != null) map['indentLeft'] = node.indentLeft;
    if (node.indentRight != null) map['indentRight'] = node.indentRight;
    if (node.firstLineIndent != null) map['firstLineIndent'] = node.firstLineIndent;
    addBorderFields(map, node.border);
    addAttributionSpans(map, node.text);
  }

  void _serializeListItem(Map<String, Object?> map, ListItemNode node) {
    map['type'] = 'listItem';
    map['text'] = node.text.text;
    map['listType'] = node.type.name;
    if (node.indent > 0) map['indent'] = node.indent;
    if (node.textAlign != TextAlign.start) {
      map['textAlign'] = node.textAlign.name;
    }
    if (node.lineHeight != null) map['lineHeight'] = node.lineHeight;
    if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
    if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
    if (node.indentLeft != null) map['indentLeft'] = node.indentLeft;
    if (node.indentRight != null) map['indentRight'] = node.indentRight;
    addBorderFields(map, node.border);
    addAttributionSpans(map, node.text);
  }

  void _serializeBlockquote(Map<String, Object?> map, BlockquoteNode node) {
    map['type'] = 'blockquote';
    map['text'] = node.text.text;
    if (node.textAlign != TextAlign.start) {
      map['textAlign'] = node.textAlign.name;
    }
    if (node.lineHeight != null) map['lineHeight'] = node.lineHeight;
    if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
    if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
    if (node.indentLeft != null) map['indentLeft'] = node.indentLeft;
    if (node.indentRight != null) map['indentRight'] = node.indentRight;
    if (node.firstLineIndent != null) map['firstLineIndent'] = node.firstLineIndent;
    addBorderFields(map, node.border);
    _addBlockLayoutFields(map, node);
    addAttributionSpans(map, node.text);
  }

  void _serializeCodeBlock(Map<String, Object?> map, CodeBlockNode node) {
    map['type'] = 'codeBlock';
    map['text'] = node.text.text;
    if (node.language != null) map['language'] = node.language;
    if (node.lineHeight != null) map['lineHeight'] = node.lineHeight;
    if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
    if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
    addBorderFields(map, node.border);
    _addBlockLayoutFields(map, node);
    addAttributionSpans(map, node.text);
  }

  void _serializeImage(Map<String, Object?> map, ImageNode node) {
    map['type'] = 'image';
    map['imageUrl'] = node.imageUrl;
    if (node.altText != null) map['altText'] = node.altText;
    if (!node.lockAspect) map['lockAspect'] = false;
    if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
    if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
    addBorderFields(map, node.border);
    _addBlockLayoutFields(map, node);
  }

  void _serializeHorizontalRule(Map<String, Object?> map, HorizontalRuleNode node) {
    map['type'] = 'horizontalRule';
    if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
    if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
    addBorderFields(map, node.border);
    _addBlockLayoutFields(map, node);
  }

  void _serializeTable(Map<String, Object?> map, TableNode node) {
    map['type'] = 'table';
    map['rowCount'] = node.rowCount;
    map['columnCount'] = node.columnCount;

    // Cells — 2D array of plain text strings.
    map['cells'] = List.generate(
      node.rowCount,
      (r) => List.generate(node.columnCount, (c) => node.cellAt(r, c).text),
    );

    // Cell attributions — only non-empty cells.
    final cellAttrs = List.generate(node.rowCount, (r) {
      return List.generate(node.columnCount, (c) {
        final cell = node.cellAt(r, c);
        final cellMap = <String, Object?>{'text': cell.text};
        addAttributionSpans(cellMap, cell);
        return cellMap;
      });
    });
    map['cellData'] = cellAttrs;

    if (node.columnWidths != null) {
      map['columnWidths'] = node.columnWidths!.map((w) => w).toList();
    }
    if (node.rowHeights != null) {
      map['rowHeights'] = node.rowHeights!.map((h) => h).toList();
    }
    if (node.cellTextAligns != null) {
      map['cellTextAligns'] =
          node.cellTextAligns!.map((row) => row.map((a) => a.name).toList()).toList();
    }
    if (node.cellVerticalAligns != null) {
      map['cellVerticalAligns'] =
          node.cellVerticalAligns!.map((row) => row.map((a) => a.name).toList()).toList();
    }
    if (node.spaceBefore != null) map['spaceBefore'] = node.spaceBefore;
    if (node.spaceAfter != null) map['spaceAfter'] = node.spaceAfter;
    addBorderFields(map, node.border);
    _addBlockLayoutFields(map, node);
  }

  /// Writes block-layout fields (width, height, blockAlignment, textWrap) into
  /// [map] for nodes that implement [HasBlockLayout].
  ///
  /// Only non-default values are written to keep the JSON compact.
  void _addBlockLayoutFields(Map<String, Object?> map, HasBlockLayout node) {
    final widthJson = blockDimensionToJson(node.width);
    if (widthJson != null) map['width'] = widthJson;
    final heightJson = blockDimensionToJson(node.height);
    if (heightJson != null) map['height'] = heightJson;
    if (node.alignment != BlockAlignment.stretch) {
      map['blockAlignment'] = node.alignment.name;
    }
    if (node.textWrap != TextWrapMode.none) {
      map['textWrap'] = node.textWrap.name;
    }
  }

  /// Deserializes a single node map to its corresponding [DocumentNode].
  DocumentNode _nodeFromJson(Map<String, Object?> map) {
    final id = map['id'] as String? ?? generateNodeId();
    final type = map['type'] as String?;
    return switch (type) {
      'paragraph' => _parseParagraph(id, map),
      'listItem' => _parseListItem(id, map),
      'blockquote' => _parseBlockquote(id, map),
      'codeBlock' => _parseCodeBlock(id, map),
      'image' => _parseImage(id, map),
      'horizontalRule' => _parseHorizontalRule(id, map),
      'table' => _parseTable(id, map),
      _ => ParagraphNode(
          id: id,
          text: AttributedText(map['text'] as String? ?? ''),
        ),
    };
  }

  ParagraphNode _parseParagraph(String id, Map<String, Object?> map) {
    final text = textFromJson(map);
    final blockTypeName = map['blockType'] as String?;
    return ParagraphNode(
      id: id,
      text: text,
      blockType: blockTypeName != null
          ? ParagraphBlockType.values.firstWhere(
              (bt) => bt.name == blockTypeName,
              orElse: () => ParagraphBlockType.paragraph,
            )
          : ParagraphBlockType.paragraph,
      textAlign: _parseTextAlign(map['textAlign'] as String?),
      lineHeight: (map['lineHeight'] as num?)?.toDouble(),
      spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
      spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
      indentLeft: (map['indentLeft'] as num?)?.toDouble(),
      indentRight: (map['indentRight'] as num?)?.toDouble(),
      firstLineIndent: (map['firstLineIndent'] as num?)?.toDouble(),
      border: parseBorder(map),
    );
  }

  ListItemNode _parseListItem(String id, Map<String, Object?> map) {
    final text = textFromJson(map);
    final listTypeName = map['listType'] as String? ?? 'unordered';
    return ListItemNode(
      id: id,
      text: text,
      type: listTypeName == 'ordered' ? ListItemType.ordered : ListItemType.unordered,
      indent: (map['indent'] as int?) ?? 0,
      textAlign: _parseTextAlign(map['textAlign'] as String?),
      lineHeight: (map['lineHeight'] as num?)?.toDouble(),
      spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
      spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
      indentLeft: (map['indentLeft'] as num?)?.toDouble(),
      indentRight: (map['indentRight'] as num?)?.toDouble(),
      border: parseBorder(map),
    );
  }

  BlockquoteNode _parseBlockquote(String id, Map<String, Object?> map) {
    final text = textFromJson(map);
    return BlockquoteNode(
      id: id,
      text: text,
      textAlign: _parseTextAlign(map['textAlign'] as String?),
      lineHeight: (map['lineHeight'] as num?)?.toDouble(),
      spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
      spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
      indentLeft: (map['indentLeft'] as num?)?.toDouble(),
      indentRight: (map['indentRight'] as num?)?.toDouble(),
      firstLineIndent: (map['firstLineIndent'] as num?)?.toDouble(),
      border: parseBorder(map),
      width: parseBlockDimension(map['width']),
      height: parseBlockDimension(map['height']),
      alignment: _parseBlockAlignment(map),
      textWrap: _parseTextWrap(map),
    );
  }

  CodeBlockNode _parseCodeBlock(String id, Map<String, Object?> map) {
    final text = textFromJson(map);
    return CodeBlockNode(
      id: id,
      text: text,
      language: map['language'] as String?,
      lineHeight: (map['lineHeight'] as num?)?.toDouble(),
      spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
      spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
      border: parseBorder(map),
      width: parseBlockDimension(map['width']),
      height: parseBlockDimension(map['height']),
      alignment: _parseBlockAlignment(map),
      textWrap: _parseTextWrap(map),
    );
  }

  ImageNode _parseImage(String id, Map<String, Object?> map) {
    return ImageNode(
      id: id,
      imageUrl: map['imageUrl'] as String? ?? '',
      altText: map['altText'] as String?,
      spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
      spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
      lockAspect: (map['lockAspect'] as bool?) ?? true,
      border: parseBorder(map),
      width: parseBlockDimension(map['width']),
      height: parseBlockDimension(map['height']),
      alignment: _parseBlockAlignment(map),
      textWrap: _parseTextWrap(map),
    );
  }

  HorizontalRuleNode _parseHorizontalRule(String id, Map<String, Object?> map) {
    return HorizontalRuleNode(
      id: id,
      spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
      spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
      border: parseBorder(map),
      width: parseBlockDimension(map['width']),
      height: parseBlockDimension(map['height']),
      alignment: _parseBlockAlignment(map),
      textWrap: _parseTextWrap(map),
    );
  }

  TableNode _parseTable(String id, Map<String, Object?> map) {
    final rowCount = (map['rowCount'] as int?) ?? 0;
    final columnCount = (map['columnCount'] as int?) ?? 0;

    // Prefer rich cellData (with attributions) when available; fall back to
    // plain cells array for backwards-compat.
    final List<List<AttributedText>> cells;
    final cellDataRaw = map['cellData'] as List<Object?>?;
    if (cellDataRaw != null) {
      cells = List.generate(rowCount, (r) {
        final rowRaw = cellDataRaw[r] as List<Object?>;
        return List.generate(columnCount, (c) {
          final cellMap = rowRaw[c] as Map<String, Object?>;
          return textFromJson(cellMap);
        });
      });
    } else {
      final cellsRaw = map['cells'] as List<Object?>?;
      cells = List.generate(rowCount, (r) {
        final rowRaw = cellsRaw != null ? cellsRaw[r] as List<Object?> : <Object?>[];
        return List.generate(
          columnCount,
          (c) => AttributedText(rowRaw.length > c ? rowRaw[c] as String? ?? '' : ''),
        );
      });
    }

    final columnWidthsRaw = map['columnWidths'] as List<Object?>?;
    final List<double?>? columnWidths =
        columnWidthsRaw?.map((w) => (w as num?)?.toDouble()).toList();

    final rowHeightsRaw = map['rowHeights'] as List<Object?>?;
    final List<double?>? rowHeights = rowHeightsRaw?.map((h) => (h as num?)?.toDouble()).toList();

    final cellTextAlignsRaw = map['cellTextAligns'] as List<Object?>?;
    final List<List<TextAlign>>? cellTextAligns = cellTextAlignsRaw
        ?.map((row) => (row as List<Object?>).map((a) => _parseTextAlign(a as String?)).toList())
        .toList();

    final cellVerticalAlignsRaw = map['cellVerticalAligns'] as List<Object?>?;
    final List<List<TableVerticalAlignment>>? cellVerticalAligns = cellVerticalAlignsRaw
        ?.map((row) =>
            (row as List<Object?>).map((a) => _parseTableVerticalAlignment(a as String?)).toList())
        .toList();

    return TableNode(
      id: id,
      rowCount: rowCount,
      columnCount: columnCount,
      cells: cells,
      columnWidths: columnWidths,
      rowHeights: rowHeights,
      cellTextAligns: cellTextAligns,
      cellVerticalAligns: cellVerticalAligns,
      alignment: _parseBlockAlignment(map),
      textWrap: _parseTextWrap(map),
      width: parseBlockDimension(map['width']),
      height: parseBlockDimension(map['height']),
      spaceBefore: (map['spaceBefore'] as num?)?.toDouble(),
      spaceAfter: (map['spaceAfter'] as num?)?.toDouble(),
      border: parseBorder(map),
    );
  }

  // ---------------------------------------------------------------------------
  // Enum parsers
  // ---------------------------------------------------------------------------

  /// Parses a [TextAlign] from its [TextAlign.name] string.
  ///
  /// Returns [TextAlign.start] for unrecognised or `null` values.
  TextAlign _parseTextAlign(String? value) {
    if (value == null) return TextAlign.start;
    return TextAlign.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TextAlign.start,
    );
  }

  /// Deserializes [BlockAlignment] from [map], returning [BlockAlignment.stretch]
  /// when the `'blockAlignment'` key is absent.
  BlockAlignment _parseBlockAlignment(Map<String, Object?> map) {
    final name = map['blockAlignment'] as String?;
    if (name == null) return BlockAlignment.stretch;
    return BlockAlignment.values.firstWhere(
      (e) => e.name == name,
      orElse: () => BlockAlignment.stretch,
    );
  }

  /// Deserializes [TextWrapMode] from [map], returning [TextWrapMode.none]
  /// when the `'textWrap'` key is absent.
  TextWrapMode _parseTextWrap(Map<String, Object?> map) {
    final name = map['textWrap'] as String?;
    if (name == null) return TextWrapMode.none;
    return TextWrapMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TextWrapMode.none,
    );
  }

  /// Parses a [TableVerticalAlignment] from its [TableVerticalAlignment.name]
  /// string, returning [TableVerticalAlignment.top] for unrecognised values.
  TableVerticalAlignment _parseTableVerticalAlignment(String? value) {
    if (value == null) return TableVerticalAlignment.top;
    return TableVerticalAlignment.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TableVerticalAlignment.top,
    );
  }

  /// Reconstructs an [Attribution] from its span map entry.
  ///
  /// Dispatches on the [attrId] string, applying the `'value'` key for
  /// parameterized attribution types.
  Attribution _attributionFromSpanMap(String attrId, Map<String, Object?> span) {
    return switch (attrId) {
      'fontFamily' => FontFamilyAttribution(span['value'] as String),
      'fontSize' => FontSizeAttribution((span['value'] as num).toDouble()),
      'textColor' => TextColorAttribution(span['value'] as int),
      'backgroundColor' => BackgroundColorAttribution(span['value'] as int),
      _ => NamedAttribution(attrId),
    };
  }
}
