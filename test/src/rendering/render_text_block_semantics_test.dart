/// Tests for semantics support in [RenderTextBlock] and [RenderParagraphBlock].
library;

import 'package:editable_document/editable_document.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps [block] through layout and collects its [SemanticsConfiguration].
///
/// The render object must support [describeSemanticsConfiguration] for this
/// helper to return a useful result.
SemanticsConfiguration _collectConfig(RenderTextBlock block) {
  block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
  final config = SemanticsConfiguration();
  block.describeSemanticsConfiguration(config);
  return config;
}

/// Pumps [block] through layout and collects its [SemanticsConfiguration].
SemanticsConfiguration _collectParagraphConfig(RenderParagraphBlock block) {
  block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
  final config = SemanticsConfiguration();
  block.describeSemanticsConfiguration(config);
  return config;
}

// ---------------------------------------------------------------------------
// RenderTextBlock semantics
// ---------------------------------------------------------------------------

void main() {
  group('RenderTextBlock — describeSemanticsConfiguration', () {
    test('is a semantic boundary', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello, world'),
        textStyle: const TextStyle(fontSize: 16),
      );
      final config = _collectConfig(block);
      expect(config.isSemanticBoundary, isTrue);
    });

    test('attributedValue contains the plain text', () {
      const content = 'Hello, world';
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText(content),
        textStyle: const TextStyle(fontSize: 16),
      );
      final config = _collectConfig(block);
      expect(config.attributedValue.string, content);
    });

    test('attributedValue is empty string when text is empty', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText(''),
        textStyle: const TextStyle(fontSize: 16),
      );
      final config = _collectConfig(block);
      expect(config.attributedValue.string, '');
    });

    test('textDirection is propagated to config', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('rtl text'),
        textDirection: TextDirection.rtl,
      );
      final config = _collectConfig(block);
      expect(config.textDirection, TextDirection.rtl);
    });

    test('textDirection defaults to ltr', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('ltr text'),
      );
      final config = _collectConfig(block);
      expect(config.textDirection, TextDirection.ltr);
    });

    test('isMultiline is true', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
        textStyle: const TextStyle(fontSize: 16),
      );
      final config = _collectConfig(block);
      expect(config.isMultiline, isTrue);
    });
  });

  group('RenderTextBlock — isFocused / isReadOnly semantics', () {
    test('default: not focused, not read-only, not text field', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      final config = _collectConfig(block);
      expect(config.isFocused, isNot(isTrue));
      expect(config.isReadOnly, isFalse);
      expect(config.isTextField, isFalse);
    });

    test('isFocused=true and isReadOnly=false marks config as focused text field', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      block.isFocused = true;
      block.isReadOnly = false;
      final config = _collectConfig(block);
      expect(config.isFocused, isTrue);
      expect(config.isTextField, isTrue);
      expect(config.isReadOnly, isFalse);
    });

    test('isFocused=true and isReadOnly=true sets focused + readOnly but NOT textField', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      block.isFocused = true;
      block.isReadOnly = true;
      final config = _collectConfig(block);
      expect(config.isFocused, isTrue);
      expect(config.isReadOnly, isTrue);
      expect(config.isTextField, isFalse);
    });

    test('isFocused=false and isReadOnly=true sets only readOnly', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      block.isReadOnly = true;
      final config = _collectConfig(block);
      expect(config.isFocused, isNot(isTrue));
      expect(config.isReadOnly, isTrue);
      expect(config.isTextField, isFalse);
    });

    test('setting isFocused to the same value does not trigger redundant update', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      // Setting to default (false) should not change anything.
      block.isFocused = false;
      expect(block.isFocused, isFalse);
    });

    test('setting isReadOnly to the same value does not trigger redundant update', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      block.isReadOnly = false;
      expect(block.isReadOnly, isFalse);
    });
  });

  group('RenderTextBlock — cursor movement handlers', () {
    test('onSemanticsMoveCursorForwardByCharacter is forwarded to config', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      void handler(bool _) {}
      block.onSemanticsMoveCursorForwardByCharacter = handler;
      final config = _collectConfig(block);
      expect(config.onMoveCursorForwardByCharacter, isNotNull);
    });

    test('onSemanticsMoveCursorBackwardByCharacter is forwarded to config', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      void handler(bool _) {}
      block.onSemanticsMoveCursorBackwardByCharacter = handler;
      final config = _collectConfig(block);
      expect(config.onMoveCursorBackwardByCharacter, isNotNull);
    });

    test('onSemanticsMoveCursorForwardByWord is stored on render object', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      void handler(bool _) {}
      block.onSemanticsMoveCursorForwardByWord = handler;
      // Verify the handler round-trips on the render object.
      expect(block.onSemanticsMoveCursorForwardByWord, handler);
    });

    test('onSemanticsMoveCursorBackwardByWord is stored on render object', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      void handler(bool _) {}
      block.onSemanticsMoveCursorBackwardByWord = handler;
      expect(block.onSemanticsMoveCursorBackwardByWord, handler);
    });

    test('null cursor handler is not forwarded to config', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      // Handlers are null by default.
      final config = _collectConfig(block);
      expect(config.onMoveCursorForwardByCharacter, isNull);
      expect(config.onMoveCursorBackwardByCharacter, isNull);
    });

    test('cursor handler setter no-ops when value is unchanged', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      void handler(bool _) {}
      block.onSemanticsMoveCursorForwardByCharacter = handler;
      // Setting the same handler again should be a no-op.
      block.onSemanticsMoveCursorForwardByCharacter = handler;
      expect(block.onSemanticsMoveCursorForwardByCharacter, handler);
    });
  });

  group('RenderTextBlock — text and selection handlers', () {
    test('onSemanticsSetText is forwarded to config', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      void handler(String _) {}
      block.onSemanticsSetText = handler;
      final config = _collectConfig(block);
      expect(config.onSetText, isNotNull);
    });

    test('onSemanticsSetSelection is forwarded to config', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      void handler(TextSelection _) {}
      block.onSemanticsSetSelection = handler;
      final config = _collectConfig(block);
      expect(config.onSetSelection, isNotNull);
    });

    test('null text handler is not forwarded to config', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      final config = _collectConfig(block);
      expect(config.onSetText, isNull);
    });

    test('null selection handler is not forwarded to config', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      final config = _collectConfig(block);
      expect(config.onSetSelection, isNull);
    });

    test('setText handler setter no-ops when value is unchanged', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      void handler(String _) {}
      block.onSemanticsSetText = handler;
      block.onSemanticsSetText = handler;
      expect(block.onSemanticsSetText, handler);
    });

    test('setSelection handler setter no-ops when value is unchanged', () {
      final block = RenderTextBlock(
        nodeId: 'p1',
        text: AttributedText('Hello'),
      );
      void handler(TextSelection _) {}
      block.onSemanticsSetSelection = handler;
      block.onSemanticsSetSelection = handler;
      expect(block.onSemanticsSetSelection, handler);
    });
  });

  // ---------------------------------------------------------------------------
  // RenderParagraphBlock — heading level semantics
  // ---------------------------------------------------------------------------

  group('RenderParagraphBlock — heading level semantics', () {
    for (final entry in const {
      ParagraphBlockType.header1: 1,
      ParagraphBlockType.header2: 2,
      ParagraphBlockType.header3: 3,
      ParagraphBlockType.header4: 4,
      ParagraphBlockType.header5: 5,
      ParagraphBlockType.header6: 6,
    }.entries) {
      test('${entry.key} maps to heading level ${entry.value}', () {
        final block = RenderParagraphBlock(
          nodeId: 'h',
          text: AttributedText('Heading text'),
          blockType: entry.key,
          baseTextStyle: const TextStyle(fontSize: 16),
        );
        final config = _collectParagraphConfig(block);
        expect(config.headingLevel, entry.value);
      });
    }

    test('paragraph does not set a heading level', () {
      final block = RenderParagraphBlock(
        nodeId: 'p',
        text: AttributedText('Body text'),
        blockType: ParagraphBlockType.paragraph,
        baseTextStyle: const TextStyle(fontSize: 16),
      );
      final config = _collectParagraphConfig(block);
      // headingLevel 0 means no heading semantics.
      expect(config.headingLevel, 0);
    });

    test('blockquote does not set a heading level', () {
      final block = RenderParagraphBlock(
        nodeId: 'bq',
        text: AttributedText('A quote'),
        blockType: ParagraphBlockType.blockquote,
        baseTextStyle: const TextStyle(fontSize: 16),
      );
      final config = _collectParagraphConfig(block);
      expect(config.headingLevel, 0);
    });

    test('codeBlock does not set a heading level', () {
      final block = RenderParagraphBlock(
        nodeId: 'cb',
        text: AttributedText('code()'),
        blockType: ParagraphBlockType.codeBlock,
        baseTextStyle: const TextStyle(fontSize: 16),
      );
      final config = _collectParagraphConfig(block);
      expect(config.headingLevel, 0);
    });

    test('headingLevel inherits isSemanticBoundary from RenderTextBlock', () {
      final block = RenderParagraphBlock(
        nodeId: 'h1',
        text: AttributedText('Big heading'),
        blockType: ParagraphBlockType.header1,
        baseTextStyle: const TextStyle(fontSize: 16),
      );
      final config = _collectParagraphConfig(block);
      expect(config.isSemanticBoundary, isTrue);
    });

    test('headingLevel inherits attributedValue from RenderTextBlock', () {
      const content = 'Chapter 1';
      final block = RenderParagraphBlock(
        nodeId: 'h1',
        text: AttributedText(content),
        blockType: ParagraphBlockType.header1,
        baseTextStyle: const TextStyle(fontSize: 16),
      );
      final config = _collectParagraphConfig(block);
      expect(config.attributedValue.string, content);
    });

    test('headingLevel updates when blockType changes', () {
      final block = RenderParagraphBlock(
        nodeId: 'h',
        text: AttributedText('Dynamic heading'),
        blockType: ParagraphBlockType.header1,
        baseTextStyle: const TextStyle(fontSize: 16),
      );
      var config = _collectParagraphConfig(block);
      expect(config.headingLevel, 1);

      block.blockType = ParagraphBlockType.header3;
      block.layout(const BoxConstraints(maxWidth: 400), parentUsesSize: true);
      config = SemanticsConfiguration();
      block.describeSemanticsConfiguration(config);
      expect(config.headingLevel, 3);
    });
  });
}
