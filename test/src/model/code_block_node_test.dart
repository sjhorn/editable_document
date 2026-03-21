/// Tests for [CodeBlockNode] — covering all fields including [lineHeight].
///
/// These tests cover the constructor, [copyWith], equality, hashCode,
/// [debugFillProperties], and toString.
library;

import 'package:editable_document/src/model/attributed_text.dart';
import 'package:editable_document/src/model/block_alignment.dart';
import 'package:editable_document/src/model/block_border.dart';
import 'package:editable_document/src/model/code_block_node.dart';
import 'package:editable_document/src/model/text_node.dart';
import 'package:editable_document/src/model/text_wrap_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // CodeBlockNode — default values
  // ---------------------------------------------------------------------------
  group('CodeBlockNode default values', () {
    test('language defaults to null', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node.language, isNull);
    });

    test('width defaults to null', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node.width, isNull);
    });

    test('height defaults to null', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node.height, isNull);
    });

    test('alignment defaults to BlockAlignment.stretch', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node.alignment, BlockAlignment.stretch);
    });

    test('textWrap defaults to TextWrapMode.none', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node.textWrap, TextWrapMode.none);
    });

    test('lineHeight defaults to null', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node.lineHeight, isNull);
    });

    test('text defaults to empty AttributedText', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node.text.text, '');
      expect(node.text.length, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — constructor with custom values
  // ---------------------------------------------------------------------------
  group('CodeBlockNode constructor with custom values', () {
    test('id is set correctly', () {
      final node = CodeBlockNode(id: 'my-cb-id');
      expect(node.id, 'my-cb-id');
    });

    test('language is set correctly', () {
      final node = CodeBlockNode(id: 'cb1', language: 'dart');
      expect(node.language, 'dart');
    });

    test('text is set from AttributedText', () {
      final text = AttributedText('void main() {}');
      final node = CodeBlockNode(id: 'cb1', text: text);
      expect(node.text.text, 'void main() {}');
    });

    test('width is set correctly', () {
      final node = CodeBlockNode(id: 'cb1', width: 640.0);
      expect(node.width, 640.0);
    });

    test('height is set correctly', () {
      final node = CodeBlockNode(id: 'cb1', height: 200.0);
      expect(node.height, 200.0);
    });

    test('alignment is set correctly', () {
      final node = CodeBlockNode(id: 'cb1', alignment: BlockAlignment.center);
      expect(node.alignment, BlockAlignment.center);
    });

    test('textWrap is set correctly', () {
      final node = CodeBlockNode(id: 'cb1', textWrap: TextWrapMode.wrap);
      expect(node.textWrap, TextWrapMode.wrap);
    });

    test('lineHeight is set correctly to 1.5', () {
      final node = CodeBlockNode(id: 'cb1', lineHeight: 1.5);
      expect(node.lineHeight, 1.5);
    });

    test('lineHeight is set correctly to 2.0', () {
      final node = CodeBlockNode(id: 'cb1', lineHeight: 2.0);
      expect(node.lineHeight, 2.0);
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — copyWith round-trips
  // ---------------------------------------------------------------------------
  group('CodeBlockNode copyWith', () {
    test('copyWith replaces id', () {
      final node = CodeBlockNode(id: 'cb1');
      final copy = node.copyWith(id: 'cb2');
      expect(copy.id, 'cb2');
    });

    test('copyWith replaces language', () {
      final node = CodeBlockNode(id: 'cb1', language: 'dart');
      final copy = node.copyWith(language: 'python');
      expect(copy.language, 'python');
    });

    test('copyWith replaces text', () {
      final node = CodeBlockNode(id: 'cb1', text: AttributedText('original'));
      final copy = node.copyWith(text: AttributedText('replaced'));
      expect(copy.text.text, 'replaced');
    });

    test('copyWith replaces width', () {
      final node = CodeBlockNode(id: 'cb1', width: 100.0);
      final copy = node.copyWith(width: 200.0);
      expect(copy.width, 200.0);
    });

    test('copyWith replaces height', () {
      final node = CodeBlockNode(id: 'cb1', height: 50.0);
      final copy = node.copyWith(height: 150.0);
      expect(copy.height, 150.0);
    });

    test('copyWith replaces alignment', () {
      final node = CodeBlockNode(id: 'cb1', alignment: BlockAlignment.start);
      final copy = node.copyWith(alignment: BlockAlignment.end);
      expect(copy.alignment, BlockAlignment.end);
    });

    test('copyWith replaces textWrap', () {
      final node = CodeBlockNode(id: 'cb1', textWrap: TextWrapMode.none);
      final copy = node.copyWith(textWrap: TextWrapMode.wrap);
      expect(copy.textWrap, TextWrapMode.wrap);
    });

    test('copyWith replaces lineHeight', () {
      final node = CodeBlockNode(id: 'cb1', lineHeight: 1.5);
      final copy = node.copyWith(lineHeight: 2.0);
      expect(copy.lineHeight, 2.0);
    });

    test('copyWith preserves lineHeight when not specified', () {
      final node = CodeBlockNode(id: 'cb1', lineHeight: 1.8);
      final copy = node.copyWith(id: 'cb2');
      expect(copy.lineHeight, 1.8);
    });

    test('copyWith preserves other fields when only lineHeight changes', () {
      final node = CodeBlockNode(
        id: 'cb1',
        language: 'dart',
        width: 400.0,
        alignment: BlockAlignment.center,
        lineHeight: 1.0,
      );
      final copy = node.copyWith(lineHeight: 1.5);
      expect(copy.id, 'cb1');
      expect(copy.language, 'dart');
      expect(copy.width, 400.0);
      expect(copy.alignment, BlockAlignment.center);
      expect(copy.lineHeight, 1.5);
    });

    test('copyWith preserves id when not specified', () {
      final node = CodeBlockNode(id: 'keep-me', width: 100.0);
      final copy = node.copyWith(width: 200.0);
      expect(copy.id, 'keep-me');
    });

    test('copyWith replaces metadata', () {
      final node = CodeBlockNode(id: 'cb1');
      final copy = node.copyWith(metadata: {'highlighted': true});
      expect(copy.metadata['highlighted'], true);
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — equality
  // ---------------------------------------------------------------------------
  group('CodeBlockNode equality', () {
    test('equal when all fields are the same', () {
      final a = CodeBlockNode(
        id: 'cb1',
        language: 'dart',
        width: 640.0,
        height: 200.0,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
        lineHeight: 1.5,
      );
      final b = CodeBlockNode(
        id: 'cb1',
        language: 'dart',
        width: 640.0,
        height: 200.0,
        alignment: BlockAlignment.center,
        textWrap: TextWrapMode.wrap,
        lineHeight: 1.5,
      );
      expect(a, equals(b));
    });

    test('unequal when lineHeight differs', () {
      final a = CodeBlockNode(id: 'cb1', lineHeight: 1.5);
      final b = CodeBlockNode(id: 'cb1', lineHeight: 2.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when one lineHeight is null and other is not', () {
      final a = CodeBlockNode(id: 'cb1');
      final b = CodeBlockNode(id: 'cb1', lineHeight: 1.5);
      expect(a, isNot(equals(b)));
    });

    test('equal when lineHeight is both null', () {
      final a = CodeBlockNode(id: 'cb1');
      final b = CodeBlockNode(id: 'cb1');
      expect(a, equals(b));
    });

    test('unequal when id differs', () {
      final a = CodeBlockNode(id: 'cb1');
      final b = CodeBlockNode(id: 'cb2');
      expect(a, isNot(equals(b)));
    });

    test('unequal when language differs', () {
      final a = CodeBlockNode(id: 'cb1', language: 'dart');
      final b = CodeBlockNode(id: 'cb1', language: 'python');
      expect(a, isNot(equals(b)));
    });

    test('identical instance equals itself', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node, equals(node));
    });

    test('not equal to a different runtimeType', () {
      final cb = CodeBlockNode(id: 'cb1', text: AttributedText('code'));
      final tn = TextNode(id: 'cb1', text: AttributedText('code'));
      expect(cb, isNot(equals(tn)));
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — hashCode
  // ---------------------------------------------------------------------------
  group('CodeBlockNode hashCode', () {
    test('hashCode matches for equal nodes', () {
      final a = CodeBlockNode(id: 'cb1', lineHeight: 1.5);
      final b = CodeBlockNode(id: 'cb1', lineHeight: 1.5);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode is consistent on same instance', () {
      final node = CodeBlockNode(id: 'cb1', width: 200.0, lineHeight: 1.5);
      expect(node.hashCode, node.hashCode);
    });

    test('hashCode differs when lineHeight differs', () {
      final a = CodeBlockNode(id: 'cb1', lineHeight: 1.5);
      final b = CodeBlockNode(id: 'cb1', lineHeight: 2.0);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — toString
  // ---------------------------------------------------------------------------
  group('CodeBlockNode toString', () {
    test('toString includes id', () {
      final node = CodeBlockNode(id: 'cb-unique');
      expect(node.toString(), contains('cb-unique'));
    });

    test('toString includes language', () {
      final node = CodeBlockNode(id: 'cb1', language: 'dart');
      expect(node.toString(), contains('dart'));
    });

    test('toString includes width', () {
      final node = CodeBlockNode(id: 'cb1', width: 640.0);
      expect(node.toString(), contains('640.0'));
    });

    test('toString includes lineHeight when set', () {
      final node = CodeBlockNode(id: 'cb1', lineHeight: 1.5);
      expect(node.toString(), contains('1.5'));
    });

    test('toString mentions CodeBlockNode type', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node.toString(), contains('CodeBlockNode'));
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — debugFillProperties includes lineHeight
  // ---------------------------------------------------------------------------
  group('CodeBlockNode debugFillProperties with lineHeight', () {
    test('debugFillProperties includes lineHeight when non-null', () {
      final node = CodeBlockNode(id: 'cb1', lineHeight: 1.5);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'lineHeight',
            orElse: () => throw StateError('lineHeight property not found'),
          );
      expect(prop.value, 1.5);
    });

    test('debugFillProperties lineHeight is absent (default null) when not set', () {
      final node = CodeBlockNode(id: 'cb1');
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
  // CodeBlockNode — is-a TextNode
  // ---------------------------------------------------------------------------
  group('CodeBlockNode is-a TextNode', () {
    test('CodeBlockNode is a TextNode', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node, isA<TextNode>());
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — border default value
  // ---------------------------------------------------------------------------
  group('CodeBlockNode border default', () {
    test('border defaults to null', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node.border, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — constructor with border
  // ---------------------------------------------------------------------------
  group('CodeBlockNode constructor with border', () {
    test('border is set correctly', () {
      const border = BlockBorder(style: BlockBorderStyle.solid, width: 2.0);
      final node = CodeBlockNode(id: 'cb1', border: border);
      expect(node.border, border);
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — copyWith with border
  // ---------------------------------------------------------------------------
  group('CodeBlockNode copyWith border', () {
    test('copyWith replaces border', () {
      const original = BlockBorder(style: BlockBorderStyle.solid, width: 1.0);
      const replacement = BlockBorder(style: BlockBorderStyle.dashed, width: 2.0);
      final node = CodeBlockNode(id: 'cb1', border: original);
      final copy = node.copyWith(border: replacement);
      expect(copy.border, replacement);
    });

    test('copyWith preserves border when not specified', () {
      const border = BlockBorder(style: BlockBorderStyle.dotted, width: 3.0);
      final node = CodeBlockNode(id: 'cb1', border: border);
      final copy = node.copyWith(id: 'cb2');
      expect(copy.border, border);
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — equality with border
  // ---------------------------------------------------------------------------
  group('CodeBlockNode equality with border', () {
    test('equal when border is both null', () {
      final a = CodeBlockNode(id: 'cb1');
      final b = CodeBlockNode(id: 'cb1');
      expect(a, equals(b));
    });

    test('equal when border matches', () {
      const border = BlockBorder(style: BlockBorderStyle.solid, width: 2.0);
      final a = CodeBlockNode(id: 'cb1', border: border);
      final b = CodeBlockNode(id: 'cb1', border: border);
      expect(a, equals(b));
    });

    test('unequal when border differs', () {
      final a = CodeBlockNode(id: 'cb1', border: const BlockBorder(width: 1.0));
      final b = CodeBlockNode(id: 'cb1', border: const BlockBorder(width: 2.0));
      expect(a, isNot(equals(b)));
    });

    test('unequal when one border is null and other is not', () {
      final a = CodeBlockNode(id: 'cb1');
      final b = CodeBlockNode(id: 'cb1', border: const BlockBorder());
      expect(a, isNot(equals(b)));
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — spaceBefore default value
  // ---------------------------------------------------------------------------
  group('CodeBlockNode spaceBefore default', () {
    test('spaceBefore defaults to null', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node.spaceBefore, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — spaceAfter default value
  // ---------------------------------------------------------------------------
  group('CodeBlockNode spaceAfter default', () {
    test('spaceAfter defaults to null', () {
      final node = CodeBlockNode(id: 'cb1');
      expect(node.spaceAfter, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — constructor with spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('CodeBlockNode constructor with spaceBefore/spaceAfter', () {
    test('spaceBefore is set correctly', () {
      final node = CodeBlockNode(id: 'cb1', spaceBefore: 8.0);
      expect(node.spaceBefore, 8.0);
    });

    test('spaceAfter is set correctly', () {
      final node = CodeBlockNode(id: 'cb1', spaceAfter: 16.0);
      expect(node.spaceAfter, 16.0);
    });

    test('both spaceBefore and spaceAfter can be set together', () {
      final node = CodeBlockNode(id: 'cb1', spaceBefore: 4.0, spaceAfter: 12.0);
      expect(node.spaceBefore, 4.0);
      expect(node.spaceAfter, 12.0);
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — copyWith with spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('CodeBlockNode copyWith spaceBefore/spaceAfter', () {
    test('copyWith replaces spaceBefore', () {
      final node = CodeBlockNode(id: 'cb1', spaceBefore: 8.0);
      final copy = node.copyWith(spaceBefore: 16.0);
      expect(copy.spaceBefore, 16.0);
    });

    test('copyWith preserves spaceBefore when not specified', () {
      final node = CodeBlockNode(id: 'cb1', spaceBefore: 8.0);
      final copy = node.copyWith(id: 'cb2');
      expect(copy.spaceBefore, 8.0);
    });

    test('copyWith replaces spaceAfter', () {
      final node = CodeBlockNode(id: 'cb1', spaceAfter: 12.0);
      final copy = node.copyWith(spaceAfter: 24.0);
      expect(copy.spaceAfter, 24.0);
    });

    test('copyWith preserves spaceAfter when not specified', () {
      final node = CodeBlockNode(id: 'cb1', spaceAfter: 12.0);
      final copy = node.copyWith(id: 'cb2');
      expect(copy.spaceAfter, 12.0);
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — equality with spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('CodeBlockNode equality with spaceBefore/spaceAfter', () {
    test('unequal when spaceBefore differs', () {
      final a = CodeBlockNode(id: 'cb1', spaceBefore: 8.0);
      final b = CodeBlockNode(id: 'cb1', spaceBefore: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('unequal when spaceAfter differs', () {
      final a = CodeBlockNode(id: 'cb1', spaceAfter: 8.0);
      final b = CodeBlockNode(id: 'cb1', spaceAfter: 16.0);
      expect(a, isNot(equals(b)));
    });

    test('equal when spaceBefore and spaceAfter are both null', () {
      final a = CodeBlockNode(id: 'cb1');
      final b = CodeBlockNode(id: 'cb1');
      expect(a, equals(b));
    });

    test('equal when spaceBefore and spaceAfter match', () {
      final a = CodeBlockNode(id: 'cb1', spaceBefore: 4.0, spaceAfter: 8.0);
      final b = CodeBlockNode(id: 'cb1', spaceBefore: 4.0, spaceAfter: 8.0);
      expect(a, equals(b));
    });
  });

  // ---------------------------------------------------------------------------
  // CodeBlockNode — debugFillProperties includes spaceBefore / spaceAfter
  // ---------------------------------------------------------------------------
  group('CodeBlockNode debugFillProperties with spaceBefore/spaceAfter', () {
    test('debugFillProperties includes spaceBefore when non-null', () {
      final node = CodeBlockNode(id: 'cb1', spaceBefore: 8.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'spaceBefore',
            orElse: () => throw StateError('spaceBefore property not found'),
          );
      expect(prop.value, 8.0);
    });

    test('debugFillProperties includes spaceAfter when non-null', () {
      final node = CodeBlockNode(id: 'cb1', spaceAfter: 16.0);
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final prop = builder.properties.whereType<DoubleProperty>().firstWhere(
            (p) => p.name == 'spaceAfter',
            orElse: () => throw StateError('spaceAfter property not found'),
          );
      expect(prop.value, 16.0);
    });

    test('debugFillProperties spaceBefore value is null when not set', () {
      final node = CodeBlockNode(id: 'cb1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'spaceBefore');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });

    test('debugFillProperties spaceAfter value is null when not set', () {
      final node = CodeBlockNode(id: 'cb1');
      final builder = DiagnosticPropertiesBuilder();
      node.debugFillProperties(builder);
      final props =
          builder.properties.whereType<DoubleProperty>().where((p) => p.name == 'spaceAfter');
      for (final p in props) {
        expect(p.value, isNull);
      }
    });
  });
}
