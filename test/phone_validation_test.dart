import 'package:flutter_test/flutter_test.dart';

import 'package:restep/core/utils/validators.dart';

void main() {
  group('Validators.normalizeSaudiMobile', () {
    test('normalizes accepted formats to +9665XXXXXXXX', () {
      const expected = '+966512345678';
      for (final input in [
        '512345678',
        '0512345678',
        '+966512345678',
        '966512345678',
        '00966512345678',
        '+966 51 234 5678',
        '+966-51-234-5678',
        '(051) 234 5678',
        '+9660512345678',
        '  512345678  ',
      ]) {
        expect(Validators.normalizeSaudiMobile(input), expected, reason: input);
        expect(Validators.saudiMobile(input), isNull, reason: input);
      }
    });

    test('rejects invalid numbers', () {
      for (final input in [
        '51234567', // too short
        '5123456789', // too long
        '412345678', // does not start with 5
        '0412345678',
        '+966412345678',
        '+9665123456789', // too long after +966
        '+966+966512345678', // duplicated prefix
        '+971512345678', // other country code
        '51234567a', // letters
        '5123.45678', // invalid character
        '++966512345678',
        '966',
      ]) {
        expect(Validators.normalizeSaudiMobile(input), isNull, reason: input);
        expect(
          Validators.saudiMobile(input),
          Validators.saudiMobileError,
          reason: input,
        );
      }
    });

    test('requires a value', () {
      expect(Validators.saudiMobile(''), 'Phone number is required');
      expect(Validators.saudiMobile('   '), 'Phone number is required');
      expect(Validators.saudiMobile(null), 'Phone number is required');
    });
  });
}
