import 'package:soi/api/models/notification.dart';

class AppPushPayload {
  final int? notificationId;
  final AppNotificationType? type;
  final int? friendId;
  final int? categoryId;
  final int? categoryInviteId;
  final int? postId;
  final int? commentId;
  final String? title;
  final String? body;
  final Map<String, dynamic> rawData;

  const AppPushPayload({
    this.notificationId,
    this.type,
    this.friendId,
    this.categoryId,
    this.categoryInviteId,
    this.postId,
    this.commentId,
    this.title,
    this.body,
    this.rawData = const <String, dynamic>{},
  });

  factory AppPushPayload.fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    final normalized = Map<String, dynamic>.from(data);
    return AppPushPayload(
      notificationId: _parseInt(normalized['notificationId']),
      type: _parseType(normalized['type']),
      friendId: _parseInt(normalized['friendId']),
      categoryId: _parseInt(normalized['categoryId']),
      categoryInviteId: _parseInt(normalized['categoryInviteId']),
      postId: _parseInt(normalized['postId']),
      commentId: _parseInt(normalized['commentId']),
      title: _parseString(title) ?? _parseString(normalized['title']),
      body:
          _parseString(body) ??
          _parseString(normalized['body']) ??
          _parseString(normalized['text']),
      rawData: normalized,
    );
  }

  factory AppPushPayload.fromJson(Map<String, dynamic> json) {
    return AppPushPayload.fromData(
      json,
      title: _parseString(json['title']),
      body: _parseString(json['body']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'notificationId': notificationId,
      'type': type?.value,
      'friendId': friendId,
      'categoryId': categoryId,
      'categoryInviteId': categoryInviteId,
      'postId': postId,
      'commentId': commentId,
      'title': title,
      'body': body,
      ...rawData,
    };
  }

  bool get hasPostRoute => categoryId != null && postId != null;

  static String? _parseString(dynamic value) {
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static AppNotificationType? _parseType(dynamic raw) {
    switch (_parseString(raw)?.toUpperCase()) {
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
}
