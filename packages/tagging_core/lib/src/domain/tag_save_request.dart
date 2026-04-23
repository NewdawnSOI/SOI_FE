import 'tag_models.dart';

/// 저장 직전에 draft와 anchor를 합쳐 mutation port로 전달하는 요청 모델입니다.
class TagSaveRequest {
  const TagSaveRequest({
    required this.scopeId,
    required this.actorId,
    required this.content,
    this.parentEntryId,
    this.anchor,
    this.metadata = const <String, Object?>{},
  });

  final TagScopeId scopeId;
  final TagEntityId actorId;
  final TagContent content;
  final TagEntityId? parentEntryId;
  final TagPosition? anchor;
  final Map<String, Object?> metadata;

  TagValidationError? validateForSave() {
    if (scopeId.trim().isEmpty) {
      return TagValidationError.invalidScopeId;
    }
    if (actorId.trim().isEmpty) {
      return TagValidationError.invalidActorId;
    }
    if (anchor == null) {
      return TagValidationError.missingAnchor;
    }

    if (content.isText) {
      if ((content.text ?? '').trim().isEmpty) {
        return TagValidationError.missingText;
      }
      return null;
    }

    if (!content.hasReference) {
      return TagValidationError.missingReference;
    }
    return null;
  }

  TagSaveRequest copyWith({
    TagScopeId? scopeId,
    TagEntityId? actorId,
    TagContent? content,
    TagEntityId? parentEntryId,
    TagPosition? anchor,
    Map<String, Object?>? metadata,
    bool clearParentEntryId = false,
    bool clearAnchor = false,
  }) {
    return TagSaveRequest(
      scopeId: scopeId ?? this.scopeId,
      actorId: actorId ?? this.actorId,
      content: content ?? this.content,
      parentEntryId: clearParentEntryId
          ? null
          : (parentEntryId ?? this.parentEntryId),
      anchor: clearAnchor ? null : (anchor ?? this.anchor),
      metadata: metadata ?? this.metadata,
    );
  }

  TagSaveRequest copyWithAnchor(TagPosition nextAnchor) {
    return copyWith(anchor: nextAnchor);
  }
}
