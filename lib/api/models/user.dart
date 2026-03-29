import 'package:soi_api_client/api.dart';

/// 사용자 모델
///
/// API의 UserRespDto/UserFindRespDto를 앱 내부 상태로 정규화합니다.
/// 프로필/커버 이미지 키와 URL을 함께 보관해 화면이 즉시 렌더링하거나 presigned URL을 보완할 수 있게 합니다.
class User {
  // 고유 ID
  final int id;

  // 사용자가 설정한 ID
  final String userId;

  // 사용자 이름
  final String name;

  // 프로필 이미지 키
  final String? profileImageKey;

  // 프로필 이미지 접근 URL
  final String? profileImageUrl;

  // 프로필 커버 이미지 키
  final String? profileCoverImageKey;

  // 프로필 커버 이미지 접근 URL
  final String? profileCoverImageUrl;

  // 생년월일 (YYYY-MM-DD 형식)
  final String? birthDate;

  // 전화번호
  final String phoneNumber;

  // 활성화 상태 (친구 찾기 등에서 사용)
  final bool active;

  const User({
    required this.id,
    required this.userId,
    required this.name,
    this.profileImageKey,
    this.profileImageUrl,
    this.profileCoverImageKey,
    this.profileCoverImageUrl,
    this.birthDate,
    required this.phoneNumber,
    this.active = false,
  });

  /// UserRespDto에서 User 모델 생성
  factory User.fromDto(UserRespDto dto) {
    return User(
      id: dto.id ?? 0,
      userId: dto.nickname ?? '',
      name: dto.name ?? '',
      profileImageKey: dto.profileImageKey,
      profileImageUrl: dto.profileImageUrl,
      profileCoverImageKey: dto.profileCoverImageKey,
      profileCoverImageUrl: dto.profileCoverImageUrl,
      birthDate: dto.birthDate,
      phoneNumber: dto.phoneNum ?? '',
    );
  }

  /// UserFindRespDto에서 User 모델 생성
  ///
  /// 친구 목록, 검색 결과 등에서 사용됩니다.
  /// UserFindRespDto에는 birthDate, phoneNum이 없으므로 빈 값으로 처리됩니다.
  factory User.fromFindDto(UserFindRespDto dto) {
    return User(
      id: dto.id ?? 0,
      userId: dto.nickname ?? '',
      name: dto.name ?? '',
      profileImageKey: dto.profileImageKey,
      profileCoverImageKey: dto.profileCoverImageKey,
      birthDate: null,
      phoneNumber: '',
      active: dto.active ?? false,
    );
  }

  /// JSON에서 User 모델 생성
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profileImageKey: json['profileImageKey'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      profileCoverImageKey: json['profileCoverImageKey'] as String?,
      profileCoverImageUrl: json['profileCoverImageUrl'] as String?,
      birthDate: json['birthDate'] as String?,
      phoneNumber: json['phoneNum'] as String? ?? '',
      active: json['active'] as bool? ?? false,
    );
  }

  /// User 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'profileImageKey': profileImageKey,
      'profileImageUrl': profileImageUrl,
      'profileCoverImageKey': profileCoverImageKey,
      'profileCoverImageUrl': profileCoverImageUrl,
      'birthDate': birthDate,
      'phoneNum': phoneNumber,
      'active': active,
    };
  }

  /// 프로필 이미지 유무 확인
  bool get hasProfileImage =>
      (profileImageUrl != null && profileImageUrl!.isNotEmpty) ||
      (profileImageKey != null && profileImageKey!.isNotEmpty);

  /// 화면이 즉시 렌더링할 수 있는 프로필 이미지 URL입니다.
  /// 명시적 URL을 우선 사용하고, 레거시 응답처럼 key 자체가 URL인 경우만 fallback으로 허용합니다.
  String? get displayProfileImageUrl => _resolveDisplayUrl(
    primary: profileImageUrl,
    fallbackKey: profileImageKey,
  );

  /// 프로필 이미지 캐시와 presigned URL 해상에 사용하는 안정 키입니다.
  String? get profileImageCacheKey => _normalizeNonEmpty(profileImageKey);

  /// 화면이 즉시 렌더링할 수 있는 커버 이미지 URL입니다.
  /// 명시적 URL을 우선 사용하고, 레거시 응답처럼 key 자체가 URL인 경우만 fallback으로 허용합니다.
  String? get displayCoverImageUrl => _resolveDisplayUrl(
    primary: profileCoverImageUrl,
    fallbackKey: profileCoverImageKey,
  );

  /// 커버 이미지 캐시와 presigned URL 해상에 사용하는 안정 키입니다.
  String? get profileCoverImageCacheKey =>
      _normalizeNonEmpty(profileCoverImageKey);

  /// copyWith 메서드
  User copyWith({
    int? id,
    String? userId,
    String? name,
    String? profileImageKey,
    String? profileImageUrl,
    String? profileCoverImageKey,
    String? profileCoverImageUrl,
    String? birthDate,
    String? phoneNumber,
    bool? active,
  }) {
    return User(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      profileImageKey: profileImageKey,
      profileImageUrl: profileImageUrl,
      profileCoverImageKey: profileCoverImageKey,
      profileCoverImageUrl: profileCoverImageUrl,
      birthDate: birthDate ?? this.birthDate,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      active: active ?? this.active,
    );
  }

  static String? _resolveDisplayUrl({
    required String? primary,
    required String? fallbackKey,
  }) {
    final normalizedPrimary = _normalizeNonEmpty(primary);
    if (normalizedPrimary != null) {
      return normalizedPrimary;
    }

    final normalizedFallback = _normalizeNonEmpty(fallbackKey);
    if (normalizedFallback == null) {
      return null;
    }

    final uri = Uri.tryParse(normalizedFallback);
    if (uri != null && uri.hasScheme) {
      return normalizedFallback;
    }

    return null;
  }

  static String? _normalizeNonEmpty(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId;

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;

  @override
  String toString() {
    return 'User{id: $id, userId: $userId, name: $name, phoneNumber: $phoneNumber}';
  }
}
