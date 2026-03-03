/// Benchmarks for document-level position and node lookup operations.
///
/// Since RenderDocumentLayout requires a full Flutter rendering pipeline and
/// cannot be easily benchmarked via `dart run`, this benchmark suite focuses on
/// the model-level operations that feed layout queries:
///   - Document.nodeById() — node lookup by id (linear scan)
///   - Document.getNodeIndexById() — node index lookup by id
///   - Document.nodeBefore/nodeAfter() — adjacent node queries
///
/// These operations are called frequently during layout and selection handling,
/// so their performance is critical for document responsiveness.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Benchmark: DocumentNodeLookupBeginning
// ---------------------------------------------------------------------------

/// Looks up a node at the beginning of a 10,000-node document.
///
/// Fast path: target is near the start of the node list.
class DocumentNodeLookupBeginningBenchmark extends BenchmarkBase {
  DocumentNodeLookupBeginningBenchmark() : super('DocumentNodeLookupBeginning');

  late Document _document;

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 10000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = Document(nodes);
  }

  @override
  void run() {
    _document.nodeById('node-0');
  }
}

// ---------------------------------------------------------------------------
// Benchmark: DocumentNodeLookupMiddle
// ---------------------------------------------------------------------------

/// Looks up a node at the middle of a 10,000-node document.
///
/// Average path: target is near the midpoint of the node list.
class DocumentNodeLookupMiddleBenchmark extends BenchmarkBase {
  DocumentNodeLookupMiddleBenchmark() : super('DocumentNodeLookupMiddle');

  late Document _document;

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 10000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = Document(nodes);
  }

  @override
  void run() {
    _document.nodeById('node-5000');
  }
}

// ---------------------------------------------------------------------------
// Benchmark: DocumentNodeLookupEnd
// ---------------------------------------------------------------------------

/// Looks up a node at the end of a 10,000-node document.
///
/// Slow path: target is near the end of the node list.
class DocumentNodeLookupEndBenchmark extends BenchmarkBase {
  DocumentNodeLookupEndBenchmark() : super('DocumentNodeLookupEnd');

  late Document _document;

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 10000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = Document(nodes);
  }

  @override
  void run() {
    _document.nodeById('node-9999');
  }
}

// ---------------------------------------------------------------------------
// Benchmark: DocumentNodeIndexLookupBeginning
// ---------------------------------------------------------------------------

/// Looks up a node index at the beginning of a 10,000-node document.
///
/// Fast path: target is near the start.
class DocumentNodeIndexLookupBeginningBenchmark extends BenchmarkBase {
  DocumentNodeIndexLookupBeginningBenchmark() : super('DocumentNodeIndexLookupBeginning');

  late Document _document;

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 10000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = Document(nodes);
  }

  @override
  void run() {
    _document.getNodeIndexById('node-0');
  }
}

// ---------------------------------------------------------------------------
// Benchmark: DocumentNodeIndexLookupMiddle
// ---------------------------------------------------------------------------

/// Looks up a node index at the middle of a 10,000-node document.
///
/// Average path: target is near the midpoint.
class DocumentNodeIndexLookupMiddleBenchmark extends BenchmarkBase {
  DocumentNodeIndexLookupMiddleBenchmark() : super('DocumentNodeIndexLookupMiddle');

  late Document _document;

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 10000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = Document(nodes);
  }

  @override
  void run() {
    _document.getNodeIndexById('node-5000');
  }
}

// ---------------------------------------------------------------------------
// Benchmark: DocumentNodeIndexLookupEnd
// ---------------------------------------------------------------------------

/// Looks up a node index at the end of a 10,000-node document.
///
/// Slow path: target is near the end.
class DocumentNodeIndexLookupEndBenchmark extends BenchmarkBase {
  DocumentNodeIndexLookupEndBenchmark() : super('DocumentNodeIndexLookupEnd');

  late Document _document;

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 10000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = Document(nodes);
  }

  @override
  void run() {
    _document.getNodeIndexById('node-9999');
  }
}

// ---------------------------------------------------------------------------
// Benchmark: DocumentAdjacentNodeLookup
// ---------------------------------------------------------------------------

/// Looks up adjacent nodes (nodeAfter/nodeBefore) in a 10,000-node document.
///
/// Tests the performance of traversing the document structure, which is used
/// during selection expansion and cursor navigation.
class DocumentAdjacentNodeLookupBenchmark extends BenchmarkBase {
  DocumentAdjacentNodeLookupBenchmark() : super('DocumentAdjacentNodeLookup');

  late Document _document;

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 10000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = Document(nodes);
  }

  @override
  void run() {
    // Simulate cursor movement: lookup current node, then next node
    final current = _document.nodeById('node-5000');
    if (current != null) {
      _document.nodeAfter('node-5000');
    }
  }
}

// ---------------------------------------------------------------------------
// Benchmark: DocumentIterateAllNodes
// ---------------------------------------------------------------------------

/// Iterates all 10,000 nodes and looks up each by id.
///
/// Simulates position resolution that needs to scan from a cursor position
/// to find all affected nodes (e.g., during drag selection).
class DocumentIterateAllNodesBenchmark extends BenchmarkBase {
  DocumentIterateAllNodesBenchmark() : super('DocumentIterateAllNodes');

  late Document _document;

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 10000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = Document(nodes);
  }

  @override
  void run() {
    // Iterate through the node list and verify lookup
    for (final node in _document.nodes) {
      _document.nodeById(node.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Benchmark: DocumentSelectionNormalization
// ---------------------------------------------------------------------------

/// Normalizes a cross-node selection in a 10,000-node document.
///
/// Selection normalization calls affinity() which may perform
/// getNodeIndexById() calls to compare node positions.
class DocumentSelectionNormalizationBenchmark extends BenchmarkBase {
  DocumentSelectionNormalizationBenchmark() : super('DocumentSelectionNormalization');

  late Document _document;
  late DocumentSelection _selection;

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 10000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = Document(nodes);
    // Create a selection that spans from node 8000 to node 2000 (backwards)
    _selection = const DocumentSelection(
      base: DocumentPosition(
        nodeId: 'node-8000',
        nodePosition: TextNodePosition(offset: 0),
      ),
      extent: DocumentPosition(
        nodeId: 'node-2000',
        nodePosition: TextNodePosition(offset: 0),
      ),
    );
  }

  @override
  void run() {
    // Normalize will call affinity() and getNodeIndexById()
    _selection.normalize(_document);
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  // Node lookup benchmarks (fast, average, slow paths)
  DocumentNodeLookupBeginningBenchmark().report();
  DocumentNodeLookupMiddleBenchmark().report();
  DocumentNodeLookupEndBenchmark().report();

  // Node index lookup benchmarks
  DocumentNodeIndexLookupBeginningBenchmark().report();
  DocumentNodeIndexLookupMiddleBenchmark().report();
  DocumentNodeIndexLookupEndBenchmark().report();

  // Adjacent node lookup (cursor navigation pattern)
  DocumentAdjacentNodeLookupBenchmark().report();

  // Iteration and selection operations
  DocumentIterateAllNodesBenchmark().report();
  DocumentSelectionNormalizationBenchmark().report();
}
