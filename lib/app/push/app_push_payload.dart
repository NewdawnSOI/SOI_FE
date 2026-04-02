import 'dart:convert';

import 'package:soi/api/models/notification.dart';

/// 앱에서 쓰기 쉽게 정리한 푸시 데이터 모델.
/// - 서버의 'title/body/data' 구조에 대응하기 위한 모델 클래스.
/// - FCM data 맵이나 JSON에서 필요한 값들을 추출해 앱에서 쓰기 편한 형태로 정리.
///
/// 필드:
/// - [notificationId]: 알림 ID.
/// - [type]: 알림 종류.
/// - [friendId]: 친구 관련 ID.
/// - [categoryId]: 카테고리 ID.
/// - [categoryInviteId]: 카테고리 초대 ID.
/// - [postId]: 게시물 ID.
/// - [commentId]: 댓글 ID.
/// - [nickname]: 요청자 닉네임.
/// - [imageUrl]: 관련 이미지 URL.
/// - [title]: 알림 제목.
/// - [body]: 알림 본문.
/// - [rawData]: 원본 data 값 모음.
class AppPushPayload {
  /// 알림 ID.
  final int? notificationId;

  /// 알림 종류.
  final AppNotificationType? type;

  /// 친구 관련 ID.
  final int? friendId;

  /// 카테고리 ID.
  final int? categoryId;

  /// 카테고리 초대 ID.
  final int? categoryInviteId;

  /// 게시물 ID.
  final int? postId;

  /// 댓글 ID.
  final int? commentId;

  /// 요청자 닉네임.
  final String? nickname;

  /// 관련 이미지 URL.
  final String? imageUrl;

  /// 알림 제목.
  final String? title;

  /// 알림 본문.
  final String? body;

  /// 원본 data 값 모음.
  final Map<String, dynamic> rawData;

  const AppPushPayload({
    this.notificationId,
    this.type,
    this.friendId,
    this.categoryId,
    this.categoryInviteId,
    this.postId,
    this.commentId,
    this.nickname,
    this.imageUrl,
    this.title,
    this.body,
    this.rawData = const <String, dynamic>{},
  });

  /// FCM data 맵 변환 팩토리 생성자.
  /// - 받은 data 맵을 앱애서 사용하기 편하도록 AppPushPayload 객체를 생성하고 반환도 할 수 있음.
  ///   - AppPushCoordinator.__payloadFromRemoteMessage에서 RemoteMessage를 받아서
  ///     data, title, body를 추출한 후, 이 생성자에 넘겨서 AppPushPayload 객체로 변환.
  ///
  /// Parameters:
  /// - [data]: 서버에서 받은 data 맵.
  /// - [title]: 알림창 제목.
  /// - [body]: 알림창 본문.
  ///
  /// Returns:
  /// - [AppPushPayload]: 앱에서 쓰기 쉽게 정리한 푸시 데이터.
  factory AppPushPayload.fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    // 원본 data맵을 수정하지 않도록 복사를 해서 사용.
    final normalized = Map<String, dynamic>.from(data);

    // 여러 형태로 올 수 있는 값들을 정리해서 AppPushPayload 필드에 맞게 추출.
    return AppPushPayload(
      notificationId: _parseInt(normalized['notificationId']),
      type: _parseType(normalized['type']),
      friendId: _parseInt(normalized['friendId']),
      categoryId: _parseInt(normalized['categoryId']),
      categoryInviteId: _parseInt(normalized['categoryInviteId']),
      postId: _parseInt(normalized['postId']),
      commentId: _parseInt(normalized['commentId']),
      nickname: _parseFirstString(normalized, const [
        'nickname',
        'userNickname',
        'name',
      ]),
      imageUrl: _parseFirstString(normalized, const [
        'imageUrl',
        'thumbnailUrl',
        'postImageUrl',
        'photoUrl',
        'previewImageUrl',
      ]),
      title: _parseString(title) ?? _parseString(normalized['title']),
      body:
          _parseString(body) ??
          _parseString(normalized['body']) ??
          _parseString(normalized['text']),
      rawData: normalized,
    );
  }

  /// FCM json 맵 변환 팩토리 생성자.
  /// - 받은 json 맵을 앱애서 사용하기 편하도록 AppPushPayload 객체를 생성하고 반환도 할 수 있음.
  ///   - AppPushCoordinator.decodeNotificationPayload에서 payload를 받아서
  ///     JSON 문자열로 변환한 후, 이 생성자에 넘겨서 AppPushPayload 객체로 변환.
  ///
  /// Parameters:
  /// - [json]: 서버나 로컬 알림에서 받은 JSON 맵.
  ///
  /// Returns:
  /// - 앱에서 쓰기 쉽게 정리한 푸시 데이터.
  factory AppPushPayload.fromJson(Map<String, dynamic> json) {
    final envelope = Map<String, dynamic>.from(json);
    final data = _extractPayloadData(envelope);
    return AppPushPayload.fromData(
      data,
      title: _parseString(envelope['title']) ?? _parseString(data['title']),
      body: _parseString(envelope['body']) ?? _parseString(data['body']),
    );
  }

  /// JSON 변환 메서드.
  ///
  /// Returns:
  /// - `title/body/data` 형태 JSON.
  Map<String, dynamic> toJson() {
    final data = Map<String, dynamic>.from(rawData);
    _putIfAbsent(data, 'notificationId', notificationId);
    _putIfAbsent(data, 'type', type?.value);
    _putIfAbsent(data, 'friendId', friendId);
    _putIfAbsent(data, 'categoryId', categoryId);
    _putIfAbsent(data, 'categoryInviteId', categoryInviteId);
    _putIfAbsent(data, 'postId', postId);
    _putIfAbsent(data, 'commentId', commentId);
    _putIfAbsent(data, 'nickname', nickname);
    _putIfAbsent(data, 'imageUrl', imageUrl);
    _putIfAbsent(data, 'body', body);

    return <String, dynamic>{
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      'data': data,
    };
  }

  /// 게시물 화면 이동 가능 여부.
  bool get hasPostRoute => categoryId != null && postId != null;

  /// 알림에 보여줄 제목.
  String? get notificationTitle => nickname ?? title;

  /// 알림에 보여줄 본문.
  String? get notificationBody {
    if (body != null && body!.isNotEmpty) {
      return body;
    }
    if (nickname != null && title != null && title != nickname) {
      return title;
    }
    return null;
  }

  /// JSON 안쪽 data 꺼내기.
  ///
  /// Parameters:
  /// - [json]: `title/body/data` 형태 JSON.
  ///
  /// Returns:
  /// - 실제 알림 값이 담긴 data 맵.
  static Map<String, dynamic> _extractPayloadData(Map<String, dynamic> json) {
    final nestedData = _parseMap(json['data']);
    if (nestedData != null) {
      return nestedData;
    }

    final flattened = Map<String, dynamic>.from(json);
    flattened.remove('title');
    flattened.remove('body');
    flattened.remove('data');
    return flattened;
  }

  /// 맵 형태 값 변환기.
  ///
  /// Parameters:
  /// - [value]: 맵일 수 있는 원본 값.
  ///
  /// Returns:
  /// - `Map<String, dynamic>` 형태 값.
  static Map<String, dynamic>? _parseMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  /// 문자열 정리기.
  ///
  /// Parameters:
  /// - [value]: 원본 값.
  ///
  /// Returns:
  /// - 앞뒤 공백을 뺀 문자열.
  static String? _parseString(dynamic value) {
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  /// 정수 변환기.
  ///
  /// Parameters:
  /// - [value]: 원본 값.
  ///
  /// Returns:
  /// - 숫자로 바꾼 값.
  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  /// 여러 키 중 첫 문자열 찾기.
  ///
  /// Parameters:
  /// - [data]: 값을 찾을 맵.
  /// - [keys]: 후보 키 목록.
  ///
  /// Returns:
  /// - 가장 먼저 찾은 문자열.
  static String? _parseFirstString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _parseString(data[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  /// 비어 있을 때만 값 넣기.
  ///
  /// Parameters:
  /// - [data]: 값을 넣을 맵.
  /// - [key]: 넣을 위치 이름.
  /// - [value]: 넣을 값.
  static void _putIfAbsent(
    Map<String, dynamic> data,
    String key,
    dynamic value,
  ) {
    if (value == null || data.containsKey(key)) {
      return;
    }
    data[key] = value;
  }

  /// 알림 타입 변환기.
  ///
  /// Parameters:
  /// - [raw]: 서버에서 받은 타입 값.
  ///
  /// Returns:
  /// - 앱에서 쓰는 알림 종류.
  static AppNotificationType? _parseType(dynamic raw) {
    switch (_parseString(raw)?.toUpperCase()) {
      case 'CATEGORY_INVITE':
      case 'CATEGORY_INVITED':
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
}
