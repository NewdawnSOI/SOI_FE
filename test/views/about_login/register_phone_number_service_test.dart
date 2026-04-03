import 'package:flutter_test/flutter_test.dart';
import 'package:soi/views/about_login_&_register/services/register_phone_number_service.dart';

void main() {
  group('RegisterPhoneNumberService', () {
    test('formats Korean numbers into local and E.164 variants', () {
      expect(
        RegisterPhoneNumberService.formatLocalPhone(
          rawValue: '821066784110',
          countryCode: 'KR',
        ),
        '01066784110',
      );
      expect(
        RegisterPhoneNumberService.formatE164Phone(
          rawValue: '01066784110',
          countryCode: 'KR',
        ),
        '+821066784110',
      );
    });

    test('formats US numbers into local and E.164 variants', () {
      expect(
        RegisterPhoneNumberService.formatLocalPhone(
          rawValue: '14155551234',
          countryCode: 'US',
        ),
        '4155551234',
      );
      expect(
        RegisterPhoneNumberService.formatE164Phone(
          rawValue: '4155551234',
          countryCode: 'US',
        ),
        '+14155551234',
      );
    });

    test('formats Mexican numbers into local and E.164 variants', () {
      expect(
        RegisterPhoneNumberService.formatLocalPhone(
          rawValue: '525512345678',
          countryCode: 'MX',
        ),
        '5512345678',
      );
      expect(
        RegisterPhoneNumberService.formatE164Phone(
          rawValue: '5512345678',
          countryCode: 'MX',
        ),
        '+525512345678',
      );
    });

    test('validates country specific phone lengths', () {
      expect(
        RegisterPhoneNumberService.validatePhone(
          rawValue: '01066784110',
          countryCode: 'KR',
        ),
        isNull,
      );
      expect(
        RegisterPhoneNumberService.validatePhone(
          rawValue: '415555123',
          countryCode: 'US',
        ),
        RegisterPhoneValidationError.invalidUs,
      );
      expect(
        RegisterPhoneNumberService.validatePhone(
          rawValue: '551234567',
          countryCode: 'MX',
        ),
        RegisterPhoneValidationError.invalidMx,
      );
    });

    test('chooses API SMS only for Korean numbers', () {
      expect(
        RegisterPhoneNumberService.usesApiSmsVerification(countryCode: 'KR'),
        isTrue,
      );
      expect(
        RegisterPhoneNumberService.usesApiSmsVerification(countryCode: 'US'),
        isFalse,
      );
      expect(
        RegisterPhoneNumberService.usesApiSmsVerification(countryCode: 'MX'),
        isFalse,
      );
    });
  });
}
