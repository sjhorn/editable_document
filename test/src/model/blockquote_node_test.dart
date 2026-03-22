import 'dart:ui' show TextAlign;

import 'package:editable_document/src/model/attributed_text.dart';
import 'package:editable_document/src/model/block_alignment.dart';
import 'package:editable_document/src/model/block_border.dart';
import 'package:editable_document/src/model/block_dimension.dart';
import 'package:editable_document/src/model/blockquote_node.dart';
import 'package:editable_document/src/model/text_node.dart';
import 'package:editable_document/src/model/text_wrap_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // BlockquoteNode — default values
  // ---------------------------------------------------------------------------
  group('BlockquoteNode default values', () {
    test('width defaults to null', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.width, isNull);
    });

    test('height defaults to null', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.height, isNull);
    });

    test('alignment defaults to BlockAlignment.stretch', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.alignment, BlockAlignment.stretch);
    });

    test('textWrap defaults to TextWrapMode.none', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.textWrap, TextWrapMode.none);
    });

    test('text defaults to empty AttributedText', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.text.text, '');
      expect(node.text.length, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — constructor with custom values
  // ---------------------------------------------------------------------------
  group('BlockquoteNode constructor with custom values', () {
    test('id is set correctly', () {
      final node = BlockquoteNode(id: 'my-bq-id');
      expect(node.id, 'my-bq-id');
    });

    test('text is set from AttributedText', () {
      final text = AttributedText('To be or not to be');
      final node = BlockquoteNode(id: 'bq1', text: text);
      expect(node.text.text, 'To be or not to be');
    });

    test('width is set correctly', () {
      final node = BlockquoteNode(id: 'bq1', width: const BlockDimension.pixels(480.0));
      expect(node.width, const BlockDimension.pixels(480.0));
    });

    test('height is set correctly', () {
      final node = BlockquoteNode(id: 'bq1', height: const BlockDimension.pixels(200.0));
      expect(node.height, const BlockDimension.pixels(200.0));
    });

    test('alignment is set correctly', () {
      final node = BlockquoteNode(id: 'bq1', alignment: BlockAlignment.center);
      expect(node.alignment, BlockAlignment.center);
    });

    test('textWrap is set correctly', () {
      final node = BlockquoteNode(id: 'bq1', textWrap: TextWrapMode.wrap);
      expect(node.textWrap, TextWrapMode.wrap);
    });

    test('all fields set together', () {
      final text = AttributedText('Famous quote');
      final node = BlockquoteNode(
        id: 'bq1',
        text: text,
        width: const BlockDimension.pixels(640.0),
        height: const BlockDimension.pixels(300.0),
        alignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
        metadata: {'source': 'shakespeare'},
      );
      expect(node.id, 'bq1');
      expect(node.text.text, 'Famous quote');
      expect(node.width, const BlockDimension.pixels(640.0));
      expect(node.height, const BlockDimension.pixels(300.0));
      expect(node.alignment, BlockAlignment.end);
      expect(node.textWrap, TextWrapMode.wrap);
      expect(node.metadata['source'], 'shakespeare');
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — copyWith round-trips
  // ---------------------------------------------------------------------------
  group('BlockquoteNode copyWith', () {
    test('copyWith replaces id', () {
      final node = BlockquoteNode(id: 'bq1');
      final copy = node.copyWith(id: 'bq2');
      expect(copy.id, 'bq2');
    });

    test('copyWith replaces text', () {
      final node = BlockquoteNode(id: 'bq1', text: AttributedText('original'));
      final copy = node.copyWith(text: AttributedText('replaced'));
      expect(copy.text.text, 'replaced');
      expect(copy.id, 'bq1');
    });

    test('copyWith replaces width', () {
      final node = BlockquoteNode(id: 'bq1', width: const BlockDimension.pixels(100.0));
      final copy = node.copyWith(width: const BlockDimension.pixels(200.0));
      expect(copy.width, const BlockDimension.pixels(200.0));
      expect(copy.id, 'bq1');
    });

    test('copyWith replaces height', () {
      final node = BlockquoteNode(id: 'bq1', height: const BlockDimension.pixels(50.0));
      final copy = node.copyWith(height: const BlockDimension.pixels(150.0));
      expect(copy.height, const BlockDimension.pixels(150.0));
    });

    test('copyWith replaces alignment', () {
      final node = BlockquoteNode(id: 'bq1', alignment: BlockAlignment.start);
      final copy = node.copyWith(alignment: BlockAlignment.end);
      expect(copy.alignment, BlockAlignment.end);
    });

    test('copyWith replaces textWrap', () {
      final node = BlockquoteNode(id: 'bq1', textWrap: TextWrapMode.none);
      final copy = node.copyWith(textWrap: TextWrapMode.wrap);
      expect(copy.textWrap, TextWrapMode.wrap);
    });

    test('copyWith replaces metadata', () {
      final node = BlockquoteNode(id: 'bq1');
      final copy = node.copyWith(metadata: {'author': 'Hamlet'});
      expect(copy.metadata['author'], 'Hamlet');
    });

    test('copyWith preserves id when not specified', () {
      final node = BlockquoteNode(id: 'keep-me', width: const BlockDimension.pixels(100.0));
      final copy = node.copyWith(width: const BlockDimension.pixels(200.0));
      expect(copy.id, 'keep-me');
    });

    test('copyWith preserves text when not specified', () {
      final node = BlockquoteNode(id: 'bq1', text: AttributedText('keep me'));
      final copy = node.copyWith(id: 'bq2');
      expect(copy.text.text, 'keep me');
    });

    test('copyWith preserves width when not specified', () {
      final node = BlockquoteNode(id: 'bq1', width: const BlockDimension.pixels(320.0));
      final copy = node.copyWith(id: 'bq2');
      expect(copy.width, const BlockDimension.pixels(320.0));
    });

    test('copyWith preserves height when not specified', () {
      final node = BlockquoteNode(id: 'bq1', height: const BlockDimension.pixels(240.0));
      final copy = node.copyWith(id: 'bq2');
      expect(copy.height, const BlockDimension.pixels(240.0));
    });

    test('copyWith preserves alignment when not specified', () {
      final node = BlockquoteNode(id: 'bq1', alignment: BlockAlignment.center);
      final copy = node.copyWith(id: 'bq2');
      expect(copy.alignment, BlockAlignment.center);
    });

    test('copyWith preserves textWrap when not specified', () {
      final node = BlockquoteNode(id: 'bq1', textWrap: TextWrapMode.wrap);
      final copy = node.copyWith(id: 'bq2');
      expect(copy.textWrap, TextWrapMode.wrap);
    });

    test('copyWith preserves metadata when not specified', () {
      final node = BlockquoteNode(id: 'bq1', metadata: {'style': 'epic'});
      final copy = node.copyWith(id: 'bq2');
      expect(copy.metadata['style'], 'epic');
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — equality
  // ---------------------------------------------------------------------------
  group('BlockquoteNode equality', () {
    test('equal when all fields are the same', () {
      final text = AttributedText('quote');
      final a = BlockquoteNode(
        id: 'bq1',
        text: text,
        width: const BlockDimension.pixels(400.0),
        height: const BlockDimension.pixels(100.0),
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final b = BlockquoteNode(
        id: 'bq1',
        text: AttributedText('quote'),
        width: const BlockDimension.pixels(400.0),
        height: const BlockDimension.pixels(100.0),
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      expect(a, equals(b));
    });

    test('unequal when id differs', () {
      final a = BlockquoteNode(id: 'bq1');
      final b = BlockquoteNode(id: 'bq2');
      expect(a, isNot(equals(b)));
    });

    test('unequal when text differs', () {
      final a = BlockquoteNode(id: 'bq1', text: AttributedText('hello'));
      final b = BlockquoteNode(id: 'bq1', text: AttributedText('world'));
      expect(a, isNot(equals(b)));
    });

    test('unequal when width differs', () {
      final a = BlockquoteNode(id: 'bq1', width: const BlockDimension.pixels(100.0));
      final b = BlockquoteNode(id: 'bq1', width: const BlockDimension.pixels(200.0));
      expect(a, isNot(equals(b)));
    });

    test('unequal when height differs', () {
      final a = BlockquoteNode(id: 'bq1', height: const BlockDimension.pixels(50.0));
      final b = BlockquoteNode(id: 'bq1', height: const BlockDimension.pixels(100.0));
      expect(a, isNot(equals(b)));
    });

    test('unequal when alignment differs', () {
      final a = BlockquoteNode(id: 'bq1', alignment: BlockAlignment.center);
      final b = BlockquoteNode(id: 'bq1', alignment: BlockAlignment.start);
      expect(a, isNot(equals(b)));
    });

    test('unequal when textWrap differs', () {
      final a = BlockquoteNode(id: 'bq1', textWrap: TextWrapMode.wrap);
      final b = BlockquoteNode(id: 'bq1', textWrap: TextWrapMode.none);
      expect(a, isNot(equals(b)));
    });

    test('unequal when metadata differs', () {
      final a = BlockquoteNode(id: 'bq1', metadata: {'key': 'val1'});
      final b = BlockquoteNode(id: 'bq1', metadata: {'key': 'val2'});
      expect(a, isNot(equals(b)));
    });

    test('identical instance equals itself', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node, equals(node));
    });

    test('not equal to a different runtimeType', () {
      final bq = BlockquoteNode(id: 'bq1', text: AttributedText('quote'));
      // TextNode has same fields but different runtimeType
      final tn = TextNode(id: 'bq1', text: AttributedText('quote'));
      expect(bq, isNot(equals(tn)));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — hashCode consistency with equality
  // ---------------------------------------------------------------------------
  group('BlockquoteNode hashCode', () {
    test('hashCode matches for equal nodes', () {
      final a = BlockquoteNode(id: 'bq1', alignment: BlockAlignment.center);
      final b = BlockquoteNode(id: 'bq1', alignment: BlockAlignment.center);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode is consistent on same instance', () {
      final node = BlockquoteNode(
        id: 'bq1',
        width: const BlockDimension.pixels(200.0),
        textWrap: TextWrapMode.wrap,
      );
      expect(node.hashCode, node.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — toString
  // ---------------------------------------------------------------------------
  group('BlockquoteNode toString', () {
    test('toString includes id', () {
      final node = BlockquoteNode(id: 'bq-unique');
      expect(node.toString(), contains('bq-unique'));
    });

    test('toString includes text', () {
      final node = BlockquoteNode(id: 'bq1', text: AttributedText('check this'));
      expect(node.toString(), contains('check this'));
    });

    test('toString includes width', () {
      final node = BlockquoteNode(id: 'bq1', width: const BlockDimension.pixels(480.0));
      expect(node.toString(), contains('480.0'));
    });

    test('toString includes height', () {
      final node = BlockquoteNode(id: 'bq1', height: const BlockDimension.pixels(200.0));
      expect(node.toString(), contains('200.0'));
    });

    test('toString includes alignment', () {
      final node = BlockquoteNode(id: 'bq1', alignment: BlockAlignment.center);
      expect(node.toString(), contains('center'));
    });

    test('toString includes textWrap', () {
      final node = BlockquoteNode(id: 'bq1', textWrap: TextWrapMode.wrap);
      expect(node.toString(), contains('wrap'));
    });

    test('toString mentions BlockquoteNode type', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.toString(), contains('BlockquoteNode'));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — is-a TextNode
  // ---------------------------------------------------------------------------
  group('BlockquoteNode is-a TextNode', () {
    test('BlockquoteNode is a TextNode', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node, isA<TextNode>());
    });

    test('BlockquoteNode is also a DocumentNode', () {
      // TextNode extends DocumentNode so this must hold transitively
      // We check via TextNode which re-exports DocumentNode
      expect(BlockquoteNode(id: 'bq1'), isA<TextNode>());
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — textAlign default value
  // ---------------------------------------------------------------------------
  group('BlockquoteNode textAlign default', () {
    test('textAlign defaults to TextAlign.start', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.textAlign, TextAlign.start);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — constructor with textAlign
  // ---------------------------------------------------------------------------
  group('BlockquoteNode constructor with textAlign', () {
    test('textAlign is set correctly to center', () {
      final node = BlockquoteNode(id: 'bq1', textAlign: TextAlign.center);
      expect(node.textAlign, TextAlign.center);
    });

    test('textAlign is set correctly to end', () {
      final node = BlockquoteNode(id: 'bq1', textAlign: TextAlign.end);
      expect(node.textAlign, TextAlign.end);
    });

    test('textAlign is set correctly to justify', () {
      final node = BlockquoteNode(id: 'bq1', textAlign: TextAlign.justify);
      expect(node.textAlign, TextAlign.justify);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — copyWith with textAlign
  // ---------------------------------------------------------------------------
  group('BlockquoteNode copyWith textAlign', () {
    test('copyWith replaces textAlign', () {
      final node = BlockquoteNode(id: 'bq1', textAlign: TextAlign.start);
      final copy = node.copyWith(textAlign: TextAlign.center);
      expect(copy.textAlign, TextAlign.center);
    });

    test('copyWith preserves textAlign when not specified', () {
      final node = BlockquoteNode(id: 'bq1', textAlign: TextAlign.end);
      final copy = node.copyWith(id: 'bq2');
      expect(copy.textAlign, TextAlign.end);
    });

    test('copyWith preserves other fields when only textAlign changes', () {
      final node = BlockquoteNode(
        id: 'bq1',
        textAlign: TextAlign.start,
        alignment: BlockAlignment.center,
        width: const BlockDimension.pixels(400.0),
      );
      final copy = node.copyWith(textAlign: TextAlign.justify);
      expect(copy.id, 'bq1');
      expect(copy.alignment, BlockAlignment.center);
      expect(copy.width, const BlockDimension.pixels(400.0));
      expect(copy.textAlign, TextAlign.justify);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — equality with textAlign
  // ---------------------------------------------------------------------------
  group('BlockquoteNode equality with textAlign', () {
    test('equal when textAlign is the same', () {
      final a = BlockquoteNode(id: 'bq1', textAlign: TextAlign.center);
      final b = BlockquoteNode(id: 'bq1', textAlign: TextAlign.center);
      expect(a, equals(b));
    });

    test('unequal when textAlign differs', () {
      final a = BlockquoteNode(id: 'bq1', textAlign: TextAlign.start);
      final b = BlockquoteNode(id: 'bq1', textAlign: TextAlign.center);
      expect(a, isNot(equals(b)));
    });

    test('equal when textAlign is both default', () {
      final a = BlockquoteNode(id: 'bq1');
      final b = BlockquoteNode(id: 'bq1');
      expect(a, equals(b));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — hashCode consistency with textAlign
  // ---------------------------------------------------------------------------
  group('BlockquoteNode hashCode with textAlign', () {
    test('hashCode matches for equal nodes with same textAlign', () {
      final a = BlockquoteNode(id: 'bq1', textAlign: TextAlign.center);
      final b = BlockquoteNode(id: 'bq1', textAlign: TextAlign.center);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode differs when textAlign differs', () {
      final a = BlockquoteNode(id: 'bq1', textAlign: TextAlign.start);
      final b = BlockquoteNode(id: 'bq1', textAlign: TextAlign.center);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — toString includes textAlign
  // ---------------------------------------------------------------------------
  group('BlockquoteNode toString with textAlign', () {
    test('toString includes textAlign value', () {
      final node = BlockquoteNode(id: 'bq1', textAlign: TextAlign.center);
      expect(node.toString(), contains('center'));
    });

    test('toString still includes id', () {
      final node = BlockquoteNode(id: 'bq-unique', textAlign: TextAlign.justify);
      expect(node.toString(), contains('bq-unique'));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — lineHeight default value
  // ---------------------------------------------------------------------------
  group('BlockquoteNode lineHeight default', () {
    test('lineHeight defaults to null', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.lineHeight, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — constructor with lineHeight
  // ---------------------------------------------------------------------------
  group('BlockquoteNode constructor with lineHeight', () {
    test('lineHeight is set correctly to 1.5', () {
      final node = BlockquoteNode(id: 'bq1', lineHeight: 1.5);
      expect(node.lineHeight, 1.5);
    });

    test('lineHeight is set correctly to 2.0', () {
      final node = BlockquoteNode(id: 'bq1', lineHeight: 2.0);
      expect(node.lineHeight, 2.0);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — copyWith with lineHeight
  // ---------------------------------------------------------------------------
  group('BlockquoteNode copyWith lineHeight', () {
    test('copyWith replaces lineHeight', () {
      final node = BlockquoteNode(id: 'bq1', lineHeight: 1.5);
      final copy = node.copyWith(lineHeight: 2.0);
      expect(copy.lineHeight, 2.0);
    });

    test('copyWith preserves lineHeight when not specified', () {
      final node = BlockquoteNode(id: 'bq1', lineHeight: 1.8);
      final copy = node.copyWith(id: 'bq2');
      expect(copy.lineHeight, 1.8);
    });

    test('copyWith preserves other fields when only lineHeight changes', () {
      final node = BlockquoteNode(
        id: 'bq1',
        textAlign: TextAlign.center,
        alignment: BlockAlignment.center,
        width: const BlockDimension.pixels(400.0),
        lineHeight: 1.0,
      );
      final copy = node.copyWith(lineHeight: 1.5);
      expect(copy.id, 'bq1');
      expect(copy.textAlign, TextAlign.center);
      expect(copy.alignment, BlockAlignment.center);
      expect(copy.width, const BlockDimension.pixels(400.0));
      expect(copy.lineHeight, 1.5);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — equality with lineHeight
  // ---------------------------------------------------------------------------
  group('BlockquoteNode equality with lineHeight', () {
    test('equal when lineHeight is both null', () {
      final a = BlockquoteNode(id: 'bq1');
      final b = BlockquoteNode(id: 'bq1');
      expect(a, equals(b));
    });

    test('equal when lineHeight is the same non-null value', () {
      final a = BlockquoteNode(id: 'bq1', lineHeight: 1.5);
      final b = BlockquoteNode(id: 'bq1', lineHeight: 1.5);
      expect(a, equals(b));
    });

    test('unequal when lineHeight differs', () {
      final a = BlockquoteNode(id: 'bq1', lineHeight: 1.5);
      final b = BlockquoteNode(id: 'bq1', lineHeight: 2.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when one lineHeight is null and other is not', () {
      final a = BlockquoteNode(id: 'bq1');
      final b = BlockquoteNode(id: 'bq1', lineHeight: 1.5);
      expect(a, isNot(equals(b)));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — hashCode with lineHeight
  // ---------------------------------------------------------------------------
  group('BlockquoteNode hashCode with lineHeight', () {
    test('hashCode matches for equal nodes with same lineHeight', () {
      final a = BlockquoteNode(id: 'bq1', lineHeight: 1.5);
      final b = BlockquoteNode(id: 'bq1', lineHeight: 1.5);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode differs when lineHeight differs', () {
      final a = BlockquoteNode(id: 'bq1', lineHeight: 1.5);
      final b = BlockquoteNode(id: 'bq1', lineHeight: 2.0);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — toString includes lineHeight
  // ---------------------------------------------------------------------------
  group('BlockquoteNode toString with lineHeight', () {
    test('toString includes lineHeight when set', () {
      final node = BlockquoteNode(id: 'bq1', lineHeight: 1.5);
      expect(node.toString(), contains('1.5'));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — debugFillProperties includes lineHeight
  // ---------------------------------------------------------------------------
  group('BlockquoteNode debugFillProperties with lineHeight', () {
    test('debugFillProperties includes lineHeight when non-null', () {
      final node = BlockquoteNode(id: 'bq1', lineHeight: 1.5);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'lineHeight',
            orElse: () => throw StateError('lineHeight property not found'),
          );
      expect(prop.value, 1.5);
    });

    test('debugFillProperties lineHeight is absent (default null) when not set', () {
      final node = BlockquoteNode(id: 'bq1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'lineHeight');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — spaceBefore default value
  // ---------------------------------------------------------------------------
  group('BlockquoteNode spaceBefore default', () {
    test('spaceBefore defaults to null', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.spaceBefore, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — spaceAfter default value
  // ---------------------------------------------------------------------------
  group('BlockquoteNode spaceAfter default', () {
    test('spaceAfter defaults to null', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.spaceAfter, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — constructor with spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('BlockquoteNode constructor with spaceBefore/spaceAfter', () {
    test('spaceBefore is set correctly', () {
      final node = BlockquoteNode(id: 'bq1', spaceBefore: 8.0);
      expect(node.spaceBefore, 8.0);
    });

    test('spaceAfter is set correctly', () {
      final node = BlockquoteNode(id: 'bq1', spaceAfter: 16.0);
      expect(node.spaceAfter, 16.0);
    });

    test('both spaceBefore and spaceAfter can be set together', () {
      final node = BlockquoteNode(id: 'bq1', spaceBefore: 4.0, spaceAfter: 12.0);
      expect(node.spaceBefore, 4.0);
      expect(node.spaceAfter, 12.0);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — copyWith with spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('BlockquoteNode copyWith spaceBefore/spaceAfter', () {
    test('copyWith replaces spaceBefore', () {
      final node = BlockquoteNode(id: 'bq1', spaceBefore: 8.0);
      final copy = node.copyWith(spaceBefore: 16.0);
      expect(copy.spaceBefore, 16.0);
    });

    test('copyWith preserves spaceBefore when not specified', () {
      final node = BlockquoteNode(id: 'bq1', spaceBefore: 8.0);
      final copy = node.copyWith(id: 'bq2');
      expect(copy.spaceBefore, 8.0);
    });

    test('copyWith replaces spaceAfter', () {
      final node = BlockquoteNode(id: 'bq1', spaceAfter: 12.0);
      final copy = node.copyWith(spaceAfter: 24.0);
      expect(copy.spaceAfter, 24.0);
    });

    test('copyWith preserves spaceAfter when not specified', () {
      final node = BlockquoteNode(id: 'bq1', spaceAfter: 12.0);
      final copy = node.copyWith(id: 'bq2');
      expect(copy.spaceAfter, 12.0);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — equality with spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('BlockquoteNode equality with spaceBefore/spaceAfter', () {
    test('unequal when spaceBefore differs', () {
      final a = BlockquoteNode(id: 'bq1', spaceBefore: 8.0);
      final b = BlockquoteNode(id: 'bq1', spaceBefore: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when spaceAfter differs', () {
      final a = BlockquoteNode(id: 'bq1', spaceAfter: 8.0);
      final b = BlockquoteNode(id: 'bq1', spaceAfter: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('equal when spaceBefore and spaceAfter are both null', () {
      final a = BlockquoteNode(id: 'bq1');
      final b = BlockquoteNode(id: 'bq1');
      expect(a, equals(b));
    });

    test('equal when spaceBefore and spaceAfter match', () {
      final a = BlockquoteNode(id: 'bq1', spaceBefore: 4.0, spaceAfter: 8.0);
      final b = BlockquoteNode(id: 'bq1', spaceBefore: 4.0, spaceAfter: 8.0);
      expect(a, equals(b));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — debugFillProperties includes spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('BlockquoteNode debugFillProperties with spaceBefore/spaceAfter', () {
    test('debugFillProperties includes spaceBefore when non-null', () {
      final node = BlockquoteNode(id: 'bq1', spaceBefore: 8.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'spaceBefore',
            orElse: () => throw StateError('spaceBefore property not found'),
          );
      expect(prop.value, 8.0);
    });

    test('debugFillProperties includes spaceAfter when non-null', () {
      final node = BlockquoteNode(id: 'bq1', spaceAfter: 16.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'spaceAfter',
            orElse: () => throw StateError('spaceAfter property not found'),
          );
      expect(prop.value, 16.0);
    });

    test('debugFillProperties spaceBefore value is null when not set', () {
      final node = BlockquoteNode(id: 'bq1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'spaceBefore');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });

    test('debugFillProperties spaceAfter value is null when not set', () {
      final node = BlockquoteNode(id: 'bq1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'spaceAfter');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — indentLeft default value
  // ---------------------------------------------------------------------------
  group('BlockquoteNode indentLeft default', () {
    test('indentLeft defaults to null', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.indentLeft, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — indentRight default value
  // ---------------------------------------------------------------------------
  group('BlockquoteNode indentRight default', () {
    test('indentRight defaults to null', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.indentRight, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — firstLineIndent default value
  // ---------------------------------------------------------------------------
  group('BlockquoteNode firstLineIndent default', () {
    test('firstLineIndent defaults to null', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.firstLineIndent, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — constructor with indent fields
  // ---------------------------------------------------------------------------
  group('BlockquoteNode constructor with indent fields', () {
    test('indentLeft is set correctly', () {
      final node = BlockquoteNode(id: 'bq1', indentLeft: 16.0);
      expect(node.indentLeft, 16.0);
    });

    test('indentRight is set correctly', () {
      final node = BlockquoteNode(id: 'bq1', indentRight: 8.0);
      expect(node.indentRight, 8.0);
    });

    test('firstLineIndent is set correctly (positive)', () {
      final node = BlockquoteNode(id: 'bq1', firstLineIndent: 24.0);
      expect(node.firstLineIndent, 24.0);
    });

    test('firstLineIndent is set correctly (negative — hanging indent)', () {
      final node = BlockquoteNode(id: 'bq1', firstLineIndent: -16.0);
      expect(node.firstLineIndent, -16.0);
    });

    test('all three indent fields can be set together', () {
      final node =
          BlockquoteNode(id: 'bq1', indentLeft: 16.0, indentRight: 8.0, firstLineIndent: 24.0);
      expect(node.indentLeft, 16.0);
      expect(node.indentRight, 8.0);
      expect(node.firstLineIndent, 24.0);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — copyWith with indent fields
  // ---------------------------------------------------------------------------
  group('BlockquoteNode copyWith indent fields', () {
    test('copyWith replaces indentLeft', () {
      final node = BlockquoteNode(id: 'bq1', indentLeft: 8.0);
      final copy = node.copyWith(indentLeft: 16.0);
      expect(copy.indentLeft, 16.0);
    });

    test('copyWith preserves indentLeft when not specified', () {
      final node = BlockquoteNode(id: 'bq1', indentLeft: 8.0);
      final copy = node.copyWith(id: 'bq2');
      expect(copy.indentLeft, 8.0);
    });

    test('copyWith replaces indentRight', () {
      final node = BlockquoteNode(id: 'bq1', indentRight: 8.0);
      final copy = node.copyWith(indentRight: 16.0);
      expect(copy.indentRight, 16.0);
    });

    test('copyWith preserves indentRight when not specified', () {
      final node = BlockquoteNode(id: 'bq1', indentRight: 8.0);
      final copy = node.copyWith(id: 'bq2');
      expect(copy.indentRight, 8.0);
    });

    test('copyWith replaces firstLineIndent', () {
      final node = BlockquoteNode(id: 'bq1', firstLineIndent: 24.0);
      final copy = node.copyWith(firstLineIndent: -16.0);
      expect(copy.firstLineIndent, -16.0);
    });

    test('copyWith preserves firstLineIndent when not specified', () {
      final node = BlockquoteNode(id: 'bq1', firstLineIndent: 24.0);
      final copy = node.copyWith(id: 'bq2');
      expect(copy.firstLineIndent, 24.0);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — equality with indent fields
  // ---------------------------------------------------------------------------
  group('BlockquoteNode equality with indent fields', () {
    test('equal when all indent fields are both null', () {
      final a = BlockquoteNode(id: 'bq1');
      final b = BlockquoteNode(id: 'bq1');
      expect(a, equals(b));
    });

    test('equal when all indent fields match', () {
      final a =
          BlockquoteNode(id: 'bq1', indentLeft: 16.0, indentRight: 8.0, firstLineIndent: 24.0);
      final b =
          BlockquoteNode(id: 'bq1', indentLeft: 16.0, indentRight: 8.0, firstLineIndent: 24.0);
      expect(a, equals(b));
    });

    test('unequal when indentLeft differs', () {
      final a = BlockquoteNode(id: 'bq1', indentLeft: 8.0);
      final b = BlockquoteNode(id: 'bq1', indentLeft: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when indentRight differs', () {
      final a = BlockquoteNode(id: 'bq1', indentRight: 4.0);
      final b = BlockquoteNode(id: 'bq1', indentRight: 8.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when firstLineIndent differs', () {
      final a = BlockquoteNode(id: 'bq1', firstLineIndent: 16.0);
      final b = BlockquoteNode(id: 'bq1', firstLineIndent: 24.0);
      expect(a, isNot(equals(b)));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — hashCode with indent fields
  // ---------------------------------------------------------------------------
  group('BlockquoteNode hashCode with indent fields', () {
    test('hashCode matches for equal nodes with same indent fields', () {
      final a =
          BlockquoteNode(id: 'bq1', indentLeft: 16.0, indentRight: 8.0, firstLineIndent: 24.0);
      final b =
          BlockquoteNode(id: 'bq1', indentLeft: 16.0, indentRight: 8.0, firstLineIndent: 24.0);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode differs when indentLeft differs', () {
      final a = BlockquoteNode(id: 'bq1', indentLeft: 8.0);
      final b = BlockquoteNode(id: 'bq1', indentLeft: 16.0);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — debugFillProperties includes indent fields
  // ---------------------------------------------------------------------------
  group('BlockquoteNode debugFillProperties with indent fields', () {
    test('debugFillProperties includes indentLeft when non-null', () {
      final node = BlockquoteNode(id: 'bq1', indentLeft: 16.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'indentLeft',
            orElse: () => throw StateError('indentLeft property not found'),
          );
      expect(prop.value, 16.0);
    });

    test('debugFillProperties includes indentRight when non-null', () {
      final node = BlockquoteNode(id: 'bq1', indentRight: 8.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'indentRight',
            orElse: () => throw StateError('indentRight property not found'),
          );
      expect(prop.value, 8.0);
    });

    test('debugFillProperties includes firstLineIndent when non-null', () {
      final node = BlockquoteNode(id: 'bq1', firstLineIndent: 24.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'firstLineIndent',
            orElse: () => throw StateError('firstLineIndent property not found'),
          );
      expect(prop.value, 24.0);
    });

    test('debugFillProperties indentLeft value is null when not set', () {
      final node = BlockquoteNode(id: 'bq1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'indentLeft');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — border default value
  // ---------------------------------------------------------------------------
  group('BlockquoteNode border default', () {
    test('border defaults to null', () {
      final node = BlockquoteNode(id: 'bq1');
      expect(node.border, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — constructor with border
  // ---------------------------------------------------------------------------
  group('BlockquoteNode constructor with border', () {
    test('border is set correctly', () {
      const border = BlockBorder(style: BlockBorderStyle.solid, width: 2.0);
      final node = BlockquoteNode(id: 'bq1', border: border);
      expect(node.border, border);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — copyWith with border
  // ---------------------------------------------------------------------------
  group('BlockquoteNode copyWith border', () {
    test('copyWith replaces border', () {
      const original = BlockBorder(style: BlockBorderStyle.solid, width: 1.0);
      const replacement = BlockBorder(style: BlockBorderStyle.dashed, width: 2.0);
      final node = BlockquoteNode(id: 'bq1', border: original);
      final copy = node.copyWith(border: replacement);
      expect(copy.border, replacement);
    });

    test('copyWith preserves border when not specified', () {
      const border = BlockBorder(style: BlockBorderStyle.dotted, width: 3.0);
      final node = BlockquoteNode(id: 'bq1', border: border);
      final copy = node.copyWith(id: 'bq2');
      expect(copy.border, border);
    });
  });

  // ---------------------------------------------------------------------------
  // BlockquoteNode — equality with border
  // ---------------------------------------------------------------------------
  group('BlockquoteNode equality with border', () {
    test('equal when border is both null', () {
      final a = BlockquoteNode(id: 'bq1');
      final b = BlockquoteNode(id: 'bq1');
      expect(a, equals(b));
    });

    test('equal when border matches', () {
      const border = BlockBorder(style: BlockBorderStyle.solid, width: 2.0);
      final a = BlockquoteNode(id: 'bq1', border: border);
      final b = BlockquoteNode(id: 'bq1', border: border);
      expect(a, equals(b));
    });

    test('unequal when border differs', () {
      final a = BlockquoteNode(id: 'bq1', border: const BlockBorder(width: 1.0));
      final b = BlockquoteNode(id: 'bq1', border: const BlockBorder(width: 2.0));
      expect(a, isNot(equals(b)));
    });

    test('unequal when one border is null and other is not', () {
      final a = BlockquoteNode(id: 'bq1');
      final b = BlockquoteNode(id: 'bq1', border: const BlockBorder());
      expect(a, isNot(equals(b)));
    });
  });
}
