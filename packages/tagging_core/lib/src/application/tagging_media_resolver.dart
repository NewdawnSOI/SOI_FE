/// 태깅 모듈이 프로필 이미지 key를 실제 표시 가능한 URL로 푸는 인터페이스입니다.
abstract class TaggingMediaResolver {
  String? peekPresignedUrl(String key);

  Future<String?> getPresignedUrl(String key);

  Future<List<String>> getPresignedUrls(List<String> keys);
}
