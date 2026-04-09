import 'package:soi_api_client/api.dart';

import '../../utils/format_utils.dart';

/// 서버 postType 계약과 앱 내 게시물 분류를 이어주는 게시물 유형입니다.
enum PostType {
  textOnly, // 텍스트만 포함된 게시물
  multiMedia, // 레거시 미디어 그룹 표현
  image, // 이미지 게시물
  video // 비디오 게시물
  ;

  /// 2분류 UI에서 이 타입을 텍스트 게시물로 취급할 수 있는지 반환합니다.
  bool get isTextCategory => this == PostType.textOnly;

  /// 2분류 UI에서 이 타입을 미디어 게시물로 취급할 수 있는지 반환합니다.
  bool get isMediaCategory =>
      this == PostType.multiMedia ||
      this == PostType.image ||
      this == PostType.video;
}

/// 게시물 상태 enum
///
/// API에서 사용하는 게시물 상태값입니다.
/// - ACTIVE: 활성화된 게시물 (기본)
/// - DELETED: 삭제된 게시물 (휴지통)
/// - INACTIVE: 비활성화된 게시물
enum PostStatus {
  active('ACTIVE'),
  deleted('DELETED'),
  inactive('INACTIVE');

  final String value;
  const PostStatus(this.value);

  static PostStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'DELETED':
        return PostStatus.deleted;
      case 'INACTIVE':
        return PostStatus.inactive;
      case 'ACTIVE':
      default:
        return PostStatus.active;
    }
  }
}

/// 게시물(포스트) 모델
///
/// API의 PostRespDto를 앱 내부에서 사용하기 위한 모델입니다.
class Post {
  final int id;
  final String nickName;
  final String? content;
  final String? postFileKey;
  final String? postFileUrl;
  final String? userProfileImageKey;
  final String? userProfileImageUrl;
  final String? audioUrl;
  final String? waveformData;
  final int? commentCount;
  final int? duration;
  final bool isActive;
  final DateTime? createdAt;
  final PostType? postType;
  final double? savedAspectRatio; // 저장된 미디어의 가로세로 비율
  final bool? isFromGallery; // 갤러리에서 업로드된 미디어인지 여부

  const Post({
    required this.id,
    required this.nickName,
    this.content,
    this.postFileKey,
    this.postFileUrl,
    this.userProfileImageKey,
    this.userProfileImageUrl,
    this.audioUrl,
    this.waveformData,
    this.commentCount,
    this.duration,
    this.isActive = true,
    this.createdAt,
    this.postType,
    this.savedAspectRatio,
    this.isFromGallery,
  });

  /// PostRespDto에서 Post 모델 생성
  factory Post.fromDto(PostRespDto dto) {
    return Post(
      id: dto.id ?? 0,
      nickName: dto.nickname ?? '',
      content: dto.content,
      postFileKey: dto.postFileKey,
      postFileUrl: dto.postFileUrl,
      userProfileImageKey: dto.userProfileImageKey,
      userProfileImageUrl: dto.userProfileImageUrl,
      audioUrl: dto.audioFileKey,
      waveformData: dto.waveformData,
      commentCount: dto.commentCount,
      duration: dto.duration,
      isActive: dto.isActive ?? true,
      createdAt: FormatUtils.normalizeServerDateTime(dto.createdAt),
      postType: _postTypeFromRespEnum(dto.postType),
      savedAspectRatio: dto.savedAspectRatio,
      isFromGallery: dto.isFromGallery,
    );
  }

  /// JSON에서 Post 모델 생성
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int? ?? 0,
      nickName:
          (json['nickName'] as String?) ?? (json['nickname'] as String?) ?? '',
      content: json['content'] as String?,
      userProfileImageKey: json['userProfileImageKey'] as String?,
      userProfileImageUrl: json['userProfileImageUrl'] as String?,
      postFileKey: json['postFileKey'] as String?,
      postFileUrl: json['postFileUrl'] as String?,
      audioUrl: json['audioFileKey'] as String?,
      waveformData: json['waveformData'] as String?,
      commentCount: json['commentCount'] as int?,
      duration: json['duration'] as int?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: FormatUtils.parseServerDateTime(json['createdAt']),
      postType: _postTypeFromJsonValue(json['postType']),
      savedAspectRatio: (json['savedAspectRatio'] as num?)?.toDouble(),
      isFromGallery: json['isFromGallery'] as bool?,
    );
  }

  /// Post 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickName': nickName,
      'content': content,
      'postFileKey': postFileKey,
      'postFileUrl': postFileUrl,
      'userProfileImageKey': userProfileImageKey,
      'userProfileImageUrl': userProfileImageUrl,
      'audioFileKey': audioUrl,
      'waveformData': waveformData,
      'commentCount': commentCount,
      'duration': duration,
      'isActive': isActive,
      'createdAt': FormatUtils.serializeServerDateTime(createdAt),
      'postType': _postTypeToApiValue(postType),
      'savedAspectRatio': savedAspectRatio,
      'isFromGallery': isFromGallery,
    };
  }

  /// 서버 postType을 우선으로 해석하고, 누락된 레거시 데이터만 확장자로 보완해 이미지 여부를 판단합니다.
  bool get hasImage {
    switch (postType) {
      case PostType.image:
        return hasMedia;
      case PostType.video:
      case PostType.textOnly:
        return false;
      case PostType.multiMedia:
      case null:
        return hasMedia && !isVideo;
    }
  }

  /// 서버가 key 또는 url 중 하나라도 내려준 미디어를 렌더링 가능한 미디어로 판단합니다.
  bool get hasMedia =>
      _hasRenderableMediaSource(postFileKey) ||
      _hasRenderableMediaSource(postFileUrl);

  /// 서버가 저장한 업로드 출처를 기준으로 기본 미디어 fit을 결정합니다.
  bool get prefersContainMediaFit => isFromGallery == true;

  /// 서버 postType을 우선으로 해석하고, 누락된 레거시 데이터만 확장자로 보완해 **비디오 여부**를 판단합니다.
  bool get isVideo {
    switch (postType) {
      case PostType.video:
        return hasMedia;
      case PostType.image:
      case PostType.textOnly:
        return false;
      case PostType.multiMedia:
      case null:
        return _isVideoKey(postFileKey) || _isVideoKey(postFileUrl);
    }
  }

  /// 오디오 유무 확인
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  /// 오디오 길이 (초 단위)
  int get durationInSeconds => duration ?? 0;

  /// copyWith 메서드
  Post copyWith({
    int? id,
    String? nickName,
    String? content,
    String? postFileKey,
    String? postFileUrl,
    String? audioUrl,
    String? waveformData,
    int? commentCount,
    String? userProfileImageKey,
    String? userProfileImageUrl,
    int? duration,
    bool? isActive,
    DateTime? createdAt,
    PostType? postType,
    double? savedAspectRatio,
    bool? isFromGallery,
  }) {
    return Post(
      id: id ?? this.id,
      nickName: nickName ?? this.nickName,
      content: content ?? this.content,
      postFileKey: postFileKey,
      postFileUrl: postFileUrl,
      audioUrl: audioUrl,
      waveformData: waveformData ?? this.waveformData,
      commentCount: commentCount ?? this.commentCount,
      userProfileImageKey: userProfileImageKey ?? this.userProfileImageKey,
      userProfileImageUrl: userProfileImageUrl ?? this.userProfileImageUrl,
      duration: duration ?? this.duration,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      postType: postType ?? this.postType,
      savedAspectRatio: savedAspectRatio ?? this.savedAspectRatio,
      isFromGallery: isFromGallery ?? this.isFromGallery,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          runtimeType == other.runtimeType &&
          nickName == other.nickName &&
          createdAt == other.createdAt &&
          postType == other.postType;

  @override
  int get hashCode =>
      nickName.hashCode ^
      (createdAt?.hashCode ?? 0) ^
      (postType?.hashCode ?? 0);

  @override
  String toString() {
    return 'Post{nickName: $nickName, hasImage: $hasImage, hasAudio: $hasAudio, postType: $postType }';
  }

  /// 서버 enum과 레거시 캐시 문자열을 모두 앱 PostType으로 정규화합니다.
  static PostType? _postTypeFromRespEnum(PostRespDtoPostTypeEnum? value) {
    return _postTypeFromRawValue(value?.value);
  }

  /// JSON/캐시/DTO 경로에서 들어오는 postType 표현을 한곳에서 해석합니다.
  static PostType? _postTypeFromJsonValue(dynamic raw) {
    if (raw is PostRespDtoPostTypeEnum) {
      return _postTypeFromRespEnum(raw);
    }
    return _postTypeFromRawValue(raw); // 레거시 문자열 경로도 지원합니다.
  }

  /// 새 API 값과 레거시 별칭을 함께 받아 게시물 분류를 복원합니다.
  static PostType? _postTypeFromRawValue(Object? raw) {
    if (raw == null) {
      return null;
    }

    final normalized = raw
        .toString()
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    switch (normalized) {
      case 'TEXT':
      case 'TEXTONLY':
        return PostType.textOnly;
      case 'IMAGE':
        return PostType.image;
      case 'VIDEO':
        return PostType.video;
      case 'MULTIMEDIA':
        // 레거시 데이터에서 미디어 유형이지만 세부 유형이 없는 경우, 일단 미디어로 분류합니다.
        return PostType.multiMedia;
      default:
        return null;
    }
  }

  static String? _postTypeToApiValue(PostType? type) {
    switch (type) {
      case PostType.textOnly:
        return 'TEXT';
      case PostType.multiMedia:
        return null;
      case PostType.image:
        return 'IMAGE';
      case PostType.video:
        return 'VIDEO';
      default:
        return null;
    }
  }

  /// 비디오 확장자 집합
  static const Set<String> _videoExtensions = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.m4v',
    '.webm',
    '.3gp',
  };

  /// 비디오 키인지 확인
  ///
  /// Parameters:
  ///   - [key]: 미디어 파일의 키 또는 URL
  ///
  /// Returns:
  ///   - [bool]: 비디오 파일인지 여부
  ///   - true: 비디오 파일
  ///   - false: 비디오 파일 아님
  static bool _isVideoKey(String? key) {
    final extension = _extractExtension(key);
    if (extension == null) return false;
    return _videoExtensions.contains(extension);
  }

  /// 서비스 레이어가 업로드 키만으로 비디오 여부를 판별할 때 재사용하는 헬퍼입니다.
  static bool isVideoKey(String? key) => _isVideoKey(key);

  /// key/url 중 하나라도 비어 있지 않으면 렌더링 가능한 미디어 소스로 취급합니다.
  static bool _hasRenderableMediaSource(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// 확장자 추출
  ///
  /// Parameters:
  ///  - [raw]: 파일 키 또는 URL 문자열
  ///
  /// Returns:
  ///  - [String]: 추출된 확장자 (없으면 null)
  static String? _extractExtension(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    var value = raw;
    final queryIndex = value.indexOf('?');
    if (queryIndex != -1) {
      value = value.substring(0, queryIndex);
    }

    final hashIndex = value.indexOf('#');
    if (hashIndex != -1) {
      value = value.substring(0, hashIndex);
    }

    // S3 key or URL path both supported
    final lastDot = value.lastIndexOf('.');
    if (lastDot == -1 || lastDot == value.length - 1) return null;

    final ext = value.substring(lastDot).toLowerCase();
    if (ext.length > 8) return null;
    return ext;
  }
}
