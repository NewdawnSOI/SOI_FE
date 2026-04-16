/// 태깅 드래프트를 시작할 때 필요한 현재 사용자 식별 정보를 묶습니다.
class TaggingAuthor {
  final int id;
  final String? handle;
  final String? profileImageSource;

  const TaggingAuthor({
    required this.id,
    this.handle,
    this.profileImageSource,
  });
}
