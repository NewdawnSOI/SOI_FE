import 'package:soi_api_client/api.dart';

/// 알림 유형
/// API의 [NotificationRespDtoTypeEnum]과 매핑되는 앱 내부에서 사용하기 위한 열거형입니다.
/// 알림 유형은 API에서 정의된 문자열 값을 기반으로 하며, 앱에서는 AppNotificationType 열거형으로 사용됩니다.
enum AppNotificationType {
  categoryInvite('CATEGORY_INVITE'), // 카테고리 초대 알림
  categoryAdded('CATEGORY_ADDED'), // 카테고리에 추가됐음을 알리는 알림
  photoAdded('PHOTO_ADDED'), // 게시물에 사진이 추가됐음을 알리는 알림
  commentAdded('COMMENT_ADDED'), // 게시물에 댓글이 추가됐음을 알리는 알림
  commentAudioAdded('COMMENT_AUDIO_ADDED'), // 게시물에 음성 댓글이 추가됐음을 알리는 알림
  commentVideoAdded('COMMENT_VIDEO_ADDED'), // 게시물에 비디오 댓글이 추가됐음을 알리는 알림
  commentPhotoAdded('COMMENT_PHOTO_ADDED'), // 게시물에 사진 댓글이 추가됐음을 알리는 알림
  commentReplyAdded('COMMENT_REPLY_ADDED'), // 게시물에 대댓글이 추가됐음을 알리는 알림
  friendRequest('FRIEND_REQUEST'), // 친구 요청 알림
  friendRespond('FRIEND_RESPOND'); // 친구 요청에 대한 응답 알림

  final String value;
  const AppNotificationType(this.value);
}

/// 알림 모델
///
/// API의 NotificationRespDto를 앱 내부에서 사용하기 위한 모델입니다.
class AppNotification {
  /// 알림 ID
  final int? id;

  /// 알림 텍스트
  final String? text;

  /// 관련 사용자 이름 (표시용)
  final String? name;

  /// 관련 사용자 닉네임/아이디 (표시용)
  final String? nickname;

  /// 관련 사용자 프로필 이미지 키
  final String? userProfileKey;

  /// 관련 사용자 프로필 이미지 URL
  final String? userProfileUrl;

  /// 기존 UI가 바로 렌더링할 수 있는 프로필 이미지 소스입니다.
  /// 서버가 URL을 내려주면 우선 사용하고, key 자체가 URL인 레거시 응답일 때만 fallback으로 허용합니다.
  String? get userProfile => userProfileImageUrl;

  /// 화면이 즉시 렌더링할 수 있는 프로필 이미지 URL입니다.
  String? get userProfileImageUrl =>
      _resolveDisplayUrl(primary: userProfileUrl, fallbackKey: userProfileKey);

  /// 프로필 이미지 캐시와 후속 URL 해상에 사용하는 안정 키입니다.
  String? get userProfileCacheKey => _normalizeNonEmpty(userProfileKey);

  /// 관련 이미지 URL
  final String? imageUrl;

  /// 알림 타입
  final AppNotificationType? type;

  /// 읽음 여부
  final bool? isRead;

  /// 게시물 알림의 경우, 게시물이 속한 카테고리 ID
  final int? categoryIdForPost;

  /// 관련 ID (예: 친구 요청 ID, 게시물 ID 등)
  /// 친구 관련 알림일 경우 --> 친구 요청 ID
  /// 게시물 관련 알림일 경우 --> Post ID
  /// 댓글 관련 알림일 경우 --> Comment ID
  final int? relatedId;

  /// 답글 알림의 경우, 실제 답글 댓글 ID
  final int? replyCommentId;

  /// 답글 알림의 경우, 부모 댓글 ID
  final int? parentCommentId;

  const AppNotification({
    this.id,
    this.text,
    this.name,
    this.nickname,
    this.userProfileKey,
    this.userProfileUrl,
    this.imageUrl,
    this.type,
    this.isRead,
    this.categoryIdForPost,
    this.relatedId,
    this.replyCommentId,
    this.parentCommentId,
  });

  /// NotificationRespDto에서 AppNotification 모델 생성
  factory AppNotification.fromDto(NotificationRespDto dto) {
    return AppNotification(
      id: dto.id,
      text: dto.text,
      name: dto.name,
      nickname: dto.nickname,
      userProfileKey: dto.userProfileKey,
      userProfileUrl: dto.userProfileUrl,
      imageUrl: dto.imageUrl,
      type: _typeFromDto(dto.type),
      isRead: dto.isRead,
      categoryIdForPost: dto.categoryIdForPost,
      relatedId: dto.relatedId,
      replyCommentId: dto.replyCommentId,
      parentCommentId: dto.parentCommentId,
    );
  }

  /// DTO 타입을 AppNotificationType으로 변환
  static AppNotificationType? _typeFromDto(NotificationRespDtoTypeEnum? type) {
    switch (type) {
      case NotificationRespDtoTypeEnum.CATEGORY_INVITE:
        return AppNotificationType.categoryInvite;
      case NotificationRespDtoTypeEnum.CATEGORY_ADDED:
        return AppNotificationType.categoryAdded;
      case NotificationRespDtoTypeEnum.PHOTO_ADDED:
        return AppNotificationType.photoAdded;
      case NotificationRespDtoTypeEnum.COMMENT_ADDED:
        return AppNotificationType.commentAdded;
      case NotificationRespDtoTypeEnum.COMMENT_AUDIO_ADDED:
        return AppNotificationType.commentAudioAdded;
      case NotificationRespDtoTypeEnum.COMMENT_VIDEO_ADDED:
        return AppNotificationType.commentVideoAdded;
      case NotificationRespDtoTypeEnum.COMMENT_PHOTO_ADDED:
        return AppNotificationType.commentPhotoAdded;
      case NotificationRespDtoTypeEnum.COMMENT_REPLY_ADDED:
        return AppNotificationType.commentReplyAdded;
      case NotificationRespDtoTypeEnum.FRIEND_REQUEST:
        return AppNotificationType.friendRequest;
      case NotificationRespDtoTypeEnum.FRIEND_RESPOND:
        return AppNotificationType.friendRespond;
      default:
        return null;
    }
  }

  /// JSON에서 AppNotification 모델 생성
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int?,
      text: json['text'] as String?,
      name: json['name'] as String?,
      nickname: json['nickname'] as String?,
      userProfileKey:
          (json['userProfileKey'] as String?) ??
          (json['userProfile'] as String?),
      userProfileUrl: json['userProfileUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      type: _typeFromJsonValue(json['type']),
      isRead: json['isRead'] as bool?,
      categoryIdForPost: json['categoryIdForPost'] as int?,
      relatedId: json['relatedId'] as int?,
      replyCommentId: json['replyCommentId'] as int?,
      parentCommentId: json['parentCommentId'] as int?,
    );
  }

  static AppNotificationType? _typeFromJsonValue(dynamic raw) {
    if (raw is NotificationRespDtoTypeEnum) {
      return _typeFromDto(raw);
    }
    return _typeFromString(raw?.toString());
  }

  static AppNotificationType? _typeFromString(String? type) {
    switch (type?.toUpperCase()) {
      case 'CATEGORY_INVITE':
        return AppNotificationType.categoryInvite;
      case 'CATEGORY_ADDED':
        return AppNotificationType.categoryAdded;
      case 'PHOTO_ADDED':
        return AppNotificationType.photoAdded;
      case 'COMMENT_ADDED':
        return AppNotificationType.commentAdded;
      case 'COMMENT_AUDIO_ADDED':
        return AppNotificationType.commentAudioAdded;
      case 'COMMENT_VIDEO_ADDED':
        return AppNotificationType.commentVideoAdded;
      case 'COMMENT_PHOTO_ADDED':
        return AppNotificationType.commentPhotoAdded;
      case 'COMMENT_REPLY_ADDED':
        return AppNotificationType.commentReplyAdded;
      case 'FRIEND_REQUEST':
        return AppNotificationType.friendRequest;
      case 'FRIEND_RESPOND':
        return AppNotificationType.friendRespond;
      default:
        return null;
    }
  }

  /// AppNotification 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'name': name,
      'nickname': nickname,
      'userProfileKey': userProfileKey,
      'userProfileUrl': userProfileUrl,
      'imageUrl': imageUrl,
      'type': type?.value,
      'isRead': isRead,
      'categoryIdForPost': categoryIdForPost,
      'relatedId': relatedId,
      'replyCommentId': replyCommentId,
      'parentCommentId': parentCommentId,
    };
  }

  /// 텍스트 유무 확인
  bool get hasText => text != null && text!.isNotEmpty;

  /// 이미지 유무 확인
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// 사용자 프로필 유무 확인
  bool get hasUserProfile =>
      userProfileImageUrl != null || userProfileCacheKey != null;

  /// copyWith 메서드
  AppNotification copyWith({
    int? id,
    String? text,
    String? name,
    String? nickname,
    String? userProfileKey,
    String? userProfileUrl,
    String? imageUrl,
    AppNotificationType? type,
    bool? isRead,
    int? categoryIdForPost,
    int? relatedId,
    int? replyCommentId,
    int? parentCommentId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      text: text ?? this.text,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      userProfileKey: userProfileKey ?? this.userProfileKey,
      userProfileUrl: userProfileUrl ?? this.userProfileUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      categoryIdForPost: categoryIdForPost ?? this.categoryIdForPost,
      relatedId: relatedId ?? this.relatedId,
      replyCommentId: replyCommentId ?? this.replyCommentId,
      parentCommentId: parentCommentId ?? this.parentCommentId,
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
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          relatedId == other.relatedId &&
          replyCommentId == other.replyCommentId &&
          parentCommentId == other.parentCommentId &&
          type == other.type;

  @override
  int get hashCode =>
      (id?.hashCode ?? 0) ^
      (text?.hashCode ?? 0) ^
      (relatedId?.hashCode ?? 0) ^
      (replyCommentId?.hashCode ?? 0) ^
      (parentCommentId?.hashCode ?? 0) ^
      (type?.hashCode ?? 0);

  @override
  String toString() {
    return 'AppNotification{id: $id, type: $type, relatedId: $relatedId, replyCommentId: $replyCommentId, parentCommentId: $parentCommentId, text: $text}';
  }
}

/// 전체 알림 응답 모델
///
/// API의 NotificationGetAllRespDto를 앱 내부에서 사용하기 위한 모델입니다.
class NotificationGetAllResult {
  /// 친구 요청 개수
  final int friendRequestCount;

  /// 알림 목록
  final List<AppNotification> notifications;

  const NotificationGetAllResult({
    this.friendRequestCount = 0,
    this.notifications = const [],
  });

  /// NotificationGetAllRespDto에서 NotificationGetAllResult 모델 생성
  factory NotificationGetAllResult.fromDto(NotificationGetAllRespDto dto) {
    return NotificationGetAllResult(
      friendRequestCount: dto.friendReqCount ?? 0,
      notifications: dto.notifications
          .map((n) => AppNotification.fromDto(n))
          .toList(),
    );
  }

  /// JSON에서 NotificationGetAllResult 모델 생성
  factory NotificationGetAllResult.fromJson(Map<String, dynamic> json) {
    return NotificationGetAllResult(
      friendRequestCount: json['friendReqCount'] as int? ?? 0,
      notifications:
          (json['notifications'] as List<dynamic>?)
              ?.map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// NotificationGetAllResult 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'friendReqCount': friendRequestCount,
      'notifications': notifications.map((n) => n.toJson()).toList(),
    };
  }

  /// 알림이 있는지 확인
  bool get hasNotifications => notifications.isNotEmpty;

  /// 친구 요청이 있는지 확인
  bool get hasFriendRequests => friendRequestCount > 0;

  /// 읽지 않은 알림 또는 처리되지 않은 친구 요청이 있는지 확인
  bool get hasUnreadNotifications =>
      hasFriendRequests ||
      notifications.any((notification) => notification.isRead != true);

  /// 전체 알림 개수
  int get totalCount => notifications.length;

  /// copyWith 메서드
  NotificationGetAllResult copyWith({
    int? friendRequestCount,
    List<AppNotification>? notifications,
  }) {
    return NotificationGetAllResult(
      friendRequestCount: friendRequestCount ?? this.friendRequestCount,
      notifications: notifications ?? this.notifications,
    );
  }

  @override
  String toString() {
    return 'NotificationGetAllResult{friendRequestCount: $friendRequestCount, notificationCount: ${notifications.length}}';
  }
}
