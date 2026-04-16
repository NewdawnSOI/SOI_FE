import '../../../api/models/comment.dart';
import '../domain/tagging_save_payload.dart';

/// 태그 저장 위젯이 앱별 저장 구현을 모른 채 저장만 요청하도록 분리한 인터페이스입니다.
abstract class TaggingSaveDelegate {
  Future<Comment> save({
    required TaggingSavePayload payload,
    void Function(double progress)? onProgress,
  });
}
