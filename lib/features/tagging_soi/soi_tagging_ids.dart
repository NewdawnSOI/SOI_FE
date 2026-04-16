import 'package:tagging_core/tagging_core.dart';

/// SOI의 정수 post/comment/user 식별자를 tagging 모듈의 범용 string 계약과 연결합니다.
class SoiTaggingIds {
  const SoiTaggingIds._();

  static const String _postScopePrefix = 'post:';

  static TagScopeId postScopeId(int postId) => '$_postScopePrefix$postId';

  static int postIdFromScopeId(TagScopeId scopeId) {
    final normalized = scopeId.trim();
    if (!normalized.startsWith(_postScopePrefix)) {
      throw StateError('지원하지 않는 SOI tagging scope 입니다: $scopeId');
    }

    final value = int.tryParse(normalized.substring(_postScopePrefix.length));
    if (value == null || value <= 0) {
      throw StateError('유효하지 않은 SOI post scope 입니다: $scopeId');
    }
    return value;
  }

  static TagEntityId? entityIdFromInt(int? value) {
    if (value == null) {
      return null;
    }
    return value.toString();
  }

  static int? intFromEntityId(TagEntityId? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return int.tryParse(normalized);
  }

  static int requiredIntFromEntityId(
    TagEntityId value, {
    required String fieldName,
  }) {
    final parsed = intFromEntityId(value);
    if (parsed == null || parsed <= 0) {
      throw StateError('유효하지 않은 $fieldName 입니다: $value');
    }
    return parsed;
  }
}
