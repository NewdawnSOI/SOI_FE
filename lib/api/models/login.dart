import 'package:soi_api_client/api.dart';

import '../api_exception.dart';

/// 로그인/토큰 재발급 응답을 앱 세션 상태로 정규화합니다.
/// access/refresh 토큰과 만료 정보를 한 형태로 보관해 저장, 복원, 재발급에 함께 사용합니다.
class LoginSession {
  LoginSession({
    required String accessToken,
    String? refreshToken,
    this.accessTokenExpiresInMs,
    this.refreshTokenExpiresInMs,
    int? issuedAtEpochMs,
  }) : accessToken = _normalizeRequiredToken(accessToken),
       refreshToken = _normalizeOptionalToken(refreshToken),
       issuedAtEpochMs =
           issuedAtEpochMs ?? DateTime.now().millisecondsSinceEpoch;

  final String accessToken;
  final String? refreshToken;
  final int? accessTokenExpiresInMs;
  final int? refreshTokenExpiresInMs;
  final int issuedAtEpochMs;

  /// 생성된 로그인 DTO를 앱 세션 모델로 변환합니다.
  factory LoginSession.fromDto(LoginRespDto dto, {int? issuedAtEpochMs}) {
    return LoginSession(
      accessToken: dto.accessToken ?? '',
      refreshToken: dto.refreshToken,
      accessTokenExpiresInMs: dto.accessTokenExpiresInMs,
      refreshTokenExpiresInMs: dto.refreshTokenExpiresInMs,
      issuedAtEpochMs: issuedAtEpochMs,
    );
  }

  /// 로컬 저장소 JSON을 세션 모델로 복원합니다.
  factory LoginSession.fromJson(Map<String, dynamic> json) {
    return LoginSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      accessTokenExpiresInMs: json['accessTokenExpiresInMs'] as int?,
      refreshTokenExpiresInMs: json['refreshTokenExpiresInMs'] as int?,
      issuedAtEpochMs: json['issuedAtEpochMs'] as int?,
    );
  }

  /// refresh token이 실제로 저장되어 재발급에 사용할 수 있는지 판별합니다.
  bool get hasRefreshToken => refreshToken != null && refreshToken!.isNotEmpty;

  /// 상대 만료 시간을 절대 시각으로 환산해 디버깅과 만료 판단에 재사용합니다.
  DateTime? get accessTokenExpiresAt => _resolveExpiry(accessTokenExpiresInMs);

  /// 상대 만료 시간을 절대 시각으로 환산해 디버깅과 만료 판단에 재사용합니다.
  DateTime? get refreshTokenExpiresAt =>
      _resolveExpiry(refreshTokenExpiresInMs);

  /// 로컬 저장소에 그대로 직렬화할 수 있는 세션 스냅샷을 제공합니다.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiresInMs': accessTokenExpiresInMs,
      'refreshTokenExpiresInMs': refreshTokenExpiresInMs,
      'issuedAtEpochMs': issuedAtEpochMs,
    };
  }

  /// 토큰 일부만 갱신해도 나머지 세션 메타데이터를 유지할 수 있게 합니다.
  LoginSession copyWith({
    String? accessToken,
    String? refreshToken,
    int? accessTokenExpiresInMs,
    int? refreshTokenExpiresInMs,
    int? issuedAtEpochMs,
  }) {
    return LoginSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessTokenExpiresInMs:
          accessTokenExpiresInMs ?? this.accessTokenExpiresInMs,
      refreshTokenExpiresInMs:
          refreshTokenExpiresInMs ?? this.refreshTokenExpiresInMs,
      issuedAtEpochMs: issuedAtEpochMs ?? this.issuedAtEpochMs,
    );
  }

  static String _normalizeRequiredToken(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const DataValidationException(message: '인증 토큰이 없습니다.');
    }
    return normalized;
  }

  static String? _normalizeOptionalToken(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  DateTime? _resolveExpiry(int? expiresInMs) {
    if (expiresInMs == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(issuedAtEpochMs + expiresInMs);
  }
}
