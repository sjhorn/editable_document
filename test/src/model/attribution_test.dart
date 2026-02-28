import 'package:editable_document/src/model/attribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NamedAttribution', () {
    test('built-in constants have correct ids', () {
      expect(NamedAttribution.bold.id, 'bold');
      expect(NamedAttribution.italics.id, 'italics');
      expect(NamedAttribution.underline.id, 'underline');
      expect(NamedAttribution.strikethrough.id, 'strikethrough');
      expect(NamedAttribution.code.id, 'code');
    });

    test('equality is based on id', () {
      expect(NamedAttribution.bold, NamedAttribution.bold);
      expect(const NamedAttribution('bold'), const NamedAttribution('bold'));
      expect(NamedAttribution.bold, isNot(NamedAttribution.italics));
    });

    test('hashCode is consistent with equality', () {
      expect(
        const NamedAttribution('bold').hashCode,
        const NamedAttribution('bold').hashCode,
      );
      expect(
        NamedAttribution.bold.hashCode,
        isNot(NamedAttribution.italics.hashCode),
      );
    });

    test('canMergeWith returns true for same attribution', () {
      expect(NamedAttribution.bold.canMergeWith(NamedAttribution.bold), isTrue);
      expect(
        const NamedAttribution('bold').canMergeWith(const NamedAttribution('bold')),
        isTrue,
      );
    });

    test('canMergeWith returns false for different attribution', () {
      expect(NamedAttribution.bold.canMergeWith(NamedAttribution.italics), isFalse);
    });

    test('toString includes the id', () {
      expect(NamedAttribution.bold.toString(), contains('bold'));
    });
  });

  group('LinkAttribution', () {
    final urlA = Uri.parse('https://example.com');
    final urlB = Uri.parse('https://other.com');

    test('id is always "link"', () {
      expect(LinkAttribution(urlA).id, 'link');
      expect(LinkAttribution(urlB).id, 'link');
    });

    test('equality is based on url', () {
      expect(LinkAttribution(urlA), LinkAttribution(urlA));
      expect(LinkAttribution(urlA), isNot(LinkAttribution(urlB)));
    });

    test('hashCode is consistent with equality', () {
      expect(LinkAttribution(urlA).hashCode, LinkAttribution(urlA).hashCode);
      expect(LinkAttribution(urlA).hashCode, isNot(LinkAttribution(urlB).hashCode));
    });

    test('canMergeWith returns true for same url', () {
      expect(LinkAttribution(urlA).canMergeWith(LinkAttribution(urlA)), isTrue);
    });

    test('canMergeWith returns false for different url', () {
      expect(LinkAttribution(urlA).canMergeWith(LinkAttribution(urlB)), isFalse);
    });

    test('canMergeWith returns false for non-link attribution', () {
      expect(LinkAttribution(urlA).canMergeWith(NamedAttribution.bold), isFalse);
    });

    test('toString includes the url', () {
      expect(LinkAttribution(urlA).toString(), contains('example.com'));
    });
  });
}
