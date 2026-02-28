/// Span-based attributed text model for the editable_document package.
///
/// This file provides [SpanMarker], [SpanMarkerType], [AttributionSpan], and
/// [AttributedText] — the core immutable rich-text value type used throughout
/// the model layer.
library;

import 'attribution.dart';

// ---------------------------------------------------------------------------
// SpanMarkerType
// ---------------------------------------------------------------------------

/// Whether a [SpanMarker] opens or closes an attribution span.
enum SpanMarkerType {
  /// The marker opens a new attribution span.
  start,

  /// The marker closes an existing attribution span.
  end,
}

// ---------------------------------------------------------------------------
// SpanMarker
// ---------------------------------------------------------------------------

/// A single boundary point of an attribution span within [AttributedText].
///
/// Markers are kept sorted inside [AttributedText] so that all span queries
/// can walk the list in a single pass. The sort order is:
///
/// 1. [offset] ascending.
/// 2. At the same offset, [SpanMarkerType.start] before [SpanMarkerType.end].
class SpanMarker implements Comparable<SpanMarker> {
  /// Creates a [SpanMarker].
  const SpanMarker({
    required this.attribution,
    required this.offset,
    required this.markerType,
  });

  /// The [Attribution] this marker belongs to.
  final Attribution attribution;

  /// The character offset within the text at which this marker sits.
  final int offset;

  /// Whether this marker opens or closes a span.
  final SpanMarkerType markerType;

  /// Returns a copy with the given fields replaced.
  SpanMarker copyWith({
    Attribution? attribution,
    int? offset,
    SpanMarkerType? markerType,
  }) =>
      SpanMarker(
        attribution: attribution ?? this.attribution,
        offset: offset ?? this.offset,
        markerType: markerType ?? this.markerType,
      );

  @override
  int compareTo(SpanMarker other) {
    final byOffset = offset.compareTo(other.offset);
    if (byOffset != 0) return byOffset;
    // Start markers sort before end markers at the same offset.
    if (markerType == other.markerType) return 0;
    return markerType == SpanMarkerType.start ? -1 : 1;
  }

  @override
  bool operator ==(Object other) =>
      other is SpanMarker &&
      other.attribution == attribution &&
      other.offset == offset &&
      other.markerType == markerType;

  @override
  int get hashCode => Object.hash(attribution, offset, markerType);

  @override
  String toString() => 'SpanMarker($attribution, $offset, $markerType)';
}

// ---------------------------------------------------------------------------
// AttributionSpan
// ---------------------------------------------------------------------------

/// A fully resolved attribution span with inclusive [start] and [end] offsets.
class AttributionSpan {
  /// Creates an [AttributionSpan].
  const AttributionSpan({
    required this.attribution,
    required this.start,
    required this.end,
  });

  /// The [Attribution] applied over this span.
  final Attribution attribution;

  /// The first character offset included in this span.
  final int start;

  /// The last character offset included in this span (inclusive).
  final int end;

  @override
  bool operator ==(Object other) =>
      other is AttributionSpan &&
      other.attribution == attribution &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(attribution, start, end);

  @override
  String toString() => 'AttributionSpan($attribution, $start..$end)';
}

// ---------------------------------------------------------------------------
// AttributedText
// ---------------------------------------------------------------------------

/// Immutable rich-text value type that combines a [String] with a sorted list
/// of [SpanMarker] pairs.
///
/// All mutation methods ([applyAttribution], [removeAttribution],
/// [toggleAttribution], [copyText], [insert], [delete], [replaceSub]) return
/// a **new** [AttributedText] instance — the receiver is never modified.
///
/// ### Span invariants
///
/// The internal markers list is always kept in [SpanMarker.compareTo] order.
/// Adjacent spans that carry the same attribution and satisfy
/// [Attribution.canMergeWith] are automatically collapsed so that at most one
/// contiguous span exists for each attribution kind at any point in the text.
///
/// ### Example
///
/// ```dart
/// final text = AttributedText('hello world')
///     .applyAttribution(NamedAttribution.bold, 0, 4);
/// assert(text.hasAttributionAt(2, NamedAttribution.bold));
/// assert(!text.hasAttributionAt(5, NamedAttribution.bold));
/// ```
class AttributedText {
  /// Creates an [AttributedText] with optional [text] and [markers].
  ///
  /// If [markers] is omitted the text carries no attributions. If supplied,
  /// the list is sorted and normalised internally.
  AttributedText([String text = '', List<SpanMarker>? markers])
      : text = text,
        _markers = _normalise(markers ?? const []);

  /// The plain-text content.
  final String text;

  /// Sorted, normalised span markers.
  final List<SpanMarker> _markers;

  /// The number of characters in [text].
  int get length => text.length;

  // -------------------------------------------------------------------------
  // Attribution queries
  // -------------------------------------------------------------------------

  /// Returns every [Attribution] that covers [offset].
  ///
  /// The offset is inclusive. Returns an empty set when no attribution covers
  /// the position.
  Set<Attribution> getAttributionsAt(int offset) {
    final result = <Attribution>{};
    for (final span in _allSpans()) {
      if (span.start <= offset && offset <= span.end) {
        result.add(span.attribution);
      }
    }
    return result;
  }

  /// Returns `true` when [attribution] covers [offset].
  bool hasAttributionAt(int offset, Attribution attribution) {
    for (final span in _allSpans()) {
      if (span.attribution == attribution && span.start <= offset && offset <= span.end) {
        return true;
      }
    }
    return false;
  }

  /// Returns the [AttributionSpan] for [attribution] that contains [offset],
  /// or `null` when [attribution] is not present at [offset].
  AttributionSpan? getAttributionSpanAt(int offset, Attribution attribution) {
    for (final span in _allSpans()) {
      if (span.attribution == attribution && span.start <= offset && offset <= span.end) {
        return span;
      }
    }
    return null;
  }

  /// Returns all [AttributionSpan]s that overlap with the range [start]..[end].
  ///
  /// A span overlaps the range when it starts at or before [end] and ends at
  /// or after [start].
  Iterable<AttributionSpan> getAttributionSpansInRange(int start, int end) {
    return _allSpans().where((span) => span.start <= end && span.end >= start);
  }

  // -------------------------------------------------------------------------
  // Attribution mutation (immutable — returns new instance)
  // -------------------------------------------------------------------------

  /// Returns a new [AttributedText] with [attribution] applied over
  /// [[start]..[end]] (both inclusive).
  ///
  /// Overlapping and adjacent spans carrying the same attribution are merged
  /// automatically.
  AttributedText applyAttribution(Attribution attribution, int start, int end) {
    assert(start <= end, 'start must be <= end');
    final updated = List<SpanMarker>.from(_markers)
      ..add(SpanMarker(attribution: attribution, offset: start, markerType: SpanMarkerType.start))
      ..add(SpanMarker(attribution: attribution, offset: end, markerType: SpanMarkerType.end));
    return AttributedText(text, _normalise(updated));
  }

  /// Returns a new [AttributedText] with [attribution] removed from
  /// [[start]..[end]] (both inclusive).
  ///
  /// Portions of existing spans outside the removed range are preserved.
  AttributedText removeAttribution(Attribution attribution, int start, int end) {
    assert(start <= end, 'start must be <= end');
    // Collect current spans for this attribution.
    final existing = _allSpans().where((s) => s.attribution == attribution).toList();
    if (existing.isEmpty) return this;

    // Remove all markers for this attribution then re-add the surviving portions.
    final updated = _markers.where((m) => m.attribution != attribution).toList();

    for (final span in existing) {
      // Portion before the removal range.
      if (span.start < start) {
        final newEnd = start - 1;
        updated
          ..add(SpanMarker(
            attribution: attribution,
            offset: span.start,
            markerType: SpanMarkerType.start,
          ))
          ..add(SpanMarker(
            attribution: attribution,
            offset: newEnd,
            markerType: SpanMarkerType.end,
          ));
      }
      // Portion after the removal range.
      if (span.end > end) {
        final newStart = end + 1;
        updated
          ..add(SpanMarker(
            attribution: attribution,
            offset: newStart,
            markerType: SpanMarkerType.start,
          ))
          ..add(SpanMarker(
            attribution: attribution,
            offset: span.end,
            markerType: SpanMarkerType.end,
          ));
      }
    }

    return AttributedText(text, _normalise(updated));
  }

  /// Returns a new [AttributedText] with [attribution] toggled over
  /// [[start]..[end]].
  ///
  /// If every offset in the range already carries [attribution] the attribution
  /// is removed; otherwise it is applied to the entire range.
  AttributedText toggleAttribution(Attribution attribution, int start, int end) {
    // Check whether every offset in [start, end] is covered.
    final fullyCovered = _isFullyCovered(attribution, start, end);
    if (fullyCovered) {
      return removeAttribution(attribution, start, end);
    } else {
      return applyAttribution(attribution, start, end);
    }
  }

  // -------------------------------------------------------------------------
  // Text mutation (immutable — returns new instance)
  // -------------------------------------------------------------------------

  /// Returns a sub-range of this [AttributedText] from [start] to [end]
  /// (exclusive), with attributions clipped and re-indexed to the new text.
  ///
  /// When [end] is omitted the copy extends to the end of the text.
  AttributedText copyText(int start, [int? end]) {
    final to = end ?? length;
    final newText = text.substring(start, to);
    final newMarkers = <SpanMarker>[];

    for (final span in _allSpans()) {
      // Skip spans that don't overlap the copied range.
      if (span.end < start || span.start >= to) continue;

      // Clip span to the copied range.
      final clippedStart = span.start < start ? start : span.start;
      final clippedEnd = span.end >= to ? to - 1 : span.end;

      newMarkers
        ..add(SpanMarker(
          attribution: span.attribution,
          offset: clippedStart - start,
          markerType: SpanMarkerType.start,
        ))
        ..add(SpanMarker(
          attribution: span.attribution,
          offset: clippedEnd - start,
          markerType: SpanMarkerType.end,
        ));
    }

    return AttributedText(newText, _normalise(newMarkers));
  }

  /// Returns a new [AttributedText] with [other] inserted at [offset].
  ///
  /// Attributions in [this] that start at or after [offset] are shifted right
  /// by `other.length`. Attributions in [other] are shifted right by [offset]
  /// and merged into the result.
  AttributedText insert(int offset, AttributedText other) {
    final newText = text.substring(0, offset) + other.text + text.substring(offset);
    final insertLen = other.length;

    // Shift existing markers at or after the insertion offset.
    final shiftedMarkers = _markers.map((m) {
      if (m.offset >= offset) {
        return m.copyWith(offset: m.offset + insertLen);
      }
      return m;
    }).toList();

    // Shift the inserted text's markers to their new absolute positions.
    final insertedMarkers = other._markers.map((m) {
      return m.copyWith(offset: m.offset + offset);
    }).toList();

    return AttributedText(newText, _normalise([...shiftedMarkers, ...insertedMarkers]));
  }

  /// Returns a new [AttributedText] with the characters in [[start]..[end])
  /// (exclusive end) removed.
  ///
  /// Attributions entirely within the deleted range are dropped. Attributions
  /// that straddle the boundary are clipped. Attributions after the range are
  /// shifted left by `end - start`.
  AttributedText delete(int start, int end) {
    assert(start <= end, 'start must be <= end');
    final deleteLen = end - start;
    final newText = text.substring(0, start) + text.substring(end);
    final newMarkers = <SpanMarker>[];

    for (final span in _allSpans()) {
      // Completely inside deleted range — drop.
      if (span.start >= start && span.end < end) continue;

      // Completely after deleted range — shift left.
      if (span.start >= end) {
        newMarkers
          ..add(SpanMarker(
            attribution: span.attribution,
            offset: span.start - deleteLen,
            markerType: SpanMarkerType.start,
          ))
          ..add(SpanMarker(
            attribution: span.attribution,
            offset: span.end - deleteLen,
            markerType: SpanMarkerType.end,
          ));
        continue;
      }

      // Completely before deleted range — keep as-is.
      if (span.end < start) {
        newMarkers
          ..add(SpanMarker(
            attribution: span.attribution,
            offset: span.start,
            markerType: SpanMarkerType.start,
          ))
          ..add(SpanMarker(
            attribution: span.attribution,
            offset: span.end,
            markerType: SpanMarkerType.end,
          ));
        continue;
      }

      // Straddles the boundary — clip.
      final newStart = span.start < start ? span.start : start;
      int newEnd;
      if (span.end >= end) {
        // Extends past the deleted range — shift tail.
        newEnd = span.end - deleteLen;
      } else {
        // Ends inside the deleted range — clip to just before deletion.
        newEnd = start - 1;
      }

      if (newStart <= newEnd) {
        newMarkers
          ..add(SpanMarker(
            attribution: span.attribution,
            offset: newStart,
            markerType: SpanMarkerType.start,
          ))
          ..add(SpanMarker(
            attribution: span.attribution,
            offset: newEnd,
            markerType: SpanMarkerType.end,
          ));
      }
    }

    return AttributedText(newText, _normalise(newMarkers));
  }

  /// Replaces the range [[start]..[end]] (both inclusive) with [replacement].
  ///
  /// This is equivalent to `delete(start, end + 1).insert(start, replacement)`.
  AttributedText replaceSub(int start, int end, AttributedText replacement) {
    return delete(start, end + 1).insert(start, replacement);
  }

  // -------------------------------------------------------------------------
  // Equality and debugging
  // -------------------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (other is! AttributedText) return false;
    if (other.text != text) return false;
    if (other._markers.length != _markers.length) return false;
    for (var i = 0; i < _markers.length; i++) {
      if (other._markers[i] != _markers[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(text, Object.hashAll(_markers));

  @override
  String toString() => 'AttributedText("$text", markers: $_markers)';

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Converts the flat [markers] list into resolved [AttributionSpan]s.
  ///
  /// Uses a simple stack-per-attribution-key approach.
  List<AttributionSpan> _allSpans() {
    final spans = <AttributionSpan>[];
    // Map from attribution → stack of start offsets.
    final openStarts = <Attribution, List<int>>{};

    for (final marker in _markers) {
      if (marker.markerType == SpanMarkerType.start) {
        openStarts.putIfAbsent(marker.attribution, () => []).add(marker.offset);
      } else {
        final starts = openStarts[marker.attribution];
        if (starts != null && starts.isNotEmpty) {
          final startOffset = starts.removeLast();
          spans.add(AttributionSpan(
            attribution: marker.attribution,
            start: startOffset,
            end: marker.offset,
          ));
        }
      }
    }

    return spans;
  }

  /// Returns `true` when every integer in [[start]..[end]] is covered by
  /// [attribution].
  bool _isFullyCovered(Attribution attribution, int start, int end) {
    if (start > end) return true;
    final spans = _allSpans().where((s) => s.attribution == attribution).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    var covered = start;
    for (final span in spans) {
      if (span.start > covered) break;
      if (span.end >= covered) covered = span.end + 1;
      if (covered > end) return true;
    }
    return false;
  }

  /// Normalises a list of [SpanMarker]s:
  ///
  /// 1. Sorts by [SpanMarker.compareTo].
  /// 2. Resolves any overlapping or adjacent spans that satisfy
  ///    [Attribution.canMergeWith] into a single merged span.
  static List<SpanMarker> _normalise(List<SpanMarker> markers) {
    if (markers.isEmpty) return const [];

    // Sort first so we can do a linear merge pass.
    final sorted = List<SpanMarker>.from(markers)..sort();

    // Convert to spans, merge, convert back to markers.
    final spans = _spansFromMarkers(sorted);
    final merged = _mergeSpans(spans);
    return _markersFromSpans(merged)..sort();
  }

  /// Converts a sorted flat marker list into [AttributionSpan]s.
  static List<AttributionSpan> _spansFromMarkers(List<SpanMarker> sorted) {
    final spans = <AttributionSpan>[];
    final openStarts = <Attribution, List<int>>{};

    for (final marker in sorted) {
      if (marker.markerType == SpanMarkerType.start) {
        openStarts.putIfAbsent(marker.attribution, () => []).add(marker.offset);
      } else {
        final starts = openStarts[marker.attribution];
        if (starts != null && starts.isNotEmpty) {
          final startOffset = starts.removeLast();
          spans.add(AttributionSpan(
            attribution: marker.attribution,
            start: startOffset,
            end: marker.offset,
          ));
        }
      }
    }
    return spans;
  }

  /// Merges adjacent and overlapping spans when [Attribution.canMergeWith]
  /// permits.
  static List<AttributionSpan> _mergeSpans(List<AttributionSpan> spans) {
    if (spans.isEmpty) return const [];

    // Group spans by attribution identity.
    final groups = <Attribution, List<AttributionSpan>>{};
    for (final span in spans) {
      // Find an existing key that can merge.
      Attribution? key;
      for (final k in groups.keys) {
        if (k.canMergeWith(span.attribution) && span.attribution.canMergeWith(k)) {
          key = k;
          break;
        }
      }
      key ??= span.attribution;
      groups.putIfAbsent(key, () => []).add(span);
    }

    final result = <AttributionSpan>[];

    for (final entry in groups.entries) {
      final sorted = entry.value..sort((a, b) => a.start.compareTo(b.start));
      var current = sorted.first;

      for (var i = 1; i < sorted.length; i++) {
        final next = sorted[i];
        // Merge if overlapping or adjacent (gap of at most 1).
        if (next.start <= current.end + 1) {
          current = AttributionSpan(
            attribution: current.attribution,
            start: current.start,
            end: next.end > current.end ? next.end : current.end,
          );
        } else {
          result.add(current);
          current = next;
        }
      }
      result.add(current);
    }

    return result;
  }

  /// Converts [AttributionSpan]s back to a flat start/end marker list.
  static List<SpanMarker> _markersFromSpans(List<AttributionSpan> spans) {
    final markers = <SpanMarker>[];
    for (final span in spans) {
      markers
        ..add(SpanMarker(
          attribution: span.attribution,
          offset: span.start,
          markerType: SpanMarkerType.start,
        ))
        ..add(SpanMarker(
          attribution: span.attribution,
          offset: span.end,
          markerType: SpanMarkerType.end,
        ));
    }
    return markers;
  }
}
