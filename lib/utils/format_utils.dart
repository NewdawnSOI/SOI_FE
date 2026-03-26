import 'package:intl/intl.dart';

/// 포맷팅 관련 유틸리티 클래스
/// 날짜, 시간, 숫자 등의 표시 형식을 관리합니다.
class FormatUtils {
  /// 날짜를 안전하게 포맷팅하는 메서드
  static String formatDate(DateTime date) {
    try {
      return DateFormat('yyyy.MM.dd').format(date);
    } catch (e) {
      // Fallback 포맷팅
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// 서버 DTO가 DateTime으로 역직렬화한 값을 화면 기준 로컬 시각으로 정규화합니다.
  static DateTime? normalizeServerDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return null;
    }
    if (dateTime.isUtc) {
      return dateTime.toLocal();
    }
    return DateTime.utc(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
      dateTime.millisecond,
      dateTime.microsecond,
    ).toLocal();
  }

  /// 서버에서 받은 날짜 문자열을 로컬 시각으로 파싱해 모델 매핑에 재사용합니다.
  static DateTime? parseServerDateTime(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw.isUtc ? raw.toLocal() : raw;
    }
    if (raw is! String || raw.isEmpty) {
      return null;
    }

    final normalized = _hasTimeZone(raw) ? raw : '${raw}Z';
    return DateTime.tryParse(normalized)?.toLocal();
  }

  /// 모델이 서버 호환 JSON을 만들 수 있도록 시간을 UTC ISO-8601 문자열로 직렬화합니다.
  static String? serializeServerDateTime(DateTime? dateTime) {
    return dateTime?.toUtc().toIso8601String();
  }

  /// 현재 시간을 기준으로 경과 시간을 동적으로 포맷팅
  /// 예) "방금 전", "5분 전", "2시간 전", "3일 전", "2025.08.20"
  ///
  /// Parameters:
  /// - [dateTime]: 포맷팅할 DateTime 객체입니다.
  ///
  /// Returns:
  /// - [String]: 현재 시간과의 차이에 따라 동적으로 포맷팅된 문자열을 반환합니다.
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // 음수인 경우 (미래 시간) 처리
    if (difference.isNegative) {
      return formatDate(dateTime);
    }

    final seconds = difference.inSeconds;
    final minutes = difference.inMinutes;
    final hours = difference.inHours;
    final days = difference.inDays;

    if (seconds < 60) {
      return '방금 전';
    } else if (minutes < 60) {
      return '$minutes분 전';
    } else if (hours < 24) {
      return '$hours시간 전';
    } else if (days < 7) {
      return '$days일 전';
    } else {
      // 7일 이상 지난 경우 날짜 형식으로 표시
      return formatDate(dateTime);
    }
  }

  /// 날짜 문자열에 timezone 정보가 포함됐는지 판별해 서버 파싱 규칙을 안정화합니다.
  static bool _hasTimeZone(String value) {
    return RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
  }
}
