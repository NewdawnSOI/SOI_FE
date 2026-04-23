typedef TagScopeId = String;
typedef TagEntityId = String;

/// 저장 가능 태그 콘텐츠의 공용 타입을 정의합니다.
enum TagContentType { text, image, video, audio }

/// 태그와 드래프트가 공유하는 최소 콘텐츠 payload를 표현합니다.
class TagContent {
  const TagContent({
    required this.type,
    this.text,
    this.reference,
    this.waveformSamples,
    this.durationMs,
    this.metadata = const <String, Object?>{},
  });

  /// 텍스트 태그 콘텐츠를 생성합니다.
  const TagContent.text(
    String value, {
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : this(type: TagContentType.text, text: value, metadata: metadata);

  /// 이미지 태그 콘텐츠를 생성합니다.
  const TagContent.image({
    String? reference,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : this(
         type: TagContentType.image,
         reference: reference,
         metadata: metadata,
       );

  /// 비디오 태그 콘텐츠를 생성합니다.
  const TagContent.video({
    String? reference,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : this(
         type: TagContentType.video,
         reference: reference,
         metadata: metadata,
       );

  /// 오디오 태그 콘텐츠를 생성합니다.
  const TagContent.audio({
    String? reference,
    List<double>? waveformSamples,
    int? durationMs,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : this(
         type: TagContentType.audio,
         reference: reference,
         waveformSamples: waveformSamples,
         durationMs: durationMs,
         metadata: metadata,
       );

  final TagContentType type;
  final String? text;
  final String? reference;
  final List<double>? waveformSamples;
  final int? durationMs;
  final Map<String, Object?> metadata;

  bool get isText => type == TagContentType.text;

  bool get isImage => type == TagContentType.image;

  bool get isVideo => type == TagContentType.video;

  bool get isAudio => type == TagContentType.audio;

  bool get hasReference => (reference ?? '').trim().isNotEmpty;

  TagContent copyWith({
    TagContentType? type,
    String? text,
    String? reference,
    List<double>? waveformSamples,
    int? durationMs,
    Map<String, Object?>? metadata,
  }) {
    return TagContent(
      type: type ?? this.type,
      text: text ?? this.text,
      reference: reference ?? this.reference,
      waveformSamples: waveformSamples ?? this.waveformSamples,
      durationMs: durationMs ?? this.durationMs,
      metadata: metadata ?? this.metadata,
    );
  }
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

/// 저장 전에만 존재하는 태그 드래프트를 scope 단위로 보관합니다.
class TagDraft {
  const TagDraft({
    required this.actorId,
    required this.content,
    this.parentEntryId,
    this.metadata = const <String, Object?>{},
  });

  final TagEntityId actorId;
  final TagContent content;
  final TagEntityId? parentEntryId;
  final Map<String, Object?> metadata;
}

/// 저장 전 pending 마커의 위치와 진행률을 scope 단위로 보관합니다.
class TagPendingMarker {
  const TagPendingMarker({required this.relativePosition, this.progress});

  final TagPosition relativePosition;
  final double? progress;

  TagPendingMarker copyWith({
    TagPosition? relativePosition,
    double? progress,
    bool clearProgress = false,
  }) {
    return TagPendingMarker(
      relativePosition: relativePosition ?? this.relativePosition,
      progress: clearProgress ? null : (progress ?? this.progress),
    );
  }
}

/// 저장 후 scope 위에 렌더링하거나 스레드로 조회하는 최소 태그 엔트리입니다.
class TagEntry {
  const TagEntry({
    this.id,
    required this.scopeId,
    required this.actorId,
    this.parentEntryId,
    this.anchor,
    this.createdAt,
    required this.content,
    this.metadata = const <String, Object?>{},
  });

  final TagEntityId? id;
  final TagScopeId scopeId;
  final TagEntityId actorId;
  final TagEntityId? parentEntryId;
  final TagPosition? anchor;
  final DateTime? createdAt;
  final TagContent content;
  final Map<String, Object?> metadata;

  bool get isText => content.isText;

  bool get isImage => content.isImage;

  bool get isVideo => content.isVideo;

  bool get isAudio => content.isAudio;

  bool get hasAnchor => anchor != null;

  bool get hasLocation => hasAnchor;

  TagEntry copyWith({
    TagEntityId? id,
    TagScopeId? scopeId,
    TagEntityId? actorId,
    TagEntityId? parentEntryId,
    TagPosition? anchor,
    DateTime? createdAt,
    TagContent? content,
    Map<String, Object?>? metadata,
    bool clearParentEntryId = false,
    bool clearAnchor = false,
  }) {
    return TagEntry(
      id: id ?? this.id,
      scopeId: scopeId ?? this.scopeId,
      actorId: actorId ?? this.actorId,
      parentEntryId: clearParentEntryId
          ? null
          : (parentEntryId ?? this.parentEntryId),
      anchor: clearAnchor ? null : (anchor ?? this.anchor),
      createdAt: createdAt ?? this.createdAt,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// overlay와 thread 캐시를 한 번에 관찰할 때 사용하는 snapshot입니다.
class TagEntrySnapshot {
  const TagEntrySnapshot({this.overlayEntries, this.threadEntries});

  final List<TagEntry>? overlayEntries;
  final List<TagEntry>? threadEntries;
}

/// 저장 요청 검증 실패 원인을 플랫폼이 해석 가능한 code로 전달합니다.
enum TagValidationError {
  invalidScopeId,
  invalidActorId,
  missingAnchor,
  missingText,
  missingReference,
}

/// mutation 성공 시 persisted entry 하나만 알면 상위 orchestration이 이어갈 수 있습니다.
class TagMutationResult {
  const TagMutationResult({required this.entry});

  final TagEntry entry;
}
