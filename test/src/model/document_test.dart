/// Tests for [DocumentChangeEvent], [Document], and [MutableDocument].
library;

import 'package:editable_document/src/model/document.dart';
import 'package:editable_document/src/model/document_change_event.dart';
import 'package:editable_document/src/model/mutable_document.dart';
import 'package:editable_document/src/model/paragraph_node.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ParagraphNode _p(String id) => ParagraphNode(id: id);

void main() {
  // -------------------------------------------------------------------------
  // DocumentChangeEvent
  // -------------------------------------------------------------------------
  group('DocumentChangeEvent', () {
    group('NodeInserted', () {
      test('equality: same fields are equal', () {
        const a = NodeInserted(nodeId: 'n1', index: 0);
        const b = NodeInserted(nodeId: 'n1', index: 0);
        expect(a, equals(b));
      });

      test('equality: different nodeId not equal', () {
        const a = NodeInserted(nodeId: 'n1', index: 0);
        const b = NodeInserted(nodeId: 'n2', index: 0);
        expect(a, isNot(equals(b)));
      });

      test('equality: different index not equal', () {
        const a = NodeInserted(nodeId: 'n1', index: 0);
        const b = NodeInserted(nodeId: 'n1', index: 1);
        expect(a, isNot(equals(b)));
      });

      test('hashCode matches for equal instances', () {
        const a = NodeInserted(nodeId: 'n1', index: 2);
        const b = NodeInserted(nodeId: 'n1', index: 2);
        expect(a.hashCode, b.hashCode);
      });

      test('toString includes type, nodeId, and index', () {
        const event = NodeInserted(nodeId: 'n1', index: 3);
        final s = event.toString();
        expect(s, contains('NodeInserted'));
        expect(s, contains('n1'));
        expect(s, contains('3'));
      });
    });

    group('NodeDeleted', () {
      test('equality: same fields are equal', () {
        const a = NodeDeleted(nodeId: 'n1', index: 1);
        const b = NodeDeleted(nodeId: 'n1', index: 1);
        expect(a, equals(b));
      });

      test('equality: different nodeId not equal', () {
        const a = NodeDeleted(nodeId: 'n1', index: 1);
        const b = NodeDeleted(nodeId: 'n2', index: 1);
        expect(a, isNot(equals(b)));
      });

      test('equality: different index not equal', () {
        const a = NodeDeleted(nodeId: 'n1', index: 1);
        const b = NodeDeleted(nodeId: 'n1', index: 2);
        expect(a, isNot(equals(b)));
      });

      test('hashCode matches for equal instances', () {
        const a = NodeDeleted(nodeId: 'n2', index: 5);
        const b = NodeDeleted(nodeId: 'n2', index: 5);
        expect(a.hashCode, b.hashCode);
      });

      test('toString includes type, nodeId, and index', () {
        const event = NodeDeleted(nodeId: 'abc', index: 0);
        final s = event.toString();
        expect(s, contains('NodeDeleted'));
        expect(s, contains('abc'));
        expect(s, contains('0'));
      });
    });

    group('NodeReplaced', () {
      test('equality: same fields are equal', () {
        const a = NodeReplaced(oldNodeId: 'old', newNodeId: 'new');
        const b = NodeReplaced(oldNodeId: 'old', newNodeId: 'new');
        expect(a, equals(b));
      });

      test('equality: different oldNodeId not equal', () {
        const a = NodeReplaced(oldNodeId: 'old1', newNodeId: 'new');
        const b = NodeReplaced(oldNodeId: 'old2', newNodeId: 'new');
        expect(a, isNot(equals(b)));
      });

      test('equality: different newNodeId not equal', () {
        const a = NodeReplaced(oldNodeId: 'old', newNodeId: 'new1');
        const b = NodeReplaced(oldNodeId: 'old', newNodeId: 'new2');
        expect(a, isNot(equals(b)));
      });

      test('hashCode matches for equal instances', () {
        const a = NodeReplaced(oldNodeId: 'x', newNodeId: 'y');
        const b = NodeReplaced(oldNodeId: 'x', newNodeId: 'y');
        expect(a.hashCode, b.hashCode);
      });

      test('toString includes type, oldNodeId, and newNodeId', () {
        const event = NodeReplaced(oldNodeId: 'oldId', newNodeId: 'newId');
        final s = event.toString();
        expect(s, contains('NodeReplaced'));
        expect(s, contains('oldId'));
        expect(s, contains('newId'));
      });
    });

    group('NodeMoved', () {
      test('equality: same fields are equal', () {
        const a = NodeMoved(nodeId: 'n1', oldIndex: 0, newIndex: 2);
        const b = NodeMoved(nodeId: 'n1', oldIndex: 0, newIndex: 2);
        expect(a, equals(b));
      });

      test('equality: different nodeId not equal', () {
        const a = NodeMoved(nodeId: 'n1', oldIndex: 0, newIndex: 2);
        const b = NodeMoved(nodeId: 'n2', oldIndex: 0, newIndex: 2);
        expect(a, isNot(equals(b)));
      });

      test('equality: different oldIndex not equal', () {
        const a = NodeMoved(nodeId: 'n1', oldIndex: 0, newIndex: 2);
        const b = NodeMoved(nodeId: 'n1', oldIndex: 1, newIndex: 2);
        expect(a, isNot(equals(b)));
      });

      test('equality: different newIndex not equal', () {
        const a = NodeMoved(nodeId: 'n1', oldIndex: 0, newIndex: 2);
        const b = NodeMoved(nodeId: 'n1', oldIndex: 0, newIndex: 3);
        expect(a, isNot(equals(b)));
      });

      test('hashCode matches for equal instances', () {
        const a = NodeMoved(nodeId: 'n1', oldIndex: 1, newIndex: 3);
        const b = NodeMoved(nodeId: 'n1', oldIndex: 1, newIndex: 3);
        expect(a.hashCode, b.hashCode);
      });

      test('toString includes type, nodeId, oldIndex, and newIndex', () {
        const event = NodeMoved(nodeId: 'n1', oldIndex: 1, newIndex: 4);
        final s = event.toString();
        expect(s, contains('NodeMoved'));
        expect(s, contains('n1'));
        expect(s, contains('1'));
        expect(s, contains('4'));
      });
    });

    group('TextChanged', () {
      test('equality: same nodeId are equal', () {
        const a = TextChanged(nodeId: 'n1');
        const b = TextChanged(nodeId: 'n1');
        expect(a, equals(b));
      });

      test('equality: different nodeId not equal', () {
        const a = TextChanged(nodeId: 'n1');
        const b = TextChanged(nodeId: 'n2');
        expect(a, isNot(equals(b)));
      });

      test('hashCode matches for equal instances', () {
        const a = TextChanged(nodeId: 'x');
        const b = TextChanged(nodeId: 'x');
        expect(a.hashCode, b.hashCode);
      });

      test('toString includes type and nodeId', () {
        const event = TextChanged(nodeId: 'myNode');
        final s = event.toString();
        expect(s, contains('TextChanged'));
        expect(s, contains('myNode'));
      });
    });
  });

  // -------------------------------------------------------------------------
  // Document (immutable)
  // -------------------------------------------------------------------------
  group('Document', () {
    test('empty document: isEmpty is true', () {
      final doc = Document();
      expect(doc.isEmpty, isTrue);
    });

    test('empty document: isNotEmpty is false', () {
      final doc = Document();
      expect(doc.isNotEmpty, isFalse);
    });

    test('empty document: nodeCount is 0', () {
      final doc = Document();
      expect(doc.nodeCount, 0);
    });

    test('document with nodes: nodeCount is correct', () {
      final doc = Document([_p('n1'), _p('n2'), _p('n3')]);
      expect(doc.nodeCount, 3);
    });

    test('document with nodes: nodes list has all nodes', () {
      final n1 = _p('n1');
      final n2 = _p('n2');
      final doc = Document([n1, n2]);
      expect(doc.nodes, [n1, n2]);
    });

    test('nodeById finds existing node', () {
      final n1 = _p('n1');
      final n2 = _p('n2');
      final doc = Document([n1, n2]);
      expect(doc.nodeById('n1'), n1);
      expect(doc.nodeById('n2'), n2);
    });

    test('nodeById returns null for missing id', () {
      final doc = Document([_p('n1')]);
      expect(doc.nodeById('missing'), isNull);
    });

    test('nodeAt returns correct node', () {
      final n1 = _p('n1');
      final n2 = _p('n2');
      final n3 = _p('n3');
      final doc = Document([n1, n2, n3]);
      expect(doc.nodeAt(0), n1);
      expect(doc.nodeAt(1), n2);
      expect(doc.nodeAt(2), n3);
    });

    test('nodeAfter returns next node', () {
      final n1 = _p('n1');
      final n2 = _p('n2');
      final doc = Document([n1, n2]);
      expect(doc.nodeAfter('n1'), n2);
    });

    test('nodeAfter returns null for last node', () {
      final doc = Document([_p('n1'), _p('n2')]);
      expect(doc.nodeAfter('n2'), isNull);
    });

    test('nodeAfter returns null for unknown id', () {
      final doc = Document([_p('n1')]);
      expect(doc.nodeAfter('unknown'), isNull);
    });

    test('nodeBefore returns previous node', () {
      final n1 = _p('n1');
      final n2 = _p('n2');
      final doc = Document([n1, n2]);
      expect(doc.nodeBefore('n2'), n1);
    });

    test('nodeBefore returns null for first node', () {
      final doc = Document([_p('n1'), _p('n2')]);
      expect(doc.nodeBefore('n1'), isNull);
    });

    test('nodeBefore returns null for unknown id', () {
      final doc = Document([_p('n1')]);
      expect(doc.nodeBefore('unknown'), isNull);
    });

    test('getNodeIndexById returns correct index', () {
      final doc = Document([_p('n1'), _p('n2'), _p('n3')]);
      expect(doc.getNodeIndexById('n1'), 0);
      expect(doc.getNodeIndexById('n2'), 1);
      expect(doc.getNodeIndexById('n3'), 2);
    });

    test('getNodeIndexById returns -1 for missing id', () {
      final doc = Document([_p('n1')]);
      expect(doc.getNodeIndexById('missing'), -1);
    });

    test('equality: same nodes are equal', () {
      final a = Document([_p('n1'), _p('n2')]);
      final b = Document([_p('n1'), _p('n2')]);
      expect(a, equals(b));
    });

    test('equality: different nodes not equal', () {
      final a = Document([_p('n1')]);
      final b = Document([_p('n2')]);
      expect(a, isNot(equals(b)));
    });

    test('equality: different order not equal', () {
      final a = Document([_p('n1'), _p('n2')]);
      final b = Document([_p('n2'), _p('n1')]);
      expect(a, isNot(equals(b)));
    });

    test('hashCode matches for equal documents', () {
      final a = Document([_p('n1'), _p('n2')]);
      final b = Document([_p('n1'), _p('n2')]);
      expect(a.hashCode, b.hashCode);
    });

    test('toString includes Document and node count', () {
      final doc = Document([_p('n1'), _p('n2')]);
      final s = doc.toString();
      expect(s, contains('Document'));
    });

    test('nodes list is unmodifiable', () {
      final doc = Document([_p('n1')]);
      expect(() => doc.nodes.add(_p('n2')), throwsUnsupportedError);
    });
  });

  // -------------------------------------------------------------------------
  // MutableDocument
  // -------------------------------------------------------------------------
  group('MutableDocument', () {
    test('starts empty when constructed with no arguments', () {
      final doc = MutableDocument();
      expect(doc.isEmpty, isTrue);
      expect(doc.nodeCount, 0);
    });

    test('starts with provided nodes', () {
      final doc = MutableDocument([_p('n1'), _p('n2')]);
      expect(doc.nodeCount, 2);
    });

    // insertNode ---------------------------------------------------------------

    test('insertNode at index 0 prepends the node', () {
      final doc = MutableDocument([_p('n1'), _p('n2')]);
      final newNode = _p('n0');
      doc.insertNode(0, newNode);
      expect(doc.nodes.first, newNode);
      expect(doc.nodeCount, 3);
    });

    test('insertNode at end appends the node', () {
      final doc = MutableDocument([_p('n1'), _p('n2')]);
      final newNode = _p('n3');
      doc.insertNode(2, newNode);
      expect(doc.nodes.last, newNode);
      expect(doc.nodeCount, 3);
    });

    test('insertNode in the middle inserts at correct position', () {
      final doc = MutableDocument([_p('n1'), _p('n3')]);
      final middle = _p('n2');
      doc.insertNode(1, middle);
      expect(doc.nodeAt(1), middle);
      expect(doc.nodeCount, 3);
    });

    test('insertNode emits NodeInserted event', () {
      final doc = MutableDocument([_p('n1')]);
      doc.insertNode(1, _p('n2'));
      expect(doc.changes.value, hasLength(1));
      expect(doc.changes.value.first, isA<NodeInserted>());
      final event = doc.changes.value.first as NodeInserted;
      expect(event.nodeId, 'n2');
      expect(event.index, 1);
    });

    test('insertNode at beginning emits NodeInserted with index 0', () {
      final doc = MutableDocument([_p('n1')]);
      doc.insertNode(0, _p('n0'));
      final event = doc.changes.value.first as NodeInserted;
      expect(event.index, 0);
      expect(event.nodeId, 'n0');
    });

    test('insertNode at end emits NodeInserted with last index', () {
      final doc = MutableDocument([_p('n1'), _p('n2')]);
      doc.insertNode(2, _p('n3'));
      final event = doc.changes.value.first as NodeInserted;
      expect(event.index, 2);
      expect(event.nodeId, 'n3');
    });

    // deleteNode ---------------------------------------------------------------

    test('deleteNode removes the node', () {
      final doc = MutableDocument([_p('n1'), _p('n2'), _p('n3')]);
      doc.deleteNode('n2');
      expect(doc.nodeCount, 2);
      expect(doc.nodeById('n2'), isNull);
    });

    test('deleteNode emits NodeDeleted event with correct index', () {
      final doc = MutableDocument([_p('n1'), _p('n2'), _p('n3')]);
      doc.deleteNode('n2');
      expect(doc.changes.value, hasLength(1));
      final event = doc.changes.value.first as NodeDeleted;
      expect(event.nodeId, 'n2');
      expect(event.index, 1);
    });

    test('deleteNode throws StateError for missing id', () {
      final doc = MutableDocument([_p('n1')]);
      expect(() => doc.deleteNode('missing'), throwsStateError);
    });

    // replaceNode --------------------------------------------------------------

    test('replaceNode replaces node at same index', () {
      final doc = MutableDocument([_p('n1'), _p('n2'), _p('n3')]);
      final replacement = _p('nX');
      doc.replaceNode('n2', replacement);
      expect(doc.nodeAt(1), replacement);
      expect(doc.nodeCount, 3);
    });

    test('replaceNode emits NodeReplaced event', () {
      final doc = MutableDocument([_p('n1'), _p('n2')]);
      doc.replaceNode('n1', _p('nNew'));
      expect(doc.changes.value, hasLength(1));
      final event = doc.changes.value.first as NodeReplaced;
      expect(event.oldNodeId, 'n1');
      expect(event.newNodeId, 'nNew');
    });

    test('replaceNode throws StateError for missing id', () {
      final doc = MutableDocument([_p('n1')]);
      expect(() => doc.replaceNode('missing', _p('nNew')), throwsStateError);
    });

    // moveNode -----------------------------------------------------------------

    test('moveNode forward shifts nodes correctly', () {
      final doc = MutableDocument([_p('a'), _p('b'), _p('c'), _p('d')]);
      doc.moveNode('a', 2);
      expect(doc.nodes.map((n) => n.id).toList(), ['b', 'c', 'a', 'd']);
    });

    test('moveNode backward shifts nodes correctly', () {
      final doc = MutableDocument([_p('a'), _p('b'), _p('c'), _p('d')]);
      doc.moveNode('c', 0);
      expect(doc.nodes.map((n) => n.id).toList(), ['c', 'a', 'b', 'd']);
    });

    test('moveNode emits NodeMoved event with correct indices', () {
      final doc = MutableDocument([_p('a'), _p('b'), _p('c')]);
      doc.moveNode('a', 2);
      expect(doc.changes.value, hasLength(1));
      final event = doc.changes.value.first as NodeMoved;
      expect(event.nodeId, 'a');
      expect(event.oldIndex, 0);
      expect(event.newIndex, 2);
    });

    test('moveNode throws StateError for missing id', () {
      final doc = MutableDocument([_p('n1')]);
      expect(() => doc.moveNode('missing', 0), throwsStateError);
    });

    // updateNode ---------------------------------------------------------------

    test('updateNode applies updater function', () {
      final doc = MutableDocument([_p('n1'), _p('n2')]);
      doc.updateNode('n1', (node) => node.copyWith(id: 'n1-updated'));
      expect(doc.nodeById('n1'), isNull);
      expect(doc.nodeById('n1-updated'), isNotNull);
    });

    test('updateNode emits NodeReplaced event', () {
      final doc = MutableDocument([_p('n1')]);
      doc.updateNode('n1', (node) => node.copyWith(id: 'n1-new'));
      expect(doc.changes.value, hasLength(1));
      final event = doc.changes.value.first as NodeReplaced;
      expect(event.oldNodeId, 'n1');
      expect(event.newNodeId, 'n1-new');
    });

    test('updateNode throws StateError for missing id', () {
      final doc = MutableDocument([_p('n1')]);
      expect(() => doc.updateNode('missing', (n) => n), throwsStateError);
    });

    // changes ValueNotifier ----------------------------------------------------

    test('changes ValueNotifier fires on insertNode', () {
      final doc = MutableDocument();
      var callCount = 0;
      doc.changes.addListener(() => callCount++);
      doc.insertNode(0, _p('n1'));
      expect(callCount, 1);
    });

    test('changes ValueNotifier fires on deleteNode', () {
      final doc = MutableDocument([_p('n1')]);
      var callCount = 0;
      doc.changes.addListener(() => callCount++);
      doc.deleteNode('n1');
      expect(callCount, 1);
    });

    test('changes ValueNotifier fires on replaceNode', () {
      final doc = MutableDocument([_p('n1')]);
      var callCount = 0;
      doc.changes.addListener(() => callCount++);
      doc.replaceNode('n1', _p('n2'));
      expect(callCount, 1);
    });

    test('changes ValueNotifier fires on moveNode', () {
      final doc = MutableDocument([_p('a'), _p('b'), _p('c')]);
      var callCount = 0;
      doc.changes.addListener(() => callCount++);
      doc.moveNode('a', 2);
      expect(callCount, 1);
    });

    test('changes ValueNotifier fires on updateNode', () {
      final doc = MutableDocument([_p('n1')]);
      var callCount = 0;
      doc.changes.addListener(() => callCount++);
      doc.updateNode('n1', (n) => n.copyWith(id: 'n1-updated'));
      expect(callCount, 1);
    });

    test('multiple mutations each fire their own event', () {
      final doc = MutableDocument();
      final events = <List<DocumentChangeEvent>>[];
      doc.changes.addListener(() => events.add(List.from(doc.changes.value)));
      doc.insertNode(0, _p('n1'));
      doc.insertNode(1, _p('n2'));
      doc.deleteNode('n1');
      expect(events, hasLength(3));
      expect(events[0].first, isA<NodeInserted>());
      expect(events[1].first, isA<NodeInserted>());
      expect(events[2].first, isA<NodeDeleted>());
    });

    // nodes getter unmodifiable ------------------------------------------------

    test('nodes getter returns unmodifiable view', () {
      final doc = MutableDocument([_p('n1')]);
      expect(() => doc.nodes.add(_p('n2')), throwsUnsupportedError);
    });

    // empty document operations ------------------------------------------------

    test('deleteNode on empty document throws StateError', () {
      final doc = MutableDocument();
      expect(() => doc.deleteNode('anything'), throwsStateError);
    });

    test('replaceNode on empty document throws StateError', () {
      final doc = MutableDocument();
      expect(() => doc.replaceNode('anything', _p('new')), throwsStateError);
    });

    test('updateNode on empty document throws StateError', () {
      final doc = MutableDocument();
      expect(() => doc.updateNode('anything', (n) => n), throwsStateError);
    });

    // isA Document -------------------------------------------------------------

    test('MutableDocument is a Document', () {
      final doc = MutableDocument([_p('n1')]);
      expect(doc, isA<Document>());
    });
  });
}
