import '../../../../api/controller/media_controller.dart';
import '../../application/tagging_media_resolver.dart';

/// SOI의 presigned URL 해석기를 태깅 모듈 인터페이스로 감쌉니다.
class SoiTaggingMediaResolver implements TaggingMediaResolver {
  final MediaController _mediaController;

  const SoiTaggingMediaResolver(this._mediaController);

  @override
  Future<String?> getPresignedUrl(String key) {
    return _mediaController.getPresignedUrl(key);
  }

  @override
  Future<List<String>> getPresignedUrls(List<String> keys) {
    return _mediaController.getPresignedUrls(keys);
  }

  @override
  String? peekPresignedUrl(String key) {
    return _mediaController.peekPresignedUrl(key);
  }
}
