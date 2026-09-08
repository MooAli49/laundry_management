import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/utils/phone_utils.dart';

void main() {
  group('PhoneUtils', () {
    test('normalizePhoneNumber trims leading and trailing whitespace', () {
      expect(PhoneUtils.normalizePhoneNumber('  01012345678  '), equals('01012345678'));
      expect(PhoneUtils.normalizePhoneNumber('\t01123456789\n'), equals('01123456789'));
    });

    test('normalizePhoneNumber converts Eastern Arabic-Indic numerals (٠-٩) to Western (0-9)', () {
      expect(
        PhoneUtils.normalizePhoneNumber('٠١٠١٢٣٤٥٦٧٨'),
        equals('01012345678'),
      );
      expect(
        PhoneUtils.normalizePhoneNumber('٠١٢٣٤٥٦٧٨٩'),
        equals('0123456789'),
      );
      expect(
        PhoneUtils.normalizePhoneNumber('  ٠١٥٩٩٩٨٨٨٧٧  '),
        equals('01599988877'),
      );
    });

    group('isValidCustomerPhone (Egyptian Mobile Rule)', () {
      test('validates valid Egyptian mobile numbers (010, 011, 012, 015)', () {
        expect(PhoneUtils.isValidCustomerPhone('01012345678'), isTrue);
        expect(PhoneUtils.isValidCustomerPhone('01112345678'), isTrue);
        expect(PhoneUtils.isValidCustomerPhone('01212345678'), isTrue);
        expect(PhoneUtils.isValidCustomerPhone('01512345678'), isTrue);
      });

      test('validates valid Eastern Arabic-Indic numerals', () {
        expect(PhoneUtils.isValidCustomerPhone('٠١٠١٢٣٤٥٦٧٨'), isTrue);
        expect(PhoneUtils.isValidCustomerPhone('  ٠١١١٢٣٤٥٦٧٨  '), isTrue);
      });

      test('rejects numbers with wrong length, invalid prefixes, or international codes', () {
        // Wrong length
        expect(PhoneUtils.isValidCustomerPhone('0101234567'), isFalse);
        expect(PhoneUtils.isValidCustomerPhone('010123456789'), isFalse);

        // Invalid Egyptian mobile prefixes
        expect(PhoneUtils.isValidCustomerPhone('01312345678'), isFalse);
        expect(PhoneUtils.isValidCustomerPhone('01412345678'), isFalse);
        expect(PhoneUtils.isValidCustomerPhone('01612345678'), isFalse);
        expect(PhoneUtils.isValidCustomerPhone('02012345678'), isFalse);

        // International prefixes not accepted
        expect(PhoneUtils.isValidCustomerPhone('+201012345678'), isFalse);
        expect(PhoneUtils.isValidCustomerPhone('00201012345678'), isFalse);

        // Non-digits & empty
        expect(PhoneUtils.isValidCustomerPhone('abc'), isFalse);
        expect(PhoneUtils.isValidCustomerPhone(''), isFalse);
        expect(PhoneUtils.isValidCustomerPhone('   '), isFalse);
        expect(PhoneUtils.isValidCustomerPhone('\t\n'), isFalse);
      });
    });
  });
}
