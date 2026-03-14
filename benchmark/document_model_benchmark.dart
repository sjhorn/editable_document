/// Micro-benchmarks for document model operations.
///
/// Benchmarks core [MutableDocument] and [AttributedText] operations
/// to measure performance of document structure and text attribution.
///
/// Run with:
/// ```bash
/// dart run benchmark/document_model_benchmark.dart
/// ```

import 'benchmark_base.dart';
import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// InsertNode benchmarks
// ---------------------------------------------------------------------------

/// Benchmark: Insert a node into a document with 1000 existing nodes.
///
/// Measures the latency of [MutableDocument.insertNode] after building
/// a baseline document. Inserts at the end of the list.
class InsertNode1kBenchmark extends BenchmarkBase {
  InsertNode1kBenchmark() : super('MutableDocument.insertNode (1k nodes)');

  late MutableDocument _document;
  late DocumentNode _nodeToInsert;

  @override
  void setup() {
    // Build a document with 1000 nodes.
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 1000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node_$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = MutableDocument(nodes);

    // Prepare the node to insert (will be inserted at the end).
    _nodeToInsert = ParagraphNode(
      id: 'bench_node',
      text: AttributedText('Benchmark node'),
    );
  }

  @override
  void run() {
    _document.insertNode(_document.nodeCount, _nodeToInsert);
    // Reset for next iteration by removing the node we just inserted.
    _document.deleteNode('bench_node');
  }
}

/// Benchmark: Insert a node into a document with 10,000 existing nodes.
///
/// Measures the latency of [MutableDocument.insertNode] at larger scale.
class InsertNode10kBenchmark extends BenchmarkBase {
  InsertNode10kBenchmark() : super('MutableDocument.insertNode (10k nodes)');

  late MutableDocument _document;
  late DocumentNode _nodeToInsert;

  @override
  void setup() {
    // Build a document with 10,000 nodes.
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 10000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node_$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = MutableDocument(nodes);

    // Prepare the node to insert (will be inserted at the end).
    _nodeToInsert = ParagraphNode(
      id: 'bench_node',
      text: AttributedText('Benchmark node'),
    );
  }

  @override
  void run() {
    _document.insertNode(_document.nodeCount, _nodeToInsert);
    // Reset for next iteration by removing the node we just inserted.
    _document.deleteNode('bench_node');
  }
}

// ---------------------------------------------------------------------------
// DeleteNode benchmarks
// ---------------------------------------------------------------------------

/// Benchmark: Delete a node from the middle of a 1000-node document.
///
/// Measures the latency of [MutableDocument.deleteNode] after building
/// a baseline document, then re-inserts to reset state.
class DeleteNode1kBenchmark extends BenchmarkBase {
  DeleteNode1kBenchmark() : super('MutableDocument.deleteNode (1k nodes)');

  late MutableDocument _document;
  late DocumentNode _nodeToReinsert;

  @override
  void setup() {
    // Build a document with 1000 nodes.
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 1000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node_$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = MutableDocument(nodes);

    // The node we'll delete and re-insert is in the middle.
    _nodeToReinsert = _document.nodeAt(500);
  }

  @override
  void run() {
    // Delete the middle node.
    _document.deleteNode('node_500');
    // Re-insert it to reset state for the next iteration.
    _document.insertNode(500, _nodeToReinsert);
  }
}

// ---------------------------------------------------------------------------
// AttributedText benchmarks
// ---------------------------------------------------------------------------

/// Benchmark: Apply bold attribution to a small 100-character text.
///
/// Measures the latency of [AttributedText.applyAttribution] on
/// short text with minimal existing attributions.
class ApplyAttributionSmallBenchmark extends BenchmarkBase {
  ApplyAttributionSmallBenchmark() : super('AttributedText.applyAttribution (100 chars)');

  late AttributedText _text;

  @override
  void setup() {
    _text = AttributedText('x' * 100);
  }

  @override
  void run() {
    // Apply bold to the entire text.
    _text = _text.applyAttribution(NamedAttribution.bold, 0, 99);
  }
}

/// Benchmark: Apply bold attribution to a larger 10,000-character text.
///
/// Measures the latency of [AttributedText.applyAttribution] on
/// longer text.
class ApplyAttributionLargeBenchmark extends BenchmarkBase {
  ApplyAttributionLargeBenchmark() : super('AttributedText.applyAttribution (10k chars)');

  late AttributedText _text;

  @override
  void setup() {
    _text = AttributedText('x' * 10000);
  }

  @override
  void run() {
    // Apply bold to the entire text.
    _text = _text.applyAttribution(NamedAttribution.bold, 0, 9999);
  }
}

/// Benchmark: Apply multiple overlapping attributions to 1,000-char text.
///
/// Measures the latency of successive [AttributedText.applyAttribution]
/// calls that create overlapping spans.
class ApplyAttributionOverlappingBenchmark extends BenchmarkBase {
  ApplyAttributionOverlappingBenchmark()
      : super('AttributedText.applyAttribution (overlapping, 1k chars)');

  late AttributedText _text;

  @override
  void setup() {
    _text = AttributedText('x' * 1000);
  }

  @override
  void run() {
    // Apply multiple overlapping attributions.
    var text = _text;
    text = text.applyAttribution(NamedAttribution.bold, 0, 499);
    text = text.applyAttribution(NamedAttribution.italics, 250, 749);
    text = text.applyAttribution(NamedAttribution.underline, 500, 999);
    _text = text;
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

/// Runs all document model benchmarks and reports results.
void main() {
  // Insert node benchmarks.
  InsertNode1kBenchmark().report();
  InsertNode10kBenchmark().report();

  // Delete node benchmarks.
  DeleteNode1kBenchmark().report();

  // Attribution benchmarks.
  ApplyAttributionSmallBenchmark().report();
  ApplyAttributionLargeBenchmark().report();
  ApplyAttributionOverlappingBenchmark().report();
}
