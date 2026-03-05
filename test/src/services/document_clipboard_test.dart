/// Tests for [DocumentClipboard] — plain-text clipboard operations.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Sets up a mock [SystemChannels.platform] handler that simulates the
/// system clipboard. Returns a teardown callback that restores the original
/// handler.
String? _clipboardData;

void _installClipboardMock(TestWidgetsFlutterBinding binding) {
  _clipboardData = null;
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        _clipboardData = (call.arguments as Map<String, dynamic>)['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        if (_clipboardData == null) return null;
        return <String, dynamic>{'text': _clipboardData};
      }
      return null;
    },
  );
}

void _removeClipboardMock(TestWidgetsFlutterBinding binding) {
  binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
  _clipboardData = null;
}

/// Builds a two-paragraph document with stable node ids.
Document _twoParagraphDoc() => Document([
      ParagraphNode(id: 'p1', text: AttributedText('Hello world')),
      ParagraphNode(id: 'p2', text: AttributedText('Second paragraph')),
    ]);

/// Builds a three-node document: two text nodes with a binary node in between.
Document _textBinaryTextDoc() => Document([
      ParagraphNode(id: 'p1', text: AttributedText('Alpha')),
      HorizontalRuleNode(id: 'hr'),
      ParagraphNode(id: 'p2', text: AttributedText('Beta')),
    ]);

void main() {
  late DocumentClipboard clipboard;

  setUp(() {
    clipboard = const DocumentClipboard();
  });

  // -------------------------------------------------------------------------
  // extractPlainText
  // -------------------------------------------------------------------------

  group('DocumentClipboard.extractPlainText', () {
    test('returns empty string for a collapsed selection', () {
      final doc = _twoParagraphDoc();
      const selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );

      expect(clipboard.extractPlainText(doc, selection), equals(''));
    });

    test('single text node — partial selection returns substring', () {
      final doc = _twoParagraphDoc();
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );

      // 'Hello world'[0..5) → 'Hello'
      expect(clipboard.extractPlainText(doc, selection), equals('Hello'));
    });

    test('single text node — full selection returns full text', () {
      final doc = _twoParagraphDoc();
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 11),
        ),
      );

      expect(clipboard.extractPlainText(doc, selection), equals('Hello world'));
    });

    test('single text node — mid-node start/end boundaries', () {
      final doc = _twoParagraphDoc();
      // 'Hello world'[6..11) → 'world'
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 6),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 11),
        ),
      );

      expect(clipboard.extractPlainText(doc, selection), equals('world'));
    });

    test('multi-node — two text nodes joined with newline', () {
      final doc = _twoParagraphDoc();
      // base at p1 offset 6, extent at p2 offset 6
      // p1 tail: 'world'; p2 head: 'Second'
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 6),
        ),
        extent: DocumentPosition(
          nodeId: 'p2',
          nodePosition: TextNodePosition(offset: 6),
        ),
      );

      expect(clipboard.extractPlainText(doc, selection), equals('world\nSecond'));
    });

    test('multi-node — full first node, partial last node', () {
      final doc = _twoParagraphDoc();
      // base at p1 offset 0, extent at p2 offset 4
      // p1 full text + '\n' + p2[0..4)
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p2',
          nodePosition: TextNodePosition(offset: 4),
        ),
      );

      // 'Hello world' + '\n' + 'Seco'
      expect(clipboard.extractPlainText(doc, selection), equals('Hello world\nSeco'));
    });

    test('multi-node — binary node in the middle contributes newline', () {
      final doc = _textBinaryTextDoc();
      // Select from p1 offset 2 across hr to p2 offset 3
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 2),
        ),
        extent: DocumentPosition(
          nodeId: 'p2',
          nodePosition: TextNodePosition(offset: 3),
        ),
      );

      // p1 tail: 'Alpha'[2..5) = 'pha'
      // hr (binary middle): '\n'
      // p2 head: 'Beta'[0..3) = 'Bet'
      expect(clipboard.extractPlainText(doc, selection), equals('pha\n\nBet'));
    });

    test('multi-node — upstream selection is normalised before extraction', () {
      final doc = _twoParagraphDoc();
      // extent BEFORE base in document order — should normalise
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p2',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 6),
        ),
      );

      // After normalise: base=p1@6, extent=p2@0
      // p1 tail: 'Hello world'[6..11) = 'world'
      // p2 head: 'Second paragraph'[0..0) = ''
      expect(clipboard.extractPlainText(doc, selection), equals('world\n'));
    });

    test('multi-node — binary first node contributes empty prefix', () {
      // Document: hr → p1
      final doc = Document([
        HorizontalRuleNode(id: 'hr'),
        ParagraphNode(id: 'p1', text: AttributedText('Text')),
      ]);
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'hr',
          nodePosition: BinaryNodePosition.upstream(),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 4),
        ),
      );

      // hr (first, binary): '' joined with '\n' + p2 full
      expect(clipboard.extractPlainText(doc, selection), equals('\nText'));
    });

    test('multi-node — binary last node contributes empty suffix', () {
      // Document: p1 → hr
      final doc = Document([
        ParagraphNode(id: 'p1', text: AttributedText('Text')),
        HorizontalRuleNode(id: 'hr'),
      ]);
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'hr',
          nodePosition: BinaryNodePosition.downstream(),
        ),
      );

      // p1 full + '\n' + hr (last, binary): ''
      expect(clipboard.extractPlainText(doc, selection), equals('Text\n'));
    });

    test('single binary node selection returns empty string', () {
      final doc = Document([HorizontalRuleNode(id: 'hr')]);
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'hr',
          nodePosition: BinaryNodePosition.upstream(),
        ),
        extent: DocumentPosition(
          nodeId: 'hr',
          nodePosition: BinaryNodePosition.downstream(),
        ),
      );

      expect(clipboard.extractPlainText(doc, selection), equals('\n'));
    });
  });

  // -------------------------------------------------------------------------
  // copy
  // -------------------------------------------------------------------------

  group('DocumentClipboard.copy', () {
    late TestWidgetsFlutterBinding binding;

    setUp(() {
      binding = TestWidgetsFlutterBinding.ensureInitialized();
      _installClipboardMock(binding);
    });

    tearDown(() {
      _removeClipboardMock(binding);
    });

    test('collapsed selection is a no-op — clipboard is not written', () async {
      final doc = _twoParagraphDoc();
      const selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
      );

      final result = await clipboard.copy(doc, selection);

      expect(result, equals(''));
      expect(_clipboardData, isNull);
    });

    test('expanded selection writes extracted text to clipboard', () async {
      final doc = _twoParagraphDoc();
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );

      final result = await clipboard.copy(doc, selection);

      expect(result, equals('Hello'));
      expect(_clipboardData, equals('Hello'));
    });

    test('copy returns the same text as extractPlainText', () async {
      final doc = _twoParagraphDoc();
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 6),
        ),
        extent: DocumentPosition(
          nodeId: 'p2',
          nodePosition: TextNodePosition(offset: 6),
        ),
      );

      final extracted = clipboard.extractPlainText(doc, selection);
      final copied = await clipboard.copy(doc, selection);

      expect(copied, equals(extracted));
      expect(_clipboardData, equals(extracted));
    });
  });

  // -------------------------------------------------------------------------
  // cut
  // -------------------------------------------------------------------------

  group('DocumentClipboard.cut', () {
    late TestWidgetsFlutterBinding binding;

    setUp(() {
      binding = TestWidgetsFlutterBinding.ensureInitialized();
      _installClipboardMock(binding);
    });

    tearDown(() {
      _removeClipboardMock(binding);
    });

    test('collapsed selection returns null — no clipboard write', () async {
      final doc = _twoParagraphDoc();
      const selection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 2),
        ),
      );

      final request = await clipboard.cut(doc, selection);

      expect(request, isNull);
      expect(_clipboardData, isNull);
    });

    test('expanded selection writes to clipboard and returns DeleteContentRequest', () async {
      final doc = _twoParagraphDoc();
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );

      final request = await clipboard.cut(doc, selection);

      expect(_clipboardData, equals('Hello'));
      expect(request, isNotNull);
      expect(request, isA<DeleteContentRequest>());
      expect(
        (request!).selection,
        equals(selection),
      );
    });

    test('cut request carries the original selection unchanged', () async {
      final doc = _twoParagraphDoc();
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p2',
          nodePosition: TextNodePosition(offset: 6),
        ),
      );

      final request = await clipboard.cut(doc, selection);

      expect(request, isNotNull);
      expect((request!).selection, equals(selection));
    });
  });

  // -------------------------------------------------------------------------
  // paste
  // -------------------------------------------------------------------------

  group('DocumentClipboard.paste', () {
    late TestWidgetsFlutterBinding binding;

    setUp(() {
      binding = TestWidgetsFlutterBinding.ensureInitialized();
      _installClipboardMock(binding);
    });

    tearDown(() {
      _removeClipboardMock(binding);
    });

    test('empty clipboard returns null', () async {
      _clipboardData = null;

      final request = await clipboard.paste('p1', 0);

      expect(request, isNull);
    });

    test('clipboard with text returns InsertTextRequest at given node and offset', () async {
      _clipboardData = 'pasted text';

      final request = await clipboard.paste('p1', 3);

      expect(request, isNotNull);
      expect(request, isA<InsertTextRequest>());
      final insert = request!;
      expect(insert.nodeId, equals('p1'));
      expect(insert.offset, equals(3));
      expect(insert.text.text, equals('pasted text'));
    });

    test('clipboard with empty string returns null', () async {
      _clipboardData = '';

      final request = await clipboard.paste('p1', 0);

      expect(request, isNull);
    });

    test('paste at offset 0 prepends the text', () async {
      _clipboardData = 'prefix ';

      final request = await clipboard.paste('p1', 0);

      expect(request, isNotNull);
      final insert = request!;
      expect(insert.nodeId, equals('p1'));
      expect(insert.offset, equals(0));
      expect(insert.text.text, equals('prefix '));
    });

    test('copy then paste produces round-trip InsertTextRequest', () async {
      final doc = _twoParagraphDoc();
      const selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: 'p1',
          nodePosition: TextNodePosition(offset: 5),
        ),
      );

      await clipboard.copy(doc, selection);
      final request = await clipboard.paste('p2', 7);

      expect(request, isNotNull);
      final insert = request!;
      expect(insert.nodeId, equals('p2'));
      expect(insert.offset, equals(7));
      expect(insert.text.text, equals('Hello'));
    });
  });
}
