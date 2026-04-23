import '../domain/tag_models.dart';
import '../domain/tag_save_request.dart';

/// core가 저장 구현을 모른 채 mutation만 요청하도록 분리한 인터페이스입니다.
abstract class TagMutationPort {
  Future<TagMutationResult> save({
    required TagSaveRequest request,
    void Function(double progress)? onProgress,
  });
}
