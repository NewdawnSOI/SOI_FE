/// 회원가입 흐름에서 국가별 전화번호를 서버 로컬 형식과 Firebase E.164 형식으로 정규화합니다.
enum RegisterPhoneValidationError {
  invalidKr('register.phone_invalid_kr'),
  invalidUs('register.phone_invalid_us'),
  invalidMx('register.phone_invalid_mx');

  const RegisterPhoneValidationError(this.translationKey);

  final String translationKey;
}

/// 회원가입 전화번호 입력을 국가별 규칙으로 정규화하고 검증합니다.
class RegisterPhoneNumberService {
  /// 사용자 입력을 서버 API에 저장할 로컬 번호 형식으로 정규화합니다.
  static String formatLocalPhone({
    required String rawValue,
    required String countryCode,
  }) {
    final digitsOnly = rawValue.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return '';
    }

    switch (countryCode) {
      case 'KR':
        var normalized = digitsOnly;
        if (normalized.startsWith('82') && normalized.length > 10) {
          normalized = normalized.substring(2);
        }
        return normalized.startsWith('0') ? normalized : '0$normalized';
      case 'US':
        var normalized = digitsOnly;
        if (normalized.startsWith('1') && normalized.length > 10) {
          normalized = normalized.substring(1);
        }
        return normalized;
      case 'MX':
        var normalized = digitsOnly;
        if (normalized.startsWith('52') && normalized.length > 10) {
          normalized = normalized.substring(2);
        }
        return normalized;
      default:
        return digitsOnly;
    }
  }

  /// 사용자 입력을 Firebase 전화번호 인증용 E.164 형식으로 정규화합니다.
  static String formatE164Phone({
    required String rawValue,
    required String countryCode,
  }) {
    final localPhone = formatLocalPhone(
      rawValue: rawValue,
      countryCode: countryCode,
    );
    if (localPhone.isEmpty) {
      return '';
    }

    switch (countryCode) {
      case 'KR':
        final e164Digits = localPhone.startsWith('0')
            ? localPhone.substring(1)
            : localPhone;
        return '+82$e164Digits';
      case 'US':
        return '+1$localPhone';
      case 'MX':
        return '+52$localPhone';
      default:
        return localPhone.startsWith('+') ? localPhone : '+$localPhone';
    }
  }

  /// 선택한 국가 기준으로 회원가입에 사용할 수 있는 전화번호인지 판별합니다.
  static RegisterPhoneValidationError? validatePhone({
    required String rawValue,
    required String countryCode,
  }) {
    final localPhone = formatLocalPhone(
      rawValue: rawValue,
      countryCode: countryCode,
    );
    if (localPhone.isEmpty) {
      return null;
    }

    switch (countryCode) {
      case 'KR':
        final isValidKrMobile =
            localPhone.startsWith('0') &&
            localPhone.length >= 10 &&
            localPhone.length <= 11;
        return isValidKrMobile ? null : RegisterPhoneValidationError.invalidKr;
      case 'US':
        return localPhone.length == 10
            ? null
            : RegisterPhoneValidationError.invalidUs;
      case 'MX':
        return localPhone.length == 10
            ? null
            : RegisterPhoneValidationError.invalidMx;
      default:
        return null;
    }
  }

  /// 입력 필드가 국가 코드 포함 번호 붙여넣기도 무리 없이 받을 수 있게 자리수 상한을 제공합니다.
  static int maxInputLength({required String countryCode}) {
    switch (countryCode) {
      case 'KR':
        return 12;
      case 'US':
        return 11;
      case 'MX':
        return 12;
      default:
        return 14;
    }
  }
}
