import 'dart:ui' show TextAlign;

import 'package:editable_document/src/model/attributed_text.dart';
import 'package:editable_document/src/model/block_alignment.dart';
import 'package:editable_document/src/model/blockquote_node.dart';
import 'package:editable_document/src/model/text_node.dart';
import 'package:editable_document/src/model/text_wrap_mode.dart';
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
      final node = BlockquoteNode(id: 'bq1', width: 480.0);
      expect(node.width, 480.0);
    });

    test('height is set correctly', () {
      final node = BlockquoteNode(id: 'bq1', height: 200.0);
      expect(node.height, 200.0);
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
        width: 640.0,
        height: 300.0,
        alignment: BlockAlignment.end,
        textWrap: TextWrapMode.wrap,
        metadata: {'source': 'shakespeare'},
      );
      expect(node.id, 'bq1');
      expect(node.text.text, 'Famous quote');
      expect(node.width, 640.0);
      expect(node.height, 300.0);
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
      final node = BlockquoteNode(id: 'bq1', width: 100.0);
      final copy = node.copyWith(width: 200.0);
      expect(copy.width, 200.0);
      expect(copy.id, 'bq1');
    });

    test('copyWith replaces height', () {
      final node = BlockquoteNode(id: 'bq1', height: 50.0);
      final copy = node.copyWith(height: 150.0);
      expect(copy.height, 150.0);
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
      final node = BlockquoteNode(id: 'keep-me', width: 100.0);
      final copy = node.copyWith(width: 200.0);
      expect(copy.id, 'keep-me');
    });

    test('copyWith preserves text when not specified', () {
      final node = BlockquoteNode(id: 'bq1', text: AttributedText('keep me'));
      final copy = node.copyWith(id: 'bq2');
      expect(copy.text.text, 'keep me');
    });

    test('copyWith preserves width when not specified', () {
      final node = BlockquoteNode(id: 'bq1', width: 320.0);
      final copy = node.copyWith(id: 'bq2');
      expect(copy.width, 320.0);
    });

    test('copyWith preserves height when not specified', () {
      final node = BlockquoteNode(id: 'bq1', height: 240.0);
      final copy = node.copyWith(id: 'bq2');
      expect(copy.height, 240.0);
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
        width: 400.0,
        height: 100.0,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
      );
      final b = BlockquoteNode(
        id: 'bq1',
        text: AttributedText('quote'),
        width: 400.0,
        height: 100.0,
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
      final a = BlockquoteNode(id: 'bq1', width: 100.0);
      final b = BlockquoteNode(id: 'bq1', width: 200.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when height differs', () {
      final a = BlockquoteNode(id: 'bq1', height: 50.0);
      final b = BlockquoteNode(id: 'bq1', height: 100.0);
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
      final node = BlockquoteNode(id: 'bq1', width: 200.0, textWrap: TextWrapMode.wrap);
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
      final node = BlockquoteNode(id: 'bq1', width: 480.0);
      expect(node.toString(), contains('480.0'));
    });

    test('toString includes height', () {
      final node = BlockquoteNode(id: 'bq1', height: 200.0);
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
        width: 400.0,
      );
      final copy = node.copyWith(textAlign: TextAlign.justify);
      expect(copy.id, 'bq1');
      expect(copy.alignment, BlockAlignment.center);
      expect(copy.width, 400.0);
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
}
