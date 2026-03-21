import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../models/models.dart';

/// 게시물 관련 API 래퍼 서비스
///
/// 게시물 생성, 조회, 수정, 삭제 등 게시물 관련 기능을 제공합니다.
/// Provider를 통해 주입받아 사용합니다.
///
/// 사용 예시:
/// ```dart
/// final postService = Provider.of<PostService>(context, listen: false);
///
/// // 게시물 생성
/// final success = await postService.createPost(
///   nickName: 'user123',
///   content: '오늘의 일상',
///   postFileKey: 'images/photo.jpg',
///   categoryIds: [1, 2],
/// );
///
/// // 메인 피드 조회
/// final posts = await postService.getMainFeedPosts(nickName: 1);
///
/// // 카테고리별 게시물 조회
/// final categoryPosts = await postService.getPostsByCategory(
///   categoryId: 1,
///   nickName: 1,
/// );
/// ```
class PostService {
  final PostAPIApi _postApi;

  PostService({PostAPIApi? postApi})
    : _postApi = postApi ?? SoiApiClient.instance.postApi;

  List<Post> _mapPosts(Iterable<PostRespDto> dtos) {
    return List<Post>.unmodifiable(dtos.map(Post.fromDto));
  }

  // ============================================
  // 게시물 생성
  // ============================================

  /// 게시물 생성
  ///
  /// 새로운 게시물(사진 + 음성메모)을 생성합니다.
  ///
  /// Parameters:
  /// - [nickName]: 작성자 사용자 ID (String)
  /// - [content]: 게시물 내용 (선택)
  /// - [postFileKey]: 이미지 파일 키
  /// - [audioFileKey]: 음성 파일 키 (선택)
  /// - [categoryIds]: 게시할 카테고리 ID 목록
  /// - [waveformData]: 음성 파형 데이터 (선택)
  /// - [duration]: 음성 길이 (선택)
  ///
  /// Returns: 생성 성공 여부
  /// - [true]: 게시물 생성 성공
  /// - [false]: 게시물 생성 실패 (API 응답은 성공이지만, 실제로는 실패한 경우)
  ///
  /// Throws:
  /// - [BadRequestException]: 필수 정보 누락
  /// - [SoiApiException]: 게시물 생성 실패
  Future<bool> createPost({
    int? userId,
    required String nickName,
    String? content,
    List<String> postFileKey =
        const [], // categoryIds의 개수에 맞춰서 빈 문자열의 개수를 맞춰서 전달해야함.
    List<String> audioFileKey =
        const [], // categoryIds의 개수에 맞춰서 빈 문자열의 개수를 맞춰서 전달해야함.
    List<int> categoryIds = const [],
    String? waveformData,
    int? duration,
    double? savedAspectRatio,
    bool? isFromGallery,
    PostType? postType,
  }) async {
    try {
      final dto = PostCreateReqDto(
        userId: userId,
        nickname: nickName,
        content: content,
        postFileKey: postFileKey, // categoryIds의 개수에 맞춰서 빈 문자열의 개수를 맞춰서 전달해야함.
        audioFileKey:
            audioFileKey, // categoryIds의 개수에 맞춰서 빈 문자열의 개수를 맞춰서 전달해야함.
        categoryId: categoryIds,
        waveformData: waveformData,
        duration: duration,
        savedAspectRatio: savedAspectRatio,
        isFromGallery: isFromGallery,
        postType: _toCreatePostTypeEnum(
          _resolveCreatePostType(postType: postType, postFileKeys: postFileKey),
        ),
      );

      final response = await _postApi.create1(dto);

      if (response == null) {
        throw const DataValidationException(message: '게시물 생성 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '게시물 생성 실패');
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } on SoiApiException {
      rethrow;
    } catch (e) {
      throw SoiApiException(message: '게시물 생성 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 게시물 조회
  // ============================================

  /// 메인 피드 게시물 조회
  ///
  /// [userId]가 속한 모든 카테고리의 게시물을 조회합니다.
  /// 메인 페이지에 표시할 피드용입니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  /// - [postStatus]: 게시물 상태 (기본값: ACTIVE)
  /// - [page]: 페이지 번호 (기본값: 0)
  ///
  /// Returns: 게시물 목록 (List of Post)
  Future<List<Post>> getAllPosts({
    required int userId,
    PostStatus postStatus = PostStatus.active,
    int page = 0,
  }) async {
    try {
      final response = await _postApi.findAllByUserId(
        postStatus.value,
        page: page,
      );

      if (response == null) {
        return [];
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '피드 조회 실패');
      }

      return _mapPosts(response.data);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } on SoiApiException {
      rethrow;
    } catch (e) {
      throw SoiApiException(message: '피드 조회 실패: $e', originalException: e);
    }
  }

  /// 카테고리별 게시물 조회
  ///
  /// 특정 카테고리에 속한 게시물만 조회합니다.
  ///
  /// Parameters:
  ///   - [categoryId]: 카테고리 ID
  ///   - [userId]: 요청 사용자 ID (권한 확인용)
  ///   - [notificationId]: 알림 ID (선택, 알림에서 접근 시 사용)
  ///   - [page]: 페이지 번호 (기본값: 0)
  ///
  /// Returns: 게시물 목록 (List of Post)
  Future<List<Post>> getPostsByCategory({
    required int categoryId,
    required int userId,
    int? notificationId,
    int page = 0,
  }) async {
    try {
      final response = await _postApi.findByCategoryId(
        categoryId,

        notificationId: notificationId,
        page: page,
      );

      if (response == null) {
        return [];
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '카테고리 게시물 조회 실패');
      }

      return _mapPosts(response.data);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } on SoiApiException {
      rethrow;
    } catch (e) {
      throw SoiApiException(
        message: '카테고리 게시물 조회 실패: $e',
        originalException: e,
      );
    }
  }

  /// 게시물 상세 조회
  ///
  /// [postId]에 해당하는 게시물의 상세 정보를 조회합니다.
  ///
  /// Returns: 게시물 정보 (Post)
  ///
  /// Throws:
  /// - [NotFoundException]: 게시물을 찾을 수 없음
  Future<Post> getPostDetail(int postId) async {
    try {
      final response = await _postApi.showDetail(postId);

      if (response == null) {
        throw const NotFoundException(message: '게시물을 찾을 수 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '게시물 조회 실패');
      }

      if (response.data == null) {
        throw const NotFoundException(message: '게시물 정보가 없습니다.');
      }

      return Post.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '게시물 조회 실패: $e', originalException: e);
    }
  }

  /// 유저 ID로 게시물 조회 (Slice 페이지네이션)
  ///
  /// [userId]와 [postType]으로 게시물을 조회합니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  /// - [postType]: 게시물 타입 (PostType)
  /// - [page]: 페이지 번호 (0부터 시작)
  ///
  /// Returns: `({List<Post> posts, bool hasMore})`
  Future<({List<Post> posts, bool hasMore})> getMediaByUserId({
    required int userId,
    required PostType postType,
    int page = 0,
  }) async {
    try {
      final postTypeStr = switch (postType) {
        PostType.multiMedia => 'MULTIMEDIA',
        PostType.textOnly => 'TEXT_ONLY',
      };
      final response = await _postApi.findMediaByUserId(postTypeStr, page);

      if (response == null) {
        return (posts: <Post>[], hasMore: false);
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '게시물 조회 실패');
      }

      final slice = response.data;
      if (slice == null) {
        return (posts: <Post>[], hasMore: false);
      }

      final posts = _mapPosts(slice.content);
      final hasMore = slice.last == false;
      return (posts: posts, hasMore: hasMore);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } on SoiApiException {
      rethrow;
    } catch (e) {
      throw SoiApiException(message: '게시물 조회 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 게시물 수정
  // ============================================

  /// 게시물 수정
  ///
  /// 기존 게시물의 내용을 수정합니다.
  ///
  /// Parameters:
  /// - [postId]: 수정할 게시물 ID
  /// - [content]: 변경할 내용 (선택)
  /// - [postFileKey]: 변경할 이미지 키 (선택)
  /// - [audioFileKey]: 변경할 음성 키 (선택)
  /// - [categoryId]: 변경할 카테고리 ID (선택, 단일 값)
  /// - [waveformData]: 변경할 파형 데이터 (선택)
  /// - [duration]: 변경할 음성 길이 (선택)
  ///
  /// Returns: 수정 성공 여부
  Future<bool> updatePost({
    required int postId,
    String? content,
    String? postFileKey,
    String? audioFileKey,
    int? categoryId,
    String? waveformData,
    int? duration,
    bool? isFromGallery,
    double? savedAspectRatio,
    PostType? postType,
  }) async {
    try {
      final dto = PostUpdateReqDto(
        postId: postId,
        content: content,
        postFileKey: postFileKey,
        audioFileKey: audioFileKey,
        categoryId: categoryId,
        waveformData: waveformData,
        duration: duration,
        isFromGallery: isFromGallery,
        savedAspectRatio: savedAspectRatio,
        postType: _toUpdatePostTypeEnum(
          _resolveUpdatePostType(postType: postType, postFileKey: postFileKey),
        ),
      );

      final response = await _postApi.update3(dto);

      if (response == null) {
        throw const DataValidationException(message: '게시물 수정 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '게시물 수정 실패');
      }

      return true;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } on SoiApiException {
      rethrow;
    } catch (e) {
      throw SoiApiException(message: '게시물 수정 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 게시물 상태 변경
  // ============================================

  /// 게시물 상태 변경
  ///
  /// [postId]에 해당하는 게시물의 상태를 변경합니다.
  /// ACTIVE: 활성화, DELETED: 삭제(휴지통), INACTIVE: 비활성화
  ///
  /// Parameters:
  /// - [postId]: 게시물 ID
  /// - [postStatus]: 변경할 상태
  ///
  /// Returns: 변경 성공 여부
  Future<bool> setPostStatus({
    required int postId,
    required PostStatus postStatus,
  }) async {
    try {
      final response = await _postApi.setPost(postId, postStatus.value);

      if (response == null) {
        throw const DataValidationException(message: '게시물 상태 변경 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '게시물 상태 변경 실패');
      }

      return true;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } on SoiApiException {
      rethrow;
    } catch (e) {
      throw SoiApiException(message: '게시물 상태 변경 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 게시물 삭제
  // ============================================

  /// 게시물 삭제
  ///
  /// [postId]에 해당하는 게시물을 삭제합니다.
  /// 삭제된 게시물은 휴지통으로 이동됩니다.
  ///
  /// Returns: 삭제 성공 여부
  ///
  /// Throws:
  /// - [NotFoundException]: 게시물을 찾을 수 없음
  /// - [ForbiddenException]: 삭제 권한 없음
  Future<bool> deletePost(int postId) async {
    try {
      final response = await _postApi.delete3(postId);

      if (response == null) {
        throw const DataValidationException(message: '게시물 삭제 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '게시물 삭제 실패');
      }

      return true;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } on SoiApiException {
      rethrow;
    } catch (e) {
      throw SoiApiException(message: '게시물 삭제 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 에러 핸들링 헬퍼
  // ============================================

  SoiApiException _handleApiException(ApiException e) {
    if (kDebugMode) debugPrint('🔴 API Error [${e.code}]: ${e.message}');

    switch (e.code) {
      case 400:
        return BadRequestException(
          message: e.message ?? '잘못된 요청입니다.',
          originalException: e,
        );
      case 401:
        return AuthException(
          message: e.message ?? '인증이 필요합니다.',
          originalException: e,
        );
      case 403:
        return ForbiddenException(
          message: e.message ?? '접근 권한이 없습니다.',
          originalException: e,
        );
      case 404:
        return NotFoundException(
          message: e.message ?? '게시물을 찾을 수 없습니다.',
          originalException: e,
        );
      case >= 500:
        return ServerException(
          statusCode: e.code,
          message: e.message ?? '서버 오류가 발생했습니다.',
          originalException: e,
        );
      default:
        return SoiApiException(
          statusCode: e.code,
          message: e.message ?? '알 수 없는 오류가 발생했습니다.',
          originalException: e,
        );
    }
  }

  PostType _resolveCreatePostType({
    required List<String> postFileKeys,
    PostType? postType,
  }) {
    if (postType != null) return postType;
    final hasMedia = postFileKeys.any((key) => key.isNotEmpty);
    return hasMedia ? PostType.multiMedia : PostType.textOnly;
  }

  PostType? _resolveUpdatePostType({PostType? postType, String? postFileKey}) {
    if (postType != null) return postType;
    if (postFileKey == null) return null;
    return postFileKey.trim().isEmpty ? PostType.textOnly : PostType.multiMedia;
  }

  PostCreateReqDtoPostTypeEnum? _toCreatePostTypeEnum(PostType? postType) {
    switch (postType) {
      case PostType.textOnly:
        return PostCreateReqDtoPostTypeEnum.TEXT_ONLY;
      case PostType.multiMedia:
        return PostCreateReqDtoPostTypeEnum.MULTIMEDIA;
      default:
        return null;
    }
  }

  PostUpdateReqDtoPostTypeEnum? _toUpdatePostTypeEnum(PostType? postType) {
    switch (postType) {
      case PostType.textOnly:
        return PostUpdateReqDtoPostTypeEnum.TEXT_ONLY;
      case PostType.multiMedia:
        return PostUpdateReqDtoPostTypeEnum.MULTIMEDIA;
      default:
        return null;
    }
  }
}
