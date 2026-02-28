import 'package:editable_document/src/model/attribution.dart';
import 'package:editable_document/src/model/attributed_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // SpanMarker
  // ---------------------------------------------------------------------------
  group('SpanMarker', () {
    test('compareTo orders by offset first', () {
      const a = SpanMarker(
        attribution: NamedAttribution.bold,
        offset: 2,
        markerType: SpanMarkerType.start,
      );
      const b = SpanMarker(
        attribution: NamedAttribution.bold,
        offset: 5,
        markerType: SpanMarkerType.start,
      );
      expect(a.compareTo(b), isNegative);
      expect(b.compareTo(a), isPositive);
    });

    test('compareTo places start before end at the same offset', () {
      const start = SpanMarker(
        attribution: NamedAttribution.bold,
        offset: 3,
        markerType: SpanMarkerType.start,
      );
      const end = SpanMarker(
        attribution: NamedAttribution.bold,
        offset: 3,
        markerType: SpanMarkerType.end,
      );
      expect(start.compareTo(end), isNegative);
      expect(end.compareTo(start), isPositive);
    });

    test('compareTo returns 0 for identical markers', () {
      const a = SpanMarker(
        attribution: NamedAttribution.bold,
        offset: 3,
        markerType: SpanMarkerType.start,
      );
      const b = SpanMarker(
        attribution: NamedAttribution.bold,
        offset: 3,
        markerType: SpanMarkerType.start,
      );
      expect(a.compareTo(b), 0);
    });

    test('copyWith overrides individual fields', () {
      const original = SpanMarker(
        attribution: NamedAttribution.bold,
        offset: 0,
        markerType: SpanMarkerType.start,
      );
      final copy = original.copyWith(offset: 10, markerType: SpanMarkerType.end);
      expect(copy.attribution, NamedAttribution.bold);
      expect(copy.offset, 10);
      expect(copy.markerType, SpanMarkerType.end);
    });

    test('equality and hashCode are value-based', () {
      const a = SpanMarker(
        attribution: NamedAttribution.bold,
        offset: 3,
        markerType: SpanMarkerType.start,
      );
      const b = SpanMarker(
        attribution: NamedAttribution.bold,
        offset: 3,
        markerType: SpanMarkerType.start,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  // AttributionSpan
  // ---------------------------------------------------------------------------
  group('AttributionSpan', () {
    test('stores attribution, start, and end', () {
      const span = AttributionSpan(
        attribution: NamedAttribution.bold,
        start: 2,
        end: 5,
      );
      expect(span.attribution, NamedAttribution.bold);
      expect(span.start, 2);
      expect(span.end, 5);
    });

    test('equality is value-based', () {
      const a = AttributionSpan(attribution: NamedAttribution.bold, start: 2, end: 5);
      const b = AttributionSpan(attribution: NamedAttribution.bold, start: 2, end: 5);
      const c = AttributionSpan(attribution: NamedAttribution.italics, start: 2, end: 5);
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  // ---------------------------------------------------------------------------
  // AttributedText — construction
  // ---------------------------------------------------------------------------
  group('AttributedText construction', () {
    test('default constructor creates empty text', () {
      final at = AttributedText();
      expect(at.text, '');
      expect(at.length, 0);
    });

    test('constructor with text only', () {
      final at = AttributedText('hello');
      expect(at.text, 'hello');
      expect(at.length, 5);
    });

    test('queries on empty text return empty results', () {
      final at = AttributedText();
      expect(at.getAttributionsAt(0), isEmpty);
      expect(at.hasAttributionAt(0, NamedAttribution.bold), isFalse);
      expect(at.getAttributionSpansInRange(0, 0), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getAttributionsAt / hasAttributionAt
  // ---------------------------------------------------------------------------
  group('getAttributionsAt', () {
    test('returns bold at applied offsets', () {
      final at = AttributedText('hello world').applyAttribution(NamedAttribution.bold, 2, 5);
      expect(at.getAttributionsAt(2), contains(NamedAttribution.bold));
      expect(at.getAttributionsAt(4), contains(NamedAttribution.bold));
      expect(at.getAttributionsAt(5), contains(NamedAttribution.bold));
    });

    test('does not return bold outside applied range', () {
      final at = AttributedText('hello world').applyAttribution(NamedAttribution.bold, 2, 5);
      expect(at.getAttributionsAt(0), isNot(contains(NamedAttribution.bold)));
      expect(at.getAttributionsAt(1), isNot(contains(NamedAttribution.bold)));
      expect(at.getAttributionsAt(6), isNot(contains(NamedAttribution.bold)));
    });

    test('returns multiple attributions at same offset', () {
      final at = AttributedText('hello world')
          .applyAttribution(NamedAttribution.bold, 0, 5)
          .applyAttribution(NamedAttribution.italics, 3, 8);
      expect(
          at.getAttributionsAt(4), containsAll([NamedAttribution.bold, NamedAttribution.italics]));
    });

    test('hasAttributionAt returns true when present', () {
      final at = AttributedText('hello').applyAttribution(NamedAttribution.bold, 0, 4);
      expect(at.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      expect(at.hasAttributionAt(4, NamedAttribution.bold), isTrue);
    });

    test('hasAttributionAt returns false when absent', () {
      final at = AttributedText('hello').applyAttribution(NamedAttribution.bold, 0, 2);
      expect(at.hasAttributionAt(3, NamedAttribution.bold), isFalse);
      expect(at.hasAttributionAt(0, NamedAttribution.italics), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // getAttributionSpanAt
  // ---------------------------------------------------------------------------
  group('getAttributionSpanAt', () {
    test('returns the full span at a queried offset', () {
      final at = AttributedText('hello world').applyAttribution(NamedAttribution.bold, 2, 7);
      final span = at.getAttributionSpanAt(4, NamedAttribution.bold);
      expect(span, isNotNull);
      expect(span!.start, 2);
      expect(span.end, 7);
    });

    test('returns null when no attribution at offset', () {
      final at = AttributedText('hello world');
      expect(at.getAttributionSpanAt(3, NamedAttribution.bold), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // getAttributionSpansInRange
  // ---------------------------------------------------------------------------
  group('getAttributionSpansInRange', () {
    test('returns all overlapping spans', () {
      final at = AttributedText('hello world')
          .applyAttribution(NamedAttribution.bold, 0, 4)
          .applyAttribution(NamedAttribution.italics, 3, 8);
      final spans = at.getAttributionSpansInRange(2, 6).toList();
      expect(
          spans.map((s) => s.attribution),
          containsAll([
            NamedAttribution.bold,
            NamedAttribution.italics,
          ]));
    });

    test('returns empty when no attributions in range', () {
      final at = AttributedText('hello world');
      expect(at.getAttributionSpansInRange(0, 5), isEmpty);
    });

    test('returns spans that partially overlap query range', () {
      final at = AttributedText('hello world').applyAttribution(NamedAttribution.bold, 0, 10);
      final spans = at.getAttributionSpansInRange(5, 8).toList();
      expect(spans, hasLength(1));
      expect(spans.first.attribution, NamedAttribution.bold);
    });
  });

  // ---------------------------------------------------------------------------
  // applyAttribution — merging behaviour
  // ---------------------------------------------------------------------------
  group('applyAttribution', () {
    test('applying same attribution twice merges into one span', () {
      final at = AttributedText('hello world')
          .applyAttribution(NamedAttribution.bold, 0, 5)
          .applyAttribution(NamedAttribution.bold, 3, 8);
      // The merged span should cover [0, 8].
      final span = at.getAttributionSpanAt(0, NamedAttribution.bold);
      expect(span, isNotNull);
      expect(span!.start, 0);
      expect(span.end, 8);
      // Nothing beyond 8 should be bold.
      expect(at.hasAttributionAt(9, NamedAttribution.bold), isFalse);
    });

    test('adjacent spans are merged when canMergeWith is true', () {
      // bold [0,3] and bold [4,7] — adjacent, should merge into [0,7]
      final at = AttributedText('hello world')
          .applyAttribution(NamedAttribution.bold, 0, 3)
          .applyAttribution(NamedAttribution.bold, 4, 7);
      final span = at.getAttributionSpanAt(0, NamedAttribution.bold);
      expect(span, isNotNull);
      expect(span!.start, 0);
      expect(span.end, 7);
    });

    test('different attributions are stored independently', () {
      final at = AttributedText('hello world')
          .applyAttribution(NamedAttribution.bold, 0, 5)
          .applyAttribution(NamedAttribution.italics, 0, 5);
      expect(at.hasAttributionAt(3, NamedAttribution.bold), isTrue);
      expect(at.hasAttributionAt(3, NamedAttribution.italics), isTrue);
    });

    test('link attributions with different URLs are not merged', () {
      final urlA = Uri.parse('https://a.com');
      final urlB = Uri.parse('https://b.com');
      final at = AttributedText('hello world')
          .applyAttribution(LinkAttribution(urlA), 0, 4)
          .applyAttribution(LinkAttribution(urlB), 5, 10);
      final spanA = at.getAttributionSpanAt(0, LinkAttribution(urlA));
      final spanB = at.getAttributionSpanAt(5, LinkAttribution(urlB));
      expect(spanA, isNotNull);
      expect(spanA!.end, 4);
      expect(spanB, isNotNull);
      expect(spanB!.start, 5);
    });
  });

  // ---------------------------------------------------------------------------
  // removeAttribution
  // ---------------------------------------------------------------------------
  group('removeAttribution', () {
    test('removes attribution over full span', () {
      final at = AttributedText('hello')
          .applyAttribution(NamedAttribution.bold, 0, 4)
          .removeAttribution(NamedAttribution.bold, 0, 4);
      expect(at.hasAttributionAt(0, NamedAttribution.bold), isFalse);
      expect(at.hasAttributionAt(2, NamedAttribution.bold), isFalse);
      expect(at.hasAttributionAt(4, NamedAttribution.bold), isFalse);
    });

    test('removes attribution over sub-range, leaving remainder', () {
      // bold [0,7], remove [2,5] → bold at [0,1] and [6,7]
      final at = AttributedText('hello wo')
          .applyAttribution(NamedAttribution.bold, 0, 7)
          .removeAttribution(NamedAttribution.bold, 2, 5);
      expect(at.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      expect(at.hasAttributionAt(1, NamedAttribution.bold), isTrue);
      expect(at.hasAttributionAt(2, NamedAttribution.bold), isFalse);
      expect(at.hasAttributionAt(5, NamedAttribution.bold), isFalse);
      expect(at.hasAttributionAt(6, NamedAttribution.bold), isTrue);
      expect(at.hasAttributionAt(7, NamedAttribution.bold), isTrue);
    });

    test('removing non-existent attribution is a no-op', () {
      final at = AttributedText('hello');
      final after = at.removeAttribution(NamedAttribution.bold, 0, 4);
      expect(after, at);
    });
  });

  // ---------------------------------------------------------------------------
  // toggleAttribution
  // ---------------------------------------------------------------------------
  group('toggleAttribution', () {
    test('toggle on then off yields original', () {
      final original = AttributedText('hello');
      final toggled = original
          .toggleAttribution(NamedAttribution.bold, 0, 4)
          .toggleAttribution(NamedAttribution.bold, 0, 4);
      expect(toggled, original);
    });

    test('toggle applies when not fully covered', () {
      final at = AttributedText('hello').toggleAttribution(NamedAttribution.bold, 0, 4);
      expect(at.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      expect(at.hasAttributionAt(4, NamedAttribution.bold), isTrue);
    });

    test('toggle removes when fully covered', () {
      final at = AttributedText('hello')
          .applyAttribution(NamedAttribution.bold, 0, 4)
          .toggleAttribution(NamedAttribution.bold, 0, 4);
      expect(at.hasAttributionAt(0, NamedAttribution.bold), isFalse);
      expect(at.hasAttributionAt(4, NamedAttribution.bold), isFalse);
    });

    test('toggle on partially covered range applies to whole range', () {
      // bold only covers [0,2]; toggle [0,4] should apply bold to [0,4]
      final at = AttributedText('hello')
          .applyAttribution(NamedAttribution.bold, 0, 2)
          .toggleAttribution(NamedAttribution.bold, 0, 4);
      expect(at.hasAttributionAt(3, NamedAttribution.bold), isTrue);
      expect(at.hasAttributionAt(4, NamedAttribution.bold), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // copyText
  // ---------------------------------------------------------------------------
  group('copyText', () {
    test('copyText extracts sub-string with adjusted attributions', () {
      final at = AttributedText('hello world').applyAttribution(NamedAttribution.bold, 2, 8);
      final copy = at.copyText(2, 8);
      expect(copy.text, 'llo wo');
      // Offsets in copy are 0-based relative to the new text.
      expect(copy.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      expect(copy.hasAttributionAt(5, NamedAttribution.bold), isTrue);
    });

    test('copyText to end when end is omitted', () {
      final at = AttributedText('hello').applyAttribution(NamedAttribution.bold, 1, 4);
      final copy = at.copyText(1);
      expect(copy.text, 'ello');
      expect(copy.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      expect(copy.hasAttributionAt(3, NamedAttribution.bold), isTrue);
    });

    test('copyText clips attributions to the copied range', () {
      // bold [0,10], copy [3,7] → bold should cover entire copy [0,4]
      final at = AttributedText('hello world').applyAttribution(NamedAttribution.bold, 0, 10);
      final copy = at.copyText(3, 7);
      expect(copy.text, 'lo w');
      expect(copy.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      expect(copy.hasAttributionAt(3, NamedAttribution.bold), isTrue);
    });

    test('copyText excludes attributions outside the copied range', () {
      final at = AttributedText('hello world').applyAttribution(NamedAttribution.bold, 6, 10);
      final copy = at.copyText(0, 4);
      expect(copy.hasAttributionAt(0, NamedAttribution.bold), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // insert
  // ---------------------------------------------------------------------------
  group('insert', () {
    test('insert at start shifts all attributions', () {
      final original = AttributedText('world').applyAttribution(NamedAttribution.bold, 0, 4);
      final inserted = original.insert(0, AttributedText('hello '));
      expect(inserted.text, 'hello world');
      // bold was at [0,4] in 'world', now at [6,10] in 'hello world'
      expect(inserted.hasAttributionAt(6, NamedAttribution.bold), isTrue);
      expect(inserted.hasAttributionAt(10, NamedAttribution.bold), isTrue);
      expect(inserted.hasAttributionAt(5, NamedAttribution.bold), isFalse);
    });

    test('insert in the middle shifts attributions after insertion point', () {
      final original = AttributedText('helloworld').applyAttribution(NamedAttribution.bold, 5, 9);
      final inserted = original.insert(5, AttributedText(' '));
      expect(inserted.text, 'hello world');
      // bold was [5,9] in 'helloworld', now [6,10] in 'hello world'
      expect(inserted.hasAttributionAt(6, NamedAttribution.bold), isTrue);
      expect(inserted.hasAttributionAt(10, NamedAttribution.bold), isTrue);
      expect(inserted.hasAttributionAt(5, NamedAttribution.bold), isFalse);
    });

    test('insert at end does not shift any attributions', () {
      final original = AttributedText('hello').applyAttribution(NamedAttribution.bold, 0, 4);
      final inserted = original.insert(5, AttributedText(' world'));
      expect(inserted.text, 'hello world');
      expect(inserted.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      expect(inserted.hasAttributionAt(4, NamedAttribution.bold), isTrue);
      expect(inserted.hasAttributionAt(5, NamedAttribution.bold), isFalse);
    });

    test('inserted text carries its own attributions', () {
      final bold = AttributedText('BOLD').applyAttribution(NamedAttribution.bold, 0, 3);
      final plain = AttributedText('hello ');
      final result = plain.insert(6, bold);
      expect(result.text, 'hello BOLD');
      expect(result.hasAttributionAt(6, NamedAttribution.bold), isTrue);
      expect(result.hasAttributionAt(9, NamedAttribution.bold), isTrue);
      expect(result.hasAttributionAt(5, NamedAttribution.bold), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // delete
  // ---------------------------------------------------------------------------
  group('delete', () {
    test('delete removes text and adjusts attributions', () {
      final at = AttributedText('hello world').applyAttribution(NamedAttribution.bold, 6, 10);
      final deleted = at.delete(0, 6);
      expect(deleted.text, 'world');
      // bold was [6,10], now [0,4]
      expect(deleted.hasAttributionAt(0, NamedAttribution.bold), isTrue);
      expect(deleted.hasAttributionAt(4, NamedAttribution.bold), isTrue);
    });

    test('delete removes attributions entirely within the deleted range', () {
      final at = AttributedText('hello world').applyAttribution(NamedAttribution.bold, 2, 4);
      final deleted = at.delete(0, 6);
      expect(deleted.text, 'world');
      expect(deleted.hasAttributionAt(0, NamedAttribution.bold), isFalse);
    });

    test('delete clips attributions that straddle the boundary', () {
      // bold [1,7], delete [3,5] → bold should cover [1,2] and [3,5] in new text
      final at = AttributedText('hello world').applyAttribution(NamedAttribution.bold, 1, 7);
      final deleted = at.delete(3, 5);
      expect(deleted.text, 'hel world');
      // Offsets [1,2] should still be bold (before deletion point)
      expect(deleted.hasAttributionAt(1, NamedAttribution.bold), isTrue);
      expect(deleted.hasAttributionAt(2, NamedAttribution.bold), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // replaceSub
  // ---------------------------------------------------------------------------
  group('replaceSub', () {
    test('replaces text range with new attributed text', () {
      final at = AttributedText('hello world').applyAttribution(NamedAttribution.bold, 6, 10);
      final replacement = AttributedText('Dart');
      final result = at.replaceSub(6, 10, replacement);
      expect(result.text, 'hello Dart');
      // The original bold span is gone; no bold in result (replacement has none)
      expect(result.hasAttributionAt(6, NamedAttribution.bold), isFalse);
    });

    test('replacement carries its own attributions', () {
      final at = AttributedText('hello world');
      final replacement = AttributedText('Dart').applyAttribution(NamedAttribution.bold, 0, 3);
      final result = at.replaceSub(6, 10, replacement);
      expect(result.text, 'hello Dart');
      expect(result.hasAttributionAt(6, NamedAttribution.bold), isTrue);
      expect(result.hasAttributionAt(9, NamedAttribution.bold), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Equality and toString
  // ---------------------------------------------------------------------------
  group('equality and toString', () {
    test('two AttributedTexts with same text and markers are equal', () {
      final a = AttributedText('hello').applyAttribution(NamedAttribution.bold, 0, 4);
      final b = AttributedText('hello').applyAttribution(NamedAttribution.bold, 0, 4);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different text means not equal', () {
      final a = AttributedText('hello');
      final b = AttributedText('world');
      expect(a, isNot(b));
    });

    test('different markers means not equal', () {
      final a = AttributedText('hello').applyAttribution(NamedAttribution.bold, 0, 2);
      final b = AttributedText('hello').applyAttribution(NamedAttribution.bold, 0, 4);
      expect(a, isNot(b));
    });

    test('toString includes text content', () {
      final at = AttributedText('hello');
      expect(at.toString(), contains('hello'));
    });
  });
}
