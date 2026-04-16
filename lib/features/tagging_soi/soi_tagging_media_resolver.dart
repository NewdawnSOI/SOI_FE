import 'package:tagging_core/tagging_core.dart';

import '../../api/controller/media_controller.dart';

/// SOI presigned URL 해석기를 tagging_core 인터페이스로 감쌉니다.
class SoiTaggingMediaResolver implements TaggingMediaResolver {
  const SoiTaggingMediaResolver(this._mediaController);

  final MediaController _mediaController;

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
