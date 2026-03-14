/// Baseline comparison benchmarks comparing EditableDocument operations
/// vs equivalent plain Dart string operations for single-paragraph editing.
///
/// Run with: flutter run -d web benchmark/baseline_comparison_benchmark.dart
/// or: flutter pub run benchmark_harness:benchmark_harness baseline_comparison_benchmark
library baseline_comparison;

import 'benchmark_base.dart';
import 'package:editable_document/editable_document.dart';

// =============================================================================
// Benchmark 1: DocumentModel Single Paragraph Insert
// =============================================================================

/// Benchmarks creating a MutableDocument with 1 ParagraphNode and inserting
/// a character via AttributedText operations.
class DocumentModelSingleParagraphInsert extends BenchmarkBase {
  DocumentModelSingleParagraphInsert() : super('DocumentModel.insert (1 paragraph, 1 character)');

  late ParagraphNode _node;

  @override
  void setup() {
    _node = ParagraphNode(
      id: 'paragraph-1',
      text: AttributedText('The quick brown fox jumps over the lazy dog'),
    );
  }

  @override
  void run() {
    // Insert a character at position 4 of the paragraph
    final updatedText = _node.text.insert(4, AttributedText(' '));
    // Verify the text changed (without actually modifying the document)
    assert(updatedText.length == _node.text.length + 1);
  }
}

// =============================================================================
// Benchmark 2: Plain String Insert
// =============================================================================

/// Benchmarks creating a plain Dart String and inserting a character
/// using substring operations (the naive string-based approach).
class PlainStringInsert extends BenchmarkBase {
  PlainStringInsert() : super('PlainString.insert (1 character via substring)');

  late String _text;

  @override
  void setup() {
    _text = 'The quick brown fox jumps over the lazy dog';
  }

  @override
  void run() {
    // Insert a character at position 4 using substring
    final offset = 4;
    final updated = _text.substring(0, offset) + ' ' + _text.substring(offset);
    // Verify the text changed
    assert(updated.length == _text.length + 1);
  }
}

// =============================================================================
// Benchmark 3: DocumentModel Single Paragraph Selection Creation
// =============================================================================

/// Benchmarks creating a DocumentSelection from a MutableDocument
/// with a single ParagraphNode.
class DocumentModelSingleParagraphSelection extends BenchmarkBase {
  DocumentModelSingleParagraphSelection() : super('DocumentModel.selection (1 paragraph)');

  late ParagraphNode _node;

  @override
  void setup() {
    _node = ParagraphNode(
      id: 'paragraph-1',
      text: AttributedText('The quick brown fox jumps over the lazy dog'),
    );
  }

  @override
  void run() {
    // Create a selection from offset 0 to 4 in the paragraph
    final selection = DocumentSelection(
      base: DocumentPosition(
        nodeId: _node.id,
        nodePosition: const TextNodePosition(offset: 0),
      ),
      extent: DocumentPosition(
        nodeId: _node.id,
        nodePosition: const TextNodePosition(offset: 4),
      ),
    );
    // Verify the selection was created
    assert(!selection.isCollapsed);
  }
}

// =============================================================================
// Benchmark 4: Plain String Range Selection
// =============================================================================

/// Benchmarks creating a simple range selection (base, extent) for
/// a plain String using plain Dart types.
class PlainStringSelection extends BenchmarkBase {
  PlainStringSelection() : super('PlainString.selection (range: 0 to 4)');

  late String _text;

  @override
  void setup() {
    _text = 'The quick brown fox jumps over the lazy dog';
  }

  @override
  void run() {
    // Create a simple selection range and extract the selected text
    final base = 0;
    final extent = 4;
    final selected = _text.substring(base, extent);
    // Verify the selection was created
    assert(selected.isNotEmpty);
  }
}

// =============================================================================
// Benchmark 5: AttributedText Apply then Remove Attribution
// =============================================================================

/// Benchmarks applying then removing an attribution on a single paragraph
/// to measure the cost of attribution operations.
class AttributedTextApplyRemoveAttribution extends BenchmarkBase {
  AttributedTextApplyRemoveAttribution()
      : super('AttributedText.apply+remove (bold on 4-char span)');

  late AttributedText _text;

  @override
  void setup() {
    _text = AttributedText('The quick brown fox jumps over the lazy dog');
  }

  @override
  void run() {
    // Apply bold to "The " (0-3)
    var updated = _text.applyAttribution(NamedAttribution.bold, 0, 3);
    // Verify attribution was applied
    assert(updated.hasAttributionAt(2, NamedAttribution.bold));
    // Remove the bold
    updated = updated.removeAttribution(NamedAttribution.bold, 0, 3);
    // Verify attribution was removed
    assert(!updated.hasAttributionAt(2, NamedAttribution.bold));
  }
}

// =============================================================================
// Benchmark 6: DocumentImeSerializer Single Node Roundtrip
// =============================================================================

/// Benchmarks serializing a single-node document to TextEditingValue
/// (which is the core IME sync operation).
class DocumentImeSerializerSingleNode extends BenchmarkBase {
  DocumentImeSerializerSingleNode() : super('DocumentImeSerializer.toTextEditingValue (1 node)');

  late MutableDocument _document;
  late ParagraphNode _node;
  late DocumentSelection _selection;
  final _serializer = const DocumentImeSerializer();

  @override
  void setup() {
    _node = ParagraphNode(
      id: 'paragraph-1',
      text: AttributedText('The quick brown fox jumps over the lazy dog'),
    );
    _document = MutableDocument([_node]);
    _selection = const DocumentSelection(
      base: DocumentPosition(
        nodeId: 'paragraph-1',
        nodePosition: TextNodePosition(offset: 0),
      ),
      extent: DocumentPosition(
        nodeId: 'paragraph-1',
        nodePosition: TextNodePosition(offset: 4),
      ),
    );
  }

  @override
  void run() {
    // Serialize to TextEditingValue (this is what the IME sync does)
    final value = _serializer.toTextEditingValue(
      document: _document,
      selection: _selection,
    );
    // Verify the value was created
    assert(value.text.isNotEmpty);
  }
}

// =============================================================================
// Benchmark 7: Plain String Concatenation (Baseline for Insert Cost)
// =============================================================================

/// Benchmarks a very fast operation (string concatenation) to establish
/// a baseline for comparison with document model operations.
class PlainStringConcatenation extends BenchmarkBase {
  PlainStringConcatenation() : super('PlainString.concat (baseline: 2 strings)');

  @override
  void run() {
    // Very simple operation: just concatenate two strings
    final result = 'The ' + 'quick';
    assert(result.isNotEmpty);
  }
}

// =============================================================================
// Main
// =============================================================================

void main() {
  // Document Model Benchmarks
  DocumentModelSingleParagraphInsert().report();
  DocumentModelSingleParagraphSelection().report();
  AttributedTextApplyRemoveAttribution().report();
  DocumentImeSerializerSingleNode().report();

  // Plain String Benchmarks (for comparison)
  PlainStringInsert().report();
  PlainStringSelection().report();
  PlainStringConcatenation().report();
}
