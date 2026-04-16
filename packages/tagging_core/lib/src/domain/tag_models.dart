typedef TagScopeId = String;
typedef TagEntityId = String;

/// 태그 댓글이 소비하는 최소 미디어 식별자를 표현합니다.
class TagMediaRef {
  const TagMediaRef({this.url, this.key});

  final String? url;
  final String? key;
}

/// 태그 댓글 작성자를 식별하는 최소 정보를 담습니다.
class TagAuthor {
  const TagAuthor({
    required this.id,
    this.handle,
    this.profileImageSource,
  });

  final TagEntityId id;
  final String? handle;
  final String? profileImageSource;
}

/// 상대 좌표와 절대 좌표 계산 모두에 쓰는 2차원 좌표 모델입니다.
class TagPosition {
  const TagPosition({required this.x, required this.y});

  final double x;
  final double y;

  TagPosition copyWith({double? x, double? y}) {
    return TagPosition(x: x ?? this.x, y: y ?? this.y);
  }

  @override
  bool operator ==(Object other) {
    return other is TagPosition && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

/// 태그 좌표를 계산할 때 사용하는 미디어 표시 영역입니다.
class TagViewportSize {
  const TagViewportSize({required this.width, required this.height});

  final double width;
  final double height;
}

/// 저장 전 태그 드래프트의 종류를 구분합니다.
enum TagDraftKind { text, audio, image, video }

/// 저장된 태그 댓글의 종류를 구분합니다.
enum TagCommentKind { text, audio, image, video, reply }

/// 저장 전에만 존재하는 태그 드래프트를 post 단위로 보관합니다.
class TagDraft {
  const TagDraft({
    required this.kind,
    this.text,
    this.audioPath,
    this.mediaPath,
    this.waveformData,
    this.durationMs,
    required this.recorderUserId,
    this.profileImageSource,
  });

  final TagDraftKind kind;
  final String? text;
  final String? audioPath;
  final String? mediaPath;
  final List<double>? waveformData;
  final int? durationMs;
  final TagEntityId recorderUserId;
  final String? profileImageSource;

  bool get isTextComment => kind == TagDraftKind.text;

  bool get isAudioComment => kind == TagDraftKind.audio;

  bool get isImageComment => kind == TagDraftKind.image;

  bool get isVideoComment => kind == TagDraftKind.video;
}

/// 저장 전 pending 마커의 위치와 진행률을 post 단위로 보관합니다.
class TagPendingMarker {
  const TagPendingMarker({
    required this.relativePosition,
    this.profileImageSource,
    this.progress,
  });

  final TagPosition relativePosition;
  final String? profileImageSource;
  final double? progress;

  TagPendingMarker copyWith({
    TagPosition? relativePosition,
    String? profileImageSource,
    double? progress,
    bool clearProgress = false,
  }) {
    return TagPendingMarker(
      relativePosition: relativePosition ?? this.relativePosition,
      profileImageSource: profileImageSource ?? this.profileImageSource,
      progress: clearProgress ? null : (progress ?? this.progress),
    );
  }
}

/// 태그 오버레이와 저장 플로우가 소비하는 최소 댓글 모델입니다.
class TagComment {
  const TagComment({
    this.id,
    this.threadParentId,
    this.userId,
    this.nickname,
    this.replyUserName,
    this.userProfileUrl,
    this.userProfileKey,
    this.fileUrl,
    this.fileKey,
    this.createdAt,
    this.replyCommentCount,
    this.text,
    this.emojiId,
    this.audioUrl,
    this.waveformData,
    this.duration,
    this.locationX,
    this.locationY,
    required this.kind,
  });

  final TagEntityId? id;
  final TagEntityId? threadParentId;
  final TagEntityId? userId;
  final String? nickname;
  final String? replyUserName;
  final String? userProfileUrl;
  final String? userProfileKey;
  final String? fileUrl;
  final String? fileKey;
  final DateTime? createdAt;
  final int? replyCommentCount;
  final String? text;
  final int? emojiId;
  final String? audioUrl;
  final String? waveformData;
  final int? duration;
  final double? locationX;
  final double? locationY;
  final TagCommentKind kind;

  bool get isText => kind == TagCommentKind.text;

  bool get isAudio => kind == TagCommentKind.audio;

  bool get isImage => kind == TagCommentKind.image;

  bool get isVideo => kind == TagCommentKind.video;

  bool get isReply => kind == TagCommentKind.reply;

  bool get hasLocation => locationX != null && locationY != null;

  TagMediaRef get media => TagMediaRef(url: fileUrl, key: fileKey);

  TagMediaRef get profileImage =>
      TagMediaRef(url: userProfileUrl, key: userProfileKey);

  TagComment copyWith({
    TagEntityId? id,
    TagEntityId? threadParentId,
    TagEntityId? userId,
    String? nickname,
    String? replyUserName,
    String? userProfileUrl,
    String? userProfileKey,
    String? fileUrl,
    String? fileKey,
    DateTime? createdAt,
    int? replyCommentCount,
    String? text,
    int? emojiId,
    String? audioUrl,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
    TagCommentKind? kind,
  }) {
    return TagComment(
      id: id ?? this.id,
      threadParentId: threadParentId ?? this.threadParentId,
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      replyUserName: replyUserName ?? this.replyUserName,
      userProfileUrl: userProfileUrl ?? this.userProfileUrl,
      userProfileKey: userProfileKey ?? this.userProfileKey,
      fileUrl: fileUrl ?? this.fileUrl,
      fileKey: fileKey ?? this.fileKey,
      createdAt: createdAt ?? this.createdAt,
      replyCommentCount: replyCommentCount ?? this.replyCommentCount,
      text: text ?? this.text,
      emojiId: emojiId ?? this.emojiId,
      audioUrl: audioUrl ?? this.audioUrl,
      waveformData: waveformData ?? this.waveformData,
      duration: duration ?? this.duration,
      locationX: locationX ?? this.locationX,
      locationY: locationY ?? this.locationY,
      kind: kind ?? this.kind,
    );
  }
}

/// post 단위 댓글 캐시의 세 가지 뷰를 한 번에 다룰 때 사용하는 스냅샷입니다.
class TagThreadSnapshot {
  const TagThreadSnapshot({
    this.comments,
    this.parentComments,
    this.tagComments,
  });

  final List<TagComment>? comments;
  final List<TagComment>? parentComments;
  final List<TagComment>? tagComments;
}

/// 저장 결과는 persisted comment 하나만 알면 상위 orchestration이 이어갈 수 있습니다.
class TagSaveResult {
  const TagSaveResult({required this.comment});

  final TagComment comment;
}
