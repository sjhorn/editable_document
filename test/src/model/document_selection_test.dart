/// Tests for [DocumentPosition] and [DocumentSelection].
library;

import 'dart:ui' show TextAffinity;

import 'package:editable_document/src/model/attributed_text.dart';
import 'package:editable_document/src/model/document.dart';
import 'package:editable_document/src/model/document_position.dart';
import 'package:editable_document/src/model/document_selection.dart';
import 'package:editable_document/src/model/image_node.dart';
import 'package:editable_document/src/model/node_position.dart';
import 'package:editable_document/src/model/paragraph_node.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// A three-node document used by affinity/normalize tests.
///
/// node-1: ParagraphNode  "First paragraph"
/// node-2: ParagraphNode  "Second paragraph"
/// node-3: ImageNode
Document _makeDoc() => Document([
      ParagraphNode(id: 'node-1', text: AttributedText('First paragraph')),
      ParagraphNode(id: 'node-2', text: AttributedText('Second paragraph')),
      ImageNode(id: 'node-3', imageUrl: 'https://example.com/image.png'),
    ]);

void main() {
  // =========================================================================
  // DocumentPosition
  // =========================================================================
  group('DocumentPosition', () {
    group('creation', () {
      test('stores nodeId and TextNodePosition', () {
        const pos = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 5),
        );
        expect(pos.nodeId, 'node-1');
        expect(pos.nodePosition, const TextNodePosition(offset: 5));
      });

      test('stores nodeId and BinaryNodePosition', () {
        const pos = DocumentPosition(
          nodeId: 'node-3',
          nodePosition: BinaryNodePosition.upstream(),
        );
        expect(pos.nodeId, 'node-3');
        expect(pos.nodePosition, const BinaryNodePosition.upstream());
      });
    });

    group('copyWith', () {
      test('copyWith replaces nodeId', () {
        const original = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 3),
        );
        final copy = original.copyWith(nodeId: 'node-2');
        expect(copy.nodeId, 'node-2');
        expect(copy.nodePosition, const TextNodePosition(offset: 3));
      });

      test('copyWith replaces nodePosition', () {
        const original = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 3),
        );
        final copy = original.copyWith(
          nodePosition: const TextNodePosition(offset: 10),
        );
        expect(copy.nodeId, 'node-1');
        expect(copy.nodePosition, const TextNodePosition(offset: 10));
      });

      test('copyWith with no args returns equal copy', () {
        const original = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 7),
        );
        final copy = original.copyWith();
        expect(copy, equals(original));
      });
    });

    group('equality', () {
      test('same nodeId and nodePosition are equal', () {
        const a = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 5),
        );
        const b = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 5),
        );
        expect(a, equals(b));
      });

      test('different nodeId not equal', () {
        const a = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 5),
        );
        const b = DocumentPosition(
          nodeId: 'node-2',
          nodePosition: TextNodePosition(offset: 5),
        );
        expect(a, isNot(equals(b)));
      });

      test('different nodePosition not equal', () {
        const a = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 5),
        );
        const b = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 6),
        );
        expect(a, isNot(equals(b)));
      });
    });

    group('hashCode', () {
      test('equal positions have equal hashCodes', () {
        const a = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 5),
        );
        const b = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 5),
        );
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('includes nodeId and nodePosition', () {
        const pos = DocumentPosition(
          nodeId: 'node-42',
          nodePosition: TextNodePosition(offset: 3),
        );
        final s = pos.toString();
        expect(s, contains('node-42'));
        expect(s, contains('3'));
      });
    });
  });

  // =========================================================================
  // DocumentSelection
  // =========================================================================
  group('DocumentSelection', () {
    // -----------------------------------------------------------------------
    // isCollapsed / isExpanded
    // -----------------------------------------------------------------------
    group('isCollapsed / isExpanded', () {
      test('collapsed selection: isCollapsed is true, isExpanded is false', () {
        const pos = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 3),
        );
        const sel = DocumentSelection(base: pos, extent: pos);
        expect(sel.isCollapsed, isTrue);
        expect(sel.isExpanded, isFalse);
      });

      test('expanded selection: isCollapsed is false, isExpanded is true', () {
        const base = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 0),
        );
        const extent = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 5),
        );
        const sel = DocumentSelection(base: base, extent: extent);
        expect(sel.isCollapsed, isFalse);
        expect(sel.isExpanded, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // DocumentSelection.collapsed factory
    // -----------------------------------------------------------------------
    group('DocumentSelection.collapsed', () {
      test('collapsed factory creates selection where base == extent', () {
        const pos = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 3),
        );
        const sel = DocumentSelection.collapsed(position: pos);
        expect(sel.base, equals(pos));
        expect(sel.extent, equals(pos));
        expect(sel.isCollapsed, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // affinity
    // -----------------------------------------------------------------------
    group('affinity', () {
      test('collapsed selection returns downstream', () {
        final doc = _makeDoc();
        const pos = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 3),
        );
        const sel = DocumentSelection.collapsed(position: pos);
        expect(sel.affinity(doc), TextAffinity.downstream);
      });

      test('extent after base in same node returns downstream', () {
        final doc = _makeDoc();
        const sel = DocumentSelection(
          base: DocumentPosition(
            nodeId: 'node-1',
            nodePosition: TextNodePosition(offset: 2),
          ),
          extent: DocumentPosition(
            nodeId: 'node-1',
            nodePosition: TextNodePosition(offset: 8),
          ),
        );
        expect(sel.affinity(doc), TextAffinity.downstream);
      });

      test('extent before base in same node returns upstream', () {
        final doc = _makeDoc();
        const sel = DocumentSelection(
          base: DocumentPosition(
            nodeId: 'node-1',
            nodePosition: TextNodePosition(offset: 8),
          ),
          extent: DocumentPosition(
            nodeId: 'node-1',
            nodePosition: TextNodePosition(offset: 2),
          ),
        );
        expect(sel.affinity(doc), TextAffinity.upstream);
      });

      test('extent in later node returns downstream', () {
        final doc = _makeDoc();
        const sel = DocumentSelection(
          base: DocumentPosition(
            nodeId: 'node-1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: 'node-2',
            nodePosition: TextNodePosition(offset: 0),
          ),
        );
        expect(sel.affinity(doc), TextAffinity.downstream);
      });

      test('extent in earlier node returns upstream', () {
        final doc = _makeDoc();
        const sel = DocumentSelection(
          base: DocumentPosition(
            nodeId: 'node-2',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: 'node-1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        );
        expect(sel.affinity(doc), TextAffinity.upstream);
      });

      test('BinaryNodePosition: downstream extent returns downstream', () {
        final doc = _makeDoc();
        const sel = DocumentSelection(
          base: DocumentPosition(
            nodeId: 'node-3',
            nodePosition: BinaryNodePosition.upstream(),
          ),
          extent: DocumentPosition(
            nodeId: 'node-3',
            nodePosition: BinaryNodePosition.downstream(),
          ),
        );
        expect(sel.affinity(doc), TextAffinity.downstream);
      });

      test('BinaryNodePosition: upstream extent returns upstream', () {
        final doc = _makeDoc();
        const sel = DocumentSelection(
          base: DocumentPosition(
            nodeId: 'node-3',
            nodePosition: BinaryNodePosition.downstream(),
          ),
          extent: DocumentPosition(
            nodeId: 'node-3',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        );
        expect(sel.affinity(doc), TextAffinity.upstream);
      });

      test('BinaryNodePosition: same position returns downstream', () {
        final doc = _makeDoc();
        const sel = DocumentSelection(
          base: DocumentPosition(
            nodeId: 'node-3',
            nodePosition: BinaryNodePosition.upstream(),
          ),
          extent: DocumentPosition(
            nodeId: 'node-3',
            nodePosition: BinaryNodePosition.upstream(),
          ),
        );
        // Same positions → collapsed → downstream.
        expect(sel.affinity(doc), TextAffinity.downstream);
      });
    });

    // -----------------------------------------------------------------------
    // normalize
    // -----------------------------------------------------------------------
    group('normalize', () {
      test('downstream selection is returned unchanged', () {
        final doc = _makeDoc();
        const base = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 0),
        );
        const extent = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 5),
        );
        const sel = DocumentSelection(base: base, extent: extent);
        final norm = sel.normalize(doc);
        expect(norm.base, equals(base));
        expect(norm.extent, equals(extent));
      });

      test('upstream selection swaps base and extent', () {
        final doc = _makeDoc();
        const base = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 5),
        );
        const extent = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 0),
        );
        const sel = DocumentSelection(base: base, extent: extent);
        final norm = sel.normalize(doc);
        // After normalization, the earlier position becomes base.
        expect(norm.base, equals(extent));
        expect(norm.extent, equals(base));
      });

      test('collapsed selection is returned unchanged', () {
        final doc = _makeDoc();
        const pos = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 3),
        );
        const sel = DocumentSelection.collapsed(position: pos);
        final norm = sel.normalize(doc);
        expect(norm, equals(sel));
      });

      test('normalize across different nodes: later extent stays', () {
        final doc = _makeDoc();
        const sel = DocumentSelection(
          base: DocumentPosition(
            nodeId: 'node-1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: 'node-2',
            nodePosition: TextNodePosition(offset: 3),
          ),
        );
        final norm = sel.normalize(doc);
        expect(norm.base.nodeId, 'node-1');
        expect(norm.extent.nodeId, 'node-2');
      });

      test('normalize across different nodes: earlier extent swaps', () {
        final doc = _makeDoc();
        const base = DocumentPosition(
          nodeId: 'node-2',
          nodePosition: TextNodePosition(offset: 0),
        );
        const extent = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 3),
        );
        const sel = DocumentSelection(base: base, extent: extent);
        final norm = sel.normalize(doc);
        expect(norm.base.nodeId, 'node-1');
        expect(norm.extent.nodeId, 'node-2');
      });
    });

    // -----------------------------------------------------------------------
    // copyWith
    // -----------------------------------------------------------------------
    group('copyWith', () {
      test('copyWith replaces base', () {
        const oldBase = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 0),
        );
        const extent = DocumentPosition(
          nodeId: 'node-2',
          nodePosition: TextNodePosition(offset: 5),
        );
        const sel = DocumentSelection(base: oldBase, extent: extent);

        const newBase = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 2),
        );
        final copy = sel.copyWith(base: newBase);
        expect(copy.base, equals(newBase));
        expect(copy.extent, equals(extent));
      });

      test('copyWith replaces extent', () {
        const base = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 0),
        );
        const oldExtent = DocumentPosition(
          nodeId: 'node-2',
          nodePosition: TextNodePosition(offset: 5),
        );
        const sel = DocumentSelection(base: base, extent: oldExtent);

        const newExtent = DocumentPosition(
          nodeId: 'node-2',
          nodePosition: TextNodePosition(offset: 10),
        );
        final copy = sel.copyWith(extent: newExtent);
        expect(copy.base, equals(base));
        expect(copy.extent, equals(newExtent));
      });
    });

    // -----------------------------------------------------------------------
    // equality
    // -----------------------------------------------------------------------
    group('equality', () {
      test('same base and extent are equal', () {
        const base = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 0),
        );
        const extent = DocumentPosition(
          nodeId: 'node-2',
          nodePosition: TextNodePosition(offset: 5),
        );
        const a = DocumentSelection(base: base, extent: extent);
        const b = DocumentSelection(base: base, extent: extent);
        expect(a, equals(b));
      });

      test('different base not equal', () {
        const extent = DocumentPosition(
          nodeId: 'node-2',
          nodePosition: TextNodePosition(offset: 5),
        );
        const a = DocumentSelection(
          base: DocumentPosition(
            nodeId: 'node-1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: extent,
        );
        const b = DocumentSelection(
          base: DocumentPosition(
            nodeId: 'node-1',
            nodePosition: TextNodePosition(offset: 1),
          ),
          extent: extent,
        );
        expect(a, isNot(equals(b)));
      });
    });

    // -----------------------------------------------------------------------
    // hashCode
    // -----------------------------------------------------------------------
    group('hashCode', () {
      test('equal selections have equal hashCodes', () {
        const base = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 0),
        );
        const extent = DocumentPosition(
          nodeId: 'node-2',
          nodePosition: TextNodePosition(offset: 5),
        );
        const a = DocumentSelection(base: base, extent: extent);
        const b = DocumentSelection(base: base, extent: extent);
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    // -----------------------------------------------------------------------
    // toString
    // -----------------------------------------------------------------------
    group('toString', () {
      test('includes base and extent', () {
        const base = DocumentPosition(
          nodeId: 'node-1',
          nodePosition: TextNodePosition(offset: 0),
        );
        const extent = DocumentPosition(
          nodeId: 'node-2',
          nodePosition: TextNodePosition(offset: 5),
        );
        const sel = DocumentSelection(base: base, extent: extent);
        final s = sel.toString();
        expect(s, contains('base'));
        expect(s, contains('extent'));
      });
    });
  });
}
