import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../models/models.dart';

/// 댓글 관련 API 래퍼 서비스
///
/// 댓글 생성, 조회 등 댓글 관련 기능을 제공합니다.
/// Provider를 통해 주입받아 사용합니다.
///
/// 사용 예시:
/// ```dart
/// final commentService = Provider.of<CommentService>(context, listen: false);
///
/// // 댓글 생성
/// await commentService.createComment(
///   postId: 1,
///   userId: 1,
///   text: '좋은 사진이네요!',
/// );
///
/// // 댓글 조회
/// final comments = await commentService.getComments(postId: 1);
/// ```
class CommentService {
  final CommentAPIApi _commentApi;
  static const int _defaultPage = 0;
  static const int _maxSliceFetchPages = 100;

  // 게시물 ID별로 진행 중인 댓글 조회 요청을 추적하여 중복 요청 방지
  final Map<int, Future<List<Comment>>> _inFlightCommentsByPost = {};
  final Map<int, Future<List<Comment>>> _inFlightTagCommentsByPost = {};

  // 사용자 ID + 페이지 번호별로 진행 중인 댓글 조회 요청을 추적하여 중복 요청 방지
  final Map<String, Future<({List<Comment> comments, bool hasMore})>>
  _inFlightCommentsByUserPage = {};

  // 게시물 ID + 페이지 번호별로 진행 중인 원댓글 조회 요청을 추적하여 중복 요청 방지
  final Map<String, Future<({List<Comment> comments, bool hasMore})>>
  _inFlightParentCommentsByPostPage = {};

  // 부모 댓글 ID + 페이지 번호별로 진행 중인 대댓글 조회 요청을 추적하여 중복 요청 방지
  final Map<String, Future<({List<Comment> comments, bool hasMore})>>
  _inFlightChildCommentsByParentPage = {};

  CommentService({CommentAPIApi? commentApi})
    : _commentApi = commentApi ?? SoiApiClient.instance.commentApi;

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// 유틸리티 메서드 - API 요청 키 생성
  /// 사용자 ID와 페이지 번호를 조합하여 고유한 키를 생성합니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  /// - [page]: 페이지 번호
  ///
  /// Returns: 생성된 요청 키 (예: "123:0" - 사용자 ID 123의 페이지 0 요청)
  /// - 이 키는 사용자별 페이지 단위 댓글 조회 요청의 중복을 방지하는 데 사용됩니다.
  String _buildUserCommentsRequestKey({
    required int userId,
    required int page,
  }) {
    return '$userId:$page';
  }

  /// 게시물별 원댓글 Slice 요청을 같은 키로 묶어 중복 호출을 막습니다.
  String _buildParentCommentsRequestKey({
    required int postId,
    required int page,
  }) {
    return '$postId:$page';
  }

  /// 부모 댓글별 대댓글 Slice 요청을 같은 키로 묶어 중복 호출을 막습니다.
  String _buildChildCommentsRequestKey({
    required int parentCommentId,
    required int page,
  }) {
    return '$parentCommentId:$page';
  }

  /// 유틸리티 메서드 - 파형 데이터 정규화
  /// API에서 반환된 파형 데이터가 JSON 배열 형태인 경우, 이를 쉼표로 구분된 문자열로 변환합니다.
  /// - 예시: "[0.1, 0.5, 0.3]" -> "0.1,0.5,0.3"
  ///
  /// Parameters:
  /// - [waveformData]: API에서 반환된 원본 파형 데이터 문자열
  ///
  /// Returns: 정규화된 파형 데이터 문자열
  String _normalizeWaveformData(String waveformData) {
    if (waveformData.isEmpty) {
      return waveformData;
    }

    final shouldParseJsonArray =
        waveformData.startsWith('[') && waveformData.endsWith(']');
    if (!shouldParseJsonArray) {
      return waveformData;
    }

    try {
      final parsed = jsonDecode(waveformData) as List;
      return parsed.join(',');
    } catch (e) {
      _debugLog('waveformData 변환 실패, 원본 사용: $e');
      return waveformData;
    }
  }

  /// 유틸리티 메서드 - 댓글 생성 요청 로그
  ///
  /// 댓글 생성 요청 시 전달된 주요 정보를 로그로 출력합니다.
  /// - 디버깅 목적으로 사용되며, 실제 운영 환경에서는 민감한 정보가 포함되지 않도록 주의해야 합니다.
  /// - 로그에는 게시물 ID, 사용자 ID, 댓글 유형, 텍스트 내용, 음성 파일 키, 파형 데이터 등이 포함됩니다.
  /// - 예시 로그:
  ///   === 댓글 생성 요청 ===
  ///   postId: 123, userId: 456
  ///   commentType: TEXT
  ///   audioFileKey: (빈 문자열)
  ///   fileKey: (빈 문자열)
  ///   text: "좋은 사진이네요!"
  ///   waveformData: (빈 문자열)
  void _logCreateCommentRequest({
    required int postId,
    required int userId,
    required CommentReqDtoCommentTypeEnum commentType,
    required String audioFileKey,
    required String fileKey,
    required String text,
    required String waveformData,
    required int parentId,
    required int replyUserId,
  }) {
    if (!kDebugMode) return; // 디버그 모드에서만 로그 출력

    debugPrint('=== 댓글 생성 요청 ===');
    debugPrint('postId: $postId, userId: $userId');
    debugPrint('commentType: ${commentType.value}');
    debugPrint('audioFileKey: $audioFileKey');
    debugPrint('fileKey: $fileKey');
    debugPrint('text: $text');
    debugPrint('waveformData: $waveformData');
    debugPrint('parentId: $parentId, replyUserId: $replyUserId');
  }

  // ============================================
  // 댓글 생성
  // ============================================

  /// 댓글 생성
  ///
  /// 게시물에 새로운 댓글을 작성합니다.
  /// 음성 댓글인 경우 [audioFileKey]를 포함합니다.
  ///
  /// Parameters:
  /// - [postId]: 게시물 ID
  /// - [userId]: 작성자 ID
  /// - [text]: 댓글 내용 (텍스트)
  /// - [audioFileKey]: 음성 파일 키 (선택, 음성 댓글인 경우)
  /// - [waveformData]: 음성 파형 데이터 (선택)
  /// - [duration]: 음성 길이 (선택)
  ///
  /// Returns: 생성 성공 여부
  ///
  /// Throws:
  /// - [BadRequestException]: 필수 정보 누락
  /// - [NotFoundException]: 게시물을 찾을 수 없음
  Future<CommentCreationResult> createComment({
    required int postId,
    required int userId,
    int? emojiId,
    int? parentId,
    int? replyUserId,
    String? text,
    String? audioFileKey,
    String? fileKey,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
    CommentType? type,
  }) async {
    try {
      final normalizedEmojiId = emojiId ?? 0;
      final normalizedParentId = parentId ?? 0;
      final normalizedReplyUserId = replyUserId ?? 0;
      final normalizedText = text?.trim() ?? '';
      final normalizedAudioKey = audioFileKey?.trim() ?? '';
      final normalizedFileKey = fileKey?.trim() ?? '';
      final normalizedWaveform = waveformData?.trim() ?? '';
      final normalizedDuration = duration ?? 0;
      final normalizedLocationX = locationX ?? 0.0;
      final normalizedLocationY = locationY ?? 0.0;
      final commentTypeEnum = _toCommentTypeEnum(type);

      // 대댓글은 위치 정보를 가지지 않습니다.
      final isReply =
          normalizedParentId > 0 ||
          normalizedReplyUserId > 0 ||
          type == CommentType.reply;

      // dto의 위치 정보는 대댓글이 아닌 경우에만 포함합니다.
      // 대댓글인 경우 API가 null/0 처리에 민감할 수 있어 명시적으로 null로 설정합니다.
      // normalizedLocationX: 대댓글이 아닌, 댓글의 위치 X (0.0으로 기본값)
      // normalizedLocationY: 대댓글이 아닌, 댓글의 위치 Y (0.0으로 기본값)
      final dtoLocationX = isReply ? null : normalizedLocationX;
      final dtoLocationY = isReply ? null : normalizedLocationY;

      // 파형 데이터 정규화 - API에서 JSON 배열 형태로 반환되는 경우 쉼표로 구분된 문자열로 변환
      final processedWaveformData = _normalizeWaveformData(normalizedWaveform);

      // DTO 생성 - API 명세에 맞게 요청 데이터 구성
      final dto = CommentReqDto(
        postId: postId,
        userId: userId,
        emojiId: normalizedEmojiId,
        parentId: normalizedParentId,
        replyUserId: normalizedReplyUserId,
        text: normalizedText,
        audioKey: normalizedAudioKey,
        fileKey: normalizedFileKey,
        waveformData: processedWaveformData,
        duration: normalizedDuration,
        locationX: dtoLocationX,
        locationY: dtoLocationY,
        commentType: commentTypeEnum,
      );

      // 요청 로그 출력
      if (kDebugMode) {
        _logCreateCommentRequest(
          postId: postId,
          userId: userId,
          commentType: commentTypeEnum,
          audioFileKey: normalizedAudioKey,
          fileKey: normalizedFileKey,
          text: normalizedText,
          waveformData: processedWaveformData,
          parentId: normalizedParentId,
          replyUserId: normalizedReplyUserId,
        );
      }

      // API 호출 - 댓글 생성
      final response = await _commentApi.create3(dto);

      if (response == null) {
        throw const DataValidationException(message: '댓글 생성 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '댓글 생성 실패');
      }

      final parsedComment = _parseCommentFromResponse(
        response,
        requestedParentId: isReply ? normalizedParentId : null,
      );
      return CommentCreationResult(success: true, comment: parsedComment);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '댓글 생성 실패: $e', originalException: e);
    }
  }

  /// 텍스트 댓글 생성 (편의 메서드)
  Future<CommentCreationResult> createTextComment({
    required int postId,
    required int userId,
    required String text,
    required double locationX,
    required double locationY,
  }) async {
    return createComment(
      postId: postId,
      userId: userId,
      // TEXT 댓글은 서버가 null/empty 처리에 민감할 수 있어 Swagger 입력 형태로 맞춥니다.
      emojiId: 0,
      text: text,
      audioFileKey: '',
      waveformData: '',
      duration: 0,
      locationX: locationX,
      locationY: locationY,
      type: CommentType.text,
    );
  }

  /// 음성 댓글 생성 (편의 메서드)
  Future<CommentCreationResult> createAudioComment({
    required int postId,
    required int userId,
    required String audioFileKey,
    required String waveformData,
    required int duration,
    required double locationX,
    required double locationY,
  }) async {
    return createComment(
      postId: postId,
      userId: userId,
      emojiId: 0,
      text: '',
      audioFileKey: audioFileKey,
      waveformData: waveformData,
      duration: duration,
      locationX: locationX,
      locationY: locationY,
      type: CommentType.audio,
    );
  }

  /// 댓글 생성 응답에서 Comment 객체 파싱
  ///
  /// Parameters:
  /// - [response]: API 응답 객체
  /// - [requestedParentId]: 대댓글인 경우, 요청 시 사용된 부모 댓글 ID (선택)
  ///
  /// Returns: 파싱된 Comment 객체 (없을 경우 null)
  Comment? _parseCommentFromResponse(
    ApiResponseDtoObject response, {
    int? requestedParentId,
  }) {
    final data = response.data; // API응답(response)에서 data 필드 추출 (댓글 정보가 담긴 부분)
    if (data == null) {
      _debugLog('댓글 생성 응답에 data가 없습니다.');
      return null;
    }

    // data가 CommentRespDto 형태인 경우 직접 Comment 모델로 변환하여 반환합니다.
    if (data is CommentRespDto) {
      return _normalizeCommentDto(data, parentCommentId: requestedParentId);
    }

    // data가 Map 형태인 경우, CommentRespDto로 파싱하여 Comment 모델로 변환합니다.
    if (data is Map) {
      // CommentRespDto로 파싱합니다.
      final dto = CommentRespDto.fromJson(Map<String, dynamic>.from(data));

      // data가 null이 아니면, CommentRespDto에서 Comment 모델로 변환하여 반환합니다.
      if (dto != null) {
        return _normalizeCommentDto(dto, parentCommentId: requestedParentId);
      }
    }

    // data가 List 형태인 경우, 첫 번째 요소를 CommentRespDto로 파싱하여 Comment 모델로 변환합니다.
    // 왜 첫 번째 요소를 시용?
    // - API 응답이 단일 댓글 객체 대신 댓글 리스트 형태로 반환되는 경우가 있기 때문입니다.
    if (data is List) {
      final list = CommentRespDto.listFromJson(data);
      if (list.isNotEmpty) {
        return _normalizeCommentDto(
          list.first,
          parentCommentId: requestedParentId,
        );
      }
    }

    _debugLog('댓글 생성 응답 data 파싱 실패: ${data.runtimeType}');
    return null;
  }

  // ============================================
  // 댓글 조회
  // ============================================

  /// 게시물의 댓글 조회
  /// [postId]에 해당하는 게시물의 모든 댓글을 조회합니다.
  ///
  /// Parameters:
  /// - [postId]: 게시물 ID
  ///
  /// Returns: 댓글 목록
  /// - [Future<List<Comment>>]: 원댓글과 대댓글이 계층 구조로 병합된 형태로 반환됩니다.
  ///
  /// Throws:
  /// - [NotFoundException]: 게시물을 찾을 수 없음
  Future<List<Comment>> getComments({required int postId}) async {
    final task = _inFlightCommentsByPost.putIfAbsent(
      postId,
      () => _getCommentsInternal(postId: postId),
    );

    try {
      return await task;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '댓글 조회 실패: $e', originalException: e);
    } finally {
      final registeredTask = _inFlightCommentsByPost[postId];
      if (identical(registeredTask, task)) {
        _inFlightCommentsByPost.remove(postId);
      }
    }
  }

  /// 태그 오버레이에 필요한 데이터만 조회하는 메서드
  /// - [postId]에 해당하는 게시물의 위치가 있는 댓글만 조회하여 반환.
  /// - 위치가 있는 댓글만 조회한 후, 반환하기 때문에 댓글을 전부 조회하는 병목을 피할 수 있다.
  ///
  /// Parameters:
  /// - [postId]: 게시물 ID
  ///
  /// Returns: 위치 댓글 목록
  /// - [Future<List<Comment>>]: 위치가 있는 댓글만 반환. 대댓글은 포함되지 않는다.
  Future<List<Comment>> getTagComments({required int postId}) async {
    final task = _inFlightTagCommentsByPost.putIfAbsent(
      postId,
      () => _getTagCommentsInternal(postId: postId),
    );

    try {
      return await task;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '태그 댓글 조회 실패: $e', originalException: e);
    } finally {
      final registeredTask = _inFlightTagCommentsByPost[postId];
      if (identical(registeredTask, task)) {
        _inFlightTagCommentsByPost.remove(postId);
      }
    }
  }

  /// 태그 오버레이는 부모 댓글 중 위치가 있는 항목만 순서대로 사용합니다.
  Future<List<Comment>> _getTagCommentsInternal({required int postId}) async {
    final taggedParents = <Comment>[];
    var page = _defaultPage;

    for (var i = 0; i < _maxSliceFetchPages; i++) {
      final result = await getParentComments(postId: postId, page: page);
      if (result.comments.isEmpty) {
        return List<Comment>.unmodifiable(taggedParents);
      }

      taggedParents.addAll(
        result.comments.where((comment) => comment.hasLocation),
      );

      if (!result.hasMore) {
        return List<Comment>.unmodifiable(taggedParents);
      }
      page += 1;
    }

    _debugLog('[CommentService] 태그 댓글 페이지 조회 제한($_maxSliceFetchPages) 도달');
    return List<Comment>.unmodifiable(taggedParents);
  }

  /// **게시물**의 댓글 조회 내부 구현
  /// - [postId]에 해당하는 게시물의 모든 댓글을 조회.
  /// - 원댓글과 대댓글을 모두 조회하여 계층 구조로 병합한 후 반환.
  ///
  /// Parameters:
  /// - [postId]: 게시물 ID
  ///
  /// Returns: 댓글 목록
  /// - [List<Comment>]: 원댓글과 대댓글이 계층 구조로 병합된 형태로 반환됩니다.
  /// - 예시: 원댓글 A, 원댓글 B, 대댓글 A-1(원댓글 A의 대댓글), 대댓글 B-1(원댓글 B의 대댓글) -> 반환 형태: [A, A-1, B, B-1]
  ///
  /// Throws:
  /// - [NotFoundException]: 게시물을 찾을 수 없음
  Future<List<Comment>> _getCommentsInternal({required int postId}) async {
    // 원댓글을 페이지 단위로 모두 조회합니다. 대댓글은 원댓글별로 별도 조회하여 병합합니다.
    final parentComments = await _fetchAllSliceComments(
      fetchPage: (page) => _commentApi.getParentComment(postId, page),
      errorMessage: '댓글 조회 실패',
    );

    if (parentComments.isEmpty) {
      return const <Comment>[];
    }

    // 각 원댓글에 대해 대댓글을 병렬로 조회하여 병합되지 않은 형태로 반환합니다.
    final childCommentGroups = await Future.wait(
      parentComments.map(_fetchChildCommentsForParent),
    );

    final merged = <Comment>[]; // 원댓글과 대댓글을 계층 구조로 병합하여 반환할 리스트

    // 원댓글과 해당 원댓글의 대댓글 그룹을 순회하며 병합된 형태로 리스트에 추가합니다.
    for (var i = 0; i < parentComments.length; i++) {
      final parentDto = parentComments[i]; // 단일 원댓글 DTO를 추출

      // 원댓글 DTO를 Comment 모델로 변환
      final parentComment = _normalizeCommentDto(parentDto);

      // 원댓글을 먼저 merged에 추가
      merged.add(parentComment);

      final parentId = parentComment.threadParentId ?? parentDto.id;

      // 해당 원댓글의 대댓글 그룹을 순회하며 각 대댓글 DTO를 Comment 모델로 변환하여 merged에 추가
      merged.addAll(
        childCommentGroups[i].map(
          (dto) => _normalizeCommentDto(dto, parentCommentId: parentId),
        ),
      );
    }

    return List<Comment>.unmodifiable(merged); // 병합된 댓글 리스트를 반환합니다.
  }

  /// 특정 원댓글의 대댓글 조회
  ///
  /// [parent]에 해당하는 원댓글의 모든 대댓글을 조회합니다.
  ///
  /// Parameters:
  /// - [parent]: 원댓글 객체
  ///
  /// Returns: 대댓글 목록 (`List<CommentRespDto>`)
  /// - 대댓글은 원댓글과 계층 구조로 병합되지 않은 평탄한 리스트 형태로 반환됩니다.
  /// - 예시: 원댓글 A, 대댓글 A-1, 대댓글 A-2 -> 반환 형태: [A-1, A-2]
  ///
  /// Throws:
  /// - [NotFoundException]: 원댓글을 찾을 수 없음
  Future<List<CommentRespDto>> _fetchChildCommentsForParent(
    CommentRespDto parent,
  ) async {
    final parentId = parent.id;
    if (parentId == null) {
      return const <CommentRespDto>[];
    }

    return _fetchAllSliceComments(
      fetchPage: (page) => _commentApi.getChildComment(parentId, page),
      errorMessage: '대댓글 조회 실패',
    );
  }

  /// 댓글 개수 조회 (편의 메서드)
  ///
  /// 게시물의 댓글 수를 반환합니다.
  Future<int> getCommentCount({required int postId}) async {
    final comments = await getComments(postId: postId);
    return comments.length;
  }

  /// 게시물에 달린 원댓글 한 페이지를 `Comment` 모델로 정규화해 반환합니다.
  Future<({List<Comment> comments, bool hasMore})> getParentComments({
    required int postId,
    int page = _defaultPage,
  }) async {
    final requestKey = _buildParentCommentsRequestKey(
      postId: postId,
      page: page,
    );
    final task = _inFlightParentCommentsByPostPage.putIfAbsent(
      requestKey,
      () => _fetchCommentSlice(
        request: () => _commentApi.getParentComment(postId, page),
        errorMessage: '원댓글 조회 실패',
      ),
    );

    try {
      return await task;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '원댓글 조회 실패: $e', originalException: e);
    } finally {
      final registeredTask = _inFlightParentCommentsByPostPage[requestKey];
      if (identical(registeredTask, task)) {
        _inFlightParentCommentsByPostPage.remove(requestKey);
      }
    }
  }

  /// 부모 댓글에 달린 대댓글 한 페이지를 `Comment` 모델로 정규화해 반환합니다.
  Future<({List<Comment> comments, bool hasMore})> getChildComments({
    required int parentCommentId,
    int page = _defaultPage,
  }) async {
    final requestKey = _buildChildCommentsRequestKey(
      parentCommentId: parentCommentId,
      page: page,
    );
    final task = _inFlightChildCommentsByParentPage.putIfAbsent(
      requestKey,
      () => _fetchCommentSlice(
        request: () => _commentApi.getChildComment(parentCommentId, page),
        errorMessage: '대댓글 조회 실패',
        parentCommentId: parentCommentId,
      ),
    );

    try {
      return await task;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '대댓글 조회 실패: $e', originalException: e);
    } finally {
      final registeredTask = _inFlightChildCommentsByParentPage[requestKey];
      if (identical(registeredTask, task)) {
        _inFlightChildCommentsByParentPage.remove(requestKey);
      }
    }
  }

  /// 사용자가 작성한 댓글 조회 (Slice 페이지네이션)
  ///
  /// [userId]가 작성한 댓글을 페이지 단위로 조회합니다.
  ///
  /// Returns: `({List<Comment> comments, bool hasMore})`
  Future<({List<Comment> comments, bool hasMore})> getCommentsByUserId({
    required int userId,
    int page = _defaultPage,
  }) async {
    final requestKey = _buildUserCommentsRequestKey(userId: userId, page: page);
    final task = _inFlightCommentsByUserPage.putIfAbsent(
      requestKey,
      () => _getCommentsByUserIdInternal(page: page),
    );

    try {
      return await task;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '댓글 조회 실패: $e', originalException: e);
    } finally {
      final registeredTask = _inFlightCommentsByUserPage[requestKey];
      if (identical(registeredTask, task)) {
        _inFlightCommentsByUserPage.remove(requestKey);
      }
    }
  }

  Future<({List<Comment> comments, bool hasMore})>
  _getCommentsByUserIdInternal({required int page}) async {
    return _fetchCommentSlice(
      request: () => _commentApi.getAllCommentByUserId(page),
      errorMessage: '댓글 조회 실패',
    );
  }

  /// 엔드포인트 문맥에 맞춰 스레드 관계 ID를 채운 댓글 모델을 생성합니다.
  Comment _normalizeCommentDto(CommentRespDto dto, {int? parentCommentId}) {
    final comment = Comment.fromDto(dto);
    if (parentCommentId != null) {
      return comment.copyWith(threadParentId: parentCommentId);
    }

    if (comment.isReply) {
      return comment;
    }

    return comment.copyWith(
      threadParentId: comment.threadParentId ?? comment.id,
    );
  }

  /// Slice 기반 댓글 응답을 앱 전용 `Comment` 목록과 다음 페이지 정보로 변환합니다.
  Future<({List<Comment> comments, bool hasMore})> _fetchCommentSlice({
    required Future<ApiResponseDtoSliceCommentRespDto?> Function() request,
    required String errorMessage,
    int? parentCommentId,
  }) async {
    final response = await request();

    if (response == null) {
      return (comments: <Comment>[], hasMore: false);
    }

    if (response.success != true) {
      throw SoiApiException(message: response.message ?? errorMessage);
    }

    final slice = response.data;
    if (slice == null) {
      return (comments: <Comment>[], hasMore: false);
    }

    final comments = List<Comment>.unmodifiable(
      slice.content.map(
        (dto) => _normalizeCommentDto(dto, parentCommentId: parentCommentId),
      ),
    );
    final hasMore = slice.last == false;
    return (comments: comments, hasMore: hasMore);
  }

  /// Slice 기반 댓글을 페이지 단위로 반복 조회하여 모든 댓글을 가져옵니다.
  ///
  /// Slice 기반 댓글?
  /// - API가 페이지네이션된 댓글 데이터를 반환하는 경우, 각 페이지를 순차적으로 조회하여 **전체 댓글 목록**을 구성하는 방식입니다.
  ///
  /// Parameters:
  /// - [fetchPage]: 페이지 번호를 입력으로 받아 해당 페이지의 댓글 데이터를 반환하는 함수입니다. API 호출을 래핑하여 전달합니다.
  /// - [errorMessage]: API 호출 실패 시 사용할 기본 에러 메시지입니다.
  ///
  /// Returns: 댓글 목록
  /// - [List<CommentRespDto>]: API에서 페이지 단위로 반환되는 댓글 데이터를 반복적으로 조회하여 전체 댓글 목록을 구성한 후 반환합니다.
  Future<List<CommentRespDto>> _fetchAllSliceComments({
    required Future<ApiResponseDtoSliceCommentRespDto?> Function(int page)
    fetchPage,
    required String errorMessage,
  }) async {
    final result = <CommentRespDto>[];
    var page = _defaultPage;

    for (var i = 0; i < _maxSliceFetchPages; i++) {
      final response = await fetchPage(page);
      if (response == null) {
        return result;
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? errorMessage);
      }

      final slice = response.data;
      if (slice == null) {
        return result;
      }

      final content = slice.content;
      if (content.isNotEmpty) {
        result.addAll(content);
      }

      final shouldContinue =
          slice.last == false && slice.empty != true && content.isNotEmpty;
      if (!shouldContinue) {
        return result;
      }

      page += 1;
    }

    _debugLog('[CommentService] 댓글 페이지 조회 제한($_maxSliceFetchPages) 도달');
    return result;
  }

  // ============================================
  // 댓글 삭제
  // ============================================

  /// 댓글 삭제
  ///
  /// [commentId]에 해당하는 댓글을 삭제합니다.
  ///
  /// Returns: 삭제 성공 여부
  ///
  /// Throws:
  /// - [NotFoundException]: 댓글을 찾을 수 없음
  Future<bool> deleteComment(int commentId) async {
    try {
      final response = await _commentApi.deleteComment(commentId);

      if (response == null) {
        throw const DataValidationException(message: '댓글 삭제 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '댓글 삭제 실패');
      }

      return true;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '댓글 삭제 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 에러 핸들링 헬퍼
  // ============================================

  /// CommentType을 API DTO enum으로 변환
  CommentReqDtoCommentTypeEnum _toCommentTypeEnum(CommentType? type) {
    switch (type) {
      case CommentType.text:
        return CommentReqDtoCommentTypeEnum.TEXT;
      case CommentType.audio:
        return CommentReqDtoCommentTypeEnum.AUDIO;
      case CommentType.photo:
        return CommentReqDtoCommentTypeEnum.PHOTO;
      case CommentType.video:
        return CommentReqDtoCommentTypeEnum.VIDEO;
      case CommentType.reply:
        return CommentReqDtoCommentTypeEnum.REPLY;
      default:
        return CommentReqDtoCommentTypeEnum.TEXT;
    }
  }

  SoiApiException _handleApiException(ApiException e) {
    _debugLog('API Error [${e.code}]: ${e.message}');

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
          message: e.message ?? '댓글을 찾을 수 없습니다.',
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
}
