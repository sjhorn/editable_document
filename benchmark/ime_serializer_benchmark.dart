/// Benchmarks for DocumentImeSerializer.toTextEditingValue() at scale.
///
/// Tests the performance of serializing large documents to TextEditingValue
/// for IME consumption. Measures both Mode 1 (single-node selection) and
/// synthetic value generation.
library;

import 'benchmark_base.dart';
import 'package:editable_document/editable_document.dart';

// ---------------------------------------------------------------------------
// Benchmark: ImeSerialize100
// ---------------------------------------------------------------------------

/// Serializes a 100-node document to TextEditingValue.
///
/// Performance gate: < 5 ms
class ImeSerialize100Benchmark extends BenchmarkBase {
  ImeSerialize100Benchmark() : super('ImeSerialize100');

  late MutableDocument _document;
  late DocumentSelection _selection;
  final _serializer = const DocumentImeSerializer();

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 100; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = MutableDocument(nodes);
    _selection = const DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: 'node-0',
        nodePosition: TextNodePosition(offset: 0),
      ),
    );
  }

  @override
  void run() {
    _serializer.toTextEditingValue(
      document: _document,
      selection: _selection,
    );
  }
}

// ---------------------------------------------------------------------------
// Benchmark: ImeSerialize1000
// ---------------------------------------------------------------------------

/// Serializes a 1,000-node document to TextEditingValue.
///
/// Performance gate: < 5 ms
class ImeSerialize1000Benchmark extends BenchmarkBase {
  ImeSerialize1000Benchmark() : super('ImeSerialize1000');

  late MutableDocument _document;
  late DocumentSelection _selection;
  final _serializer = const DocumentImeSerializer();

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 1000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = MutableDocument(nodes);
    _selection = const DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: 'node-0',
        nodePosition: TextNodePosition(offset: 0),
      ),
    );
  }

  @override
  void run() {
    _serializer.toTextEditingValue(
      document: _document,
      selection: _selection,
    );
  }
}

// ---------------------------------------------------------------------------
// Benchmark: ImeSerialize10000
// ---------------------------------------------------------------------------

/// Serializes a 10,000-node document to TextEditingValue.
///
/// Performance gate: < 5 ms
class ImeSerialize10000Benchmark extends BenchmarkBase {
  ImeSerialize10000Benchmark() : super('ImeSerialize10000');

  late MutableDocument _document;
  late DocumentSelection _selection;
  final _serializer = const DocumentImeSerializer();

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
    _document = MutableDocument(nodes);
    _selection = const DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: 'node-0',
        nodePosition: TextNodePosition(offset: 0),
      ),
    );
  }

  @override
  void run() {
    _serializer.toTextEditingValue(
      document: _document,
      selection: _selection,
    );
  }
}

// ---------------------------------------------------------------------------
// Benchmark: ImeSerializeSyntheticCrossBlock
// ---------------------------------------------------------------------------

/// Serializes a synthetic value for cross-block selection.
///
/// This tests Mode 2 (synthetic) behavior where the selection spans
/// multiple nodes, requiring a placeholder value.
class ImeSerializeSyntheticCrossBlockBenchmark extends BenchmarkBase {
  ImeSerializeSyntheticCrossBlockBenchmark() : super('ImeSerializeSyntheticCrossBlock');

  late MutableDocument _document;
  late DocumentSelection _selection;
  final _serializer = const DocumentImeSerializer();

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 1000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = MutableDocument(nodes);
    // Selection spans from node 0 to node 500 (cross-block)
    _selection = const DocumentSelection(
      base: DocumentPosition(
        nodeId: 'node-0',
        nodePosition: TextNodePosition(offset: 0),
      ),
      extent: DocumentPosition(
        nodeId: 'node-500',
        nodePosition: TextNodePosition(offset: 0),
      ),
    );
  }

  @override
  void run() {
    _serializer.toTextEditingValue(
      document: _document,
      selection: _selection,
    );
  }
}

// ---------------------------------------------------------------------------
// Benchmark: ImeSerializeNullSelection
// ---------------------------------------------------------------------------

/// Serializes with null selection (no active selection).
///
/// Tests Mode 2 behavior when selection is null, which should return
/// an empty TextEditingValue.
class ImeSerializeNullSelectionBenchmark extends BenchmarkBase {
  ImeSerializeNullSelectionBenchmark() : super('ImeSerializeNullSelection');

  late MutableDocument _document;
  final _serializer = const DocumentImeSerializer();

  @override
  void setup() {
    final nodes = <DocumentNode>[];
    for (var i = 0; i < 1000; i++) {
      nodes.add(
        ParagraphNode(
          id: 'node-$i',
          text: AttributedText('Paragraph $i'),
        ),
      );
    }
    _document = MutableDocument(nodes);
  }

  @override
  void run() {
    _serializer.toTextEditingValue(
      document: _document,
      selection: null,
    );
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  // Mode 1: Single-node selection (most common case)
  ImeSerialize100Benchmark().report();
  ImeSerialize1000Benchmark().report();
  ImeSerialize10000Benchmark().report();

  // Mode 2: Synthetic values (cross-block and null selection)
  ImeSerializeSyntheticCrossBlockBenchmark().report();
  ImeSerializeNullSelectionBenchmark().report();
}
