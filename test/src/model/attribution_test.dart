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

  group('FontFamilyAttribution', () {
    const familyA = 'Roboto';
    const familyB = 'Merriweather';

    test('id is always "fontFamily"', () {
      expect(const FontFamilyAttribution(familyA).id, 'fontFamily');
      expect(const FontFamilyAttribution(familyB).id, 'fontFamily');
    });

    test('equality is based on fontFamily', () {
      expect(
        const FontFamilyAttribution(familyA),
        const FontFamilyAttribution(familyA),
      );
      expect(
        const FontFamilyAttribution(familyA),
        isNot(const FontFamilyAttribution(familyB)),
      );
    });

    test('hashCode is consistent with equality', () {
      expect(
        const FontFamilyAttribution(familyA).hashCode,
        const FontFamilyAttribution(familyA).hashCode,
      );
      expect(
        const FontFamilyAttribution(familyA).hashCode,
        isNot(const FontFamilyAttribution(familyB).hashCode),
      );
    });

    test('canMergeWith returns true for same fontFamily', () {
      expect(
        const FontFamilyAttribution(familyA).canMergeWith(const FontFamilyAttribution(familyA)),
        isTrue,
      );
    });

    test('canMergeWith returns false for different fontFamily', () {
      expect(
        const FontFamilyAttribution(familyA).canMergeWith(const FontFamilyAttribution(familyB)),
        isFalse,
      );
    });

    test('canMergeWith returns false for different attribution type', () {
      expect(
        const FontFamilyAttribution(familyA).canMergeWith(NamedAttribution.bold),
        isFalse,
      );
    });

    test('toString includes the fontFamily value', () {
      expect(
        const FontFamilyAttribution(familyA).toString(),
        contains(familyA),
      );
    });
  });

  group('FontSizeAttribution', () {
    const sizeA = 16.0;
    const sizeB = 24.0;

    test('id is always "fontSize"', () {
      expect(const FontSizeAttribution(sizeA).id, 'fontSize');
      expect(const FontSizeAttribution(sizeB).id, 'fontSize');
    });

    test('equality is based on fontSize', () {
      expect(
        const FontSizeAttribution(sizeA),
        const FontSizeAttribution(sizeA),
      );
      expect(
        const FontSizeAttribution(sizeA),
        isNot(const FontSizeAttribution(sizeB)),
      );
    });

    test('hashCode is consistent with equality', () {
      expect(
        const FontSizeAttribution(sizeA).hashCode,
        const FontSizeAttribution(sizeA).hashCode,
      );
      expect(
        const FontSizeAttribution(sizeA).hashCode,
        isNot(const FontSizeAttribution(sizeB).hashCode),
      );
    });

    test('canMergeWith returns true for same fontSize', () {
      expect(
        const FontSizeAttribution(sizeA).canMergeWith(const FontSizeAttribution(sizeA)),
        isTrue,
      );
    });

    test('canMergeWith returns false for different fontSize', () {
      expect(
        const FontSizeAttribution(sizeA).canMergeWith(const FontSizeAttribution(sizeB)),
        isFalse,
      );
    });

    test('canMergeWith returns false for different attribution type', () {
      expect(
        const FontSizeAttribution(sizeA).canMergeWith(NamedAttribution.bold),
        isFalse,
      );
    });

    test('toString includes the fontSize value', () {
      expect(const FontSizeAttribution(sizeA).toString(), contains('16'));
    });
  });

  group('TextColorAttribution', () {
    const colorA = 0xFF0000FF; // opaque blue
    const colorB = 0xFFFF0000; // opaque red

    test('id is always "textColor"', () {
      expect(const TextColorAttribution(colorA).id, 'textColor');
      expect(const TextColorAttribution(colorB).id, 'textColor');
    });

    test('equality is based on colorValue', () {
      expect(
        const TextColorAttribution(colorA),
        const TextColorAttribution(colorA),
      );
      expect(
        const TextColorAttribution(colorA),
        isNot(const TextColorAttribution(colorB)),
      );
    });

    test('hashCode is consistent with equality', () {
      expect(
        const TextColorAttribution(colorA).hashCode,
        const TextColorAttribution(colorA).hashCode,
      );
      expect(
        const TextColorAttribution(colorA).hashCode,
        isNot(const TextColorAttribution(colorB).hashCode),
      );
    });

    test('canMergeWith returns true for same colorValue', () {
      expect(
        const TextColorAttribution(colorA).canMergeWith(const TextColorAttribution(colorA)),
        isTrue,
      );
    });

    test('canMergeWith returns false for different colorValue', () {
      expect(
        const TextColorAttribution(colorA).canMergeWith(const TextColorAttribution(colorB)),
        isFalse,
      );
    });

    test('canMergeWith returns false for different attribution type', () {
      expect(
        const TextColorAttribution(colorA).canMergeWith(NamedAttribution.bold),
        isFalse,
      );
    });

    test('toString includes the colorValue', () {
      // 0xFF0000FF decimal is 4278190335
      expect(const TextColorAttribution(colorA).toString(), contains('4278190335'));
    });
  });

  group('BackgroundColorAttribution', () {
    const colorA = 0xFFFFFF00; // opaque yellow
    const colorB = 0xFF00FF00; // opaque green

    test('id is always "backgroundColor"', () {
      expect(const BackgroundColorAttribution(colorA).id, 'backgroundColor');
      expect(const BackgroundColorAttribution(colorB).id, 'backgroundColor');
    });

    test('equality is based on colorValue', () {
      expect(
        const BackgroundColorAttribution(colorA),
        const BackgroundColorAttribution(colorA),
      );
      expect(
        const BackgroundColorAttribution(colorA),
        isNot(const BackgroundColorAttribution(colorB)),
      );
    });

    test('hashCode is consistent with equality', () {
      expect(
        const BackgroundColorAttribution(colorA).hashCode,
        const BackgroundColorAttribution(colorA).hashCode,
      );
      expect(
        const BackgroundColorAttribution(colorA).hashCode,
        isNot(const BackgroundColorAttribution(colorB).hashCode),
      );
    });

    test('canMergeWith returns true for same colorValue', () {
      expect(
        const BackgroundColorAttribution(colorA)
            .canMergeWith(const BackgroundColorAttribution(colorA)),
        isTrue,
      );
    });

    test('canMergeWith returns false for different colorValue', () {
      expect(
        const BackgroundColorAttribution(colorA)
            .canMergeWith(const BackgroundColorAttribution(colorB)),
        isFalse,
      );
    });

    test('canMergeWith returns false for different attribution type', () {
      expect(
        const BackgroundColorAttribution(colorA).canMergeWith(NamedAttribution.bold),
        isFalse,
      );
    });

    test('canMergeWith returns false for TextColorAttribution (cross-type)', () {
      expect(
        const BackgroundColorAttribution(colorA).canMergeWith(const TextColorAttribution(colorA)),
        isFalse,
      );
    });

    test('toString includes the colorValue', () {
      // 0xFFFFFF00 decimal is 4294967040
      expect(const BackgroundColorAttribution(colorA).toString(), contains('4294967040'));
    });
  });
}
