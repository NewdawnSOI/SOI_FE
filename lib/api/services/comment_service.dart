import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../models/models.dart';

/// 댓글 관련 API 래퍼 서비스.
///
/// 댓글 생성, 조회, 삭제 기능을 제공합니다.
/// Provider를 통해 주입받아 사용합니다.
class CommentService {
  /// 댓글 API 클라이언트.
  final CommentAPIApi _commentApi;

  /// 페이지네이션 시작 페이지 번호 (0-based).
  static const int _defaultPage = 0;

  /// 페이지네이션 반복 조회 시 최대 페이지 수 제한.
  static const int _maxSliceFetchPages = 100;

  /// postId별 진행 중인 **전체 댓글**을 캐싱.
  /// - 진행 중이라는 것은 getComments()가 완료되지 않았음을 의미.
  ///
  /// 동일 postId의 중복 호출을 방지.
  final _inFlightComments = <int, Future<List<Comment>>>{};

  /// postId별 진행 중인 **태그 댓글**을 캐싱.
  /// - 진행 중이라는 것은 getTagComments()가 완료되지 않았음을 의미.
  ///
  /// 동일 postId의 중복 호출을 방지.
  final _inFlightTagComments = <int, Future<List<Comment>>>{};

  /// 원댓글/대댓글/사용자 댓글 slice 요청을 한 맵으로 관리.
  /// 키 형식: 'parent:$postId:$page', 'child:$parentId:$page', 'user:$userId:$page'
  final _inFlightSlice =
      <String, Future<({List<Comment> comments, bool hasMore})>>{};

  /// [commentApi]를 주입하지 않으면 싱글턴 [SoiApiClient]의 commentApi를 사용합니다.
  CommentService({CommentAPIApi? commentApi})
    : _commentApi = commentApi ?? SoiApiClient.instance.commentApi;

  /// 디버그 모드에서만 [message]를 출력합니다.
  void _debugLog(String message) {
    if (kDebugMode) debugPrint(message);
  }

  /// 긴 디버그 메시지를 줄 단위로 나눠 로그가 잘리지 않게 출력합니다.
  void _debugLogMultiline(String message) {
    if (!kDebugMode) return;
    for (final line in const LineSplitter().convert(message)) {
      debugPrint(line);
    }
  }

  /// in-flight 중복 요청 방지 + 공통 에러 핸들링 헬퍼.
  ///
  /// [cache]에 [key]로 진행 중인 요청이 있으면 재사용하고, 없으면 [compute]를 실행합니다.
  /// 완료 후 [cache]에서 해당 키를 제거합니다.
  ///
  /// - [cache]: in-flight 요청을 추적하는 맵.
  /// - [key]: 요청을 식별하는 키.
  /// - [compute]: 실제 비동기 작업.
  /// - [errorLabel]: 알 수 없는 예외 발생 시 에러 메시지 접두사.
  ///
  /// Returns: [compute]의 결과.
  Future<T> _withDedup<K, T>(
    Map<K, Future<T>> cache,
    K key,
    Future<T> Function() compute,
    String errorLabel,
  ) async {
    final task = cache.putIfAbsent(key, compute);
    try {
      return await task;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '$errorLabel: $e', originalException: e);
    } finally {
      if (identical(cache[key], task)) cache.remove(key);
    }
  }

  // ============================================
  // 댓글 생성
  // ============================================

  /// parent 댓글 조회 응답에서 comment data만 디버그 로그로 남겨 payload 구조를 바로 확인합니다.
  Future<void> debugLogParentCommentResponse({
    required int postId,
    int page = _defaultPage,
  }) async {
    if (!kDebugMode) return;

    try {
      final response = await _commentApi.getParentComment(postId, page);
      if (response == null) {
        _debugLog(
          '[CommentService.debug] /comment/get-parent '
          'postId:$postId page:$page response:null',
        );
        return;
      }

      final data = response.data;
      if (data == null) {
        _debugLog(
          '[CommentService.debug] /comment/get-parent '
          'postId:$postId page:$page data:null',
        );
        return;
      }

      _debugLog(
        '[CommentService.debug] /comment/get-parent '
        'postId:$postId page:$page',
      );
      final payload = const JsonEncoder.withIndent('  ').convert(
        data.content.map((comment) => comment.toJson()).toList(growable: false),
      );
      _debugLogMultiline(payload);
    } catch (e, stackTrace) {
      _debugLog(
        '[CommentService.debug] /comment/get-parent failed '
        'postId:$postId page:$page error:$e',
      );
      _debugLogMultiline(stackTrace.toString());
    }
  }

  /// 게시물에 댓글을 생성합니다.
  ///
  /// - [postId]: 댓글을 작성할 게시물 ID.
  /// - [userId]: 댓글 작성자 ID.
  /// - [emojiId]: 이모지 ID (기본값 0).
  /// - [parentId]: 대댓글인 경우 부모 댓글 ID.
  /// - [replyUserId]: 대댓글 대상 사용자 ID.
  /// - [text]: 텍스트 내용.
  /// - [audioFileKey]: 음성 파일 키.
  /// - [fileKey]: 첨부 파일 키.
  /// - [waveformData]: 음성 파형 데이터 (JSON 배열 또는 쉼표 구분 문자열).
  /// - [duration]: 음성 길이 (밀리초).
  /// - [locationX]: 댓글 태그 X 좌표 (대댓글이면 무시).
  /// - [locationY]: 댓글 태그 Y 좌표 (대댓글이면 무시).
  /// - [type]: 댓글 유형 ([CommentType]).
  ///
  /// Returns: [CommentCreationResult] — 생성 성공 여부와 생성된 [Comment].
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
      final normalizedParentId = parentId ?? 0;
      final normalizedReplyUserId = replyUserId ?? 0;
      final commentTypeEnum = _toCommentTypeEnum(type);
      final normalizedLocationX = locationX ?? 0.0;
      final normalizedLocationY = locationY ?? 0.0;

      final isReply =
          normalizedParentId > 0 ||
          normalizedReplyUserId > 0 ||
          type == CommentType.reply;

      final dto = CommentReqDto(
        postId: postId,
        userId: userId,
        emojiId: emojiId ?? 0,
        parentId: normalizedParentId,
        replyUserId: normalizedReplyUserId,
        text: text?.trim() ?? '',
        audioKey: audioFileKey?.trim() ?? '',
        fileKey: fileKey?.trim() ?? '',
        waveformData: _normalizeWaveformData(waveformData?.trim() ?? ''),
        duration: duration ?? 0,
        locationX: isReply ? null : normalizedLocationX,
        locationY: isReply ? null : normalizedLocationY,
        commentType: commentTypeEnum,
      );

      if (kDebugMode) {
        debugPrint(
          '=== 댓글 생성 요청 === '
          'postId:$postId userId:$userId type:${commentTypeEnum.value} '
          'parentId:$normalizedParentId replyUserId:$normalizedReplyUserId',
        );
      }

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

  /// 텍스트 댓글 생성 편의 메서드.
  ///
  /// - [postId]: 게시물 ID.
  /// - [userId]: 작성자 ID.
  /// - [text]: 텍스트 내용.
  /// - [locationX]: 태그 X 좌표.
  /// - [locationY]: 태그 Y 좌표.
  ///
  /// Returns: [CommentCreationResult].
  Future<CommentCreationResult> createTextComment({
    required int postId,
    required int userId,
    required String text,
    required double locationX,
    required double locationY,
  }) => createComment(
    postId: postId,
    userId: userId,
    emojiId: 0,
    text: text,
    audioFileKey: '',
    waveformData: '',
    duration: 0,
    locationX: locationX,
    locationY: locationY,
    type: CommentType.text,
  );

  /// 음성 댓글 생성 편의 메서드.
  ///
  /// - [postId]: 게시물 ID.
  /// - [userId]: 작성자 ID.
  /// - [audioFileKey]: 업로드된 음성 파일 키.
  /// - [waveformData]: 음성 파형 데이터.
  /// - [duration]: 음성 길이 (밀리초).
  /// - [locationX]: 태그 X 좌표.
  /// - [locationY]: 태그 Y 좌표.
  ///
  /// Returns: [CommentCreationResult].
  Future<CommentCreationResult> createAudioComment({
    required int postId,
    required int userId,
    required String audioFileKey,
    required String waveformData,
    required int duration,
    required double locationX,
    required double locationY,
  }) => createComment(
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

  /// 댓글 생성 API 응답에서 [Comment] 객체를 파싱합니다.
  ///
  /// `data` 필드가 [CommentRespDto], [Map], [List] 순으로 파싱을 시도합니다.
  ///
  /// - [response]: 댓글 생성 API 응답.
  /// - [requestedParentId]: 대댓글인 경우 부모 댓글 ID (threadParentId 주입용).
  ///
  /// Returns: 파싱된 [Comment], 파싱 실패 시 null.
  Comment? _parseCommentFromResponse(
    ApiResponseDtoObject response, {
    int? requestedParentId,
  }) {
    final data = response.data;
    if (data == null) {
      _debugLog('댓글 생성 응답에 data가 없습니다.');
      return null;
    }

    if (data is CommentRespDto) {
      return _normalizeCommentDto(data, parentCommentId: requestedParentId);
    }
    if (data is Map) {
      final dto = CommentRespDto.fromJson(Map<String, dynamic>.from(data));
      if (dto != null) {
        return _normalizeCommentDto(dto, parentCommentId: requestedParentId);
      }
    }
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

  /// 게시물의 모든 댓글을 A → A-1 → B → B-1 스레드 순서로 반환합니다.
  ///
  /// 동일 [postId]에 대한 중복 요청은 진행 중인 Future를 재사용합니다.
  ///
  /// - [postId]: 게시물 ID.
  ///
  /// Returns: 원댓글과 대댓글이 스레드 순서로 병합된 `List<Comment>`.
  Future<List<Comment>> getComments({required int postId}) => _withDedup(
    _inFlightComments,
    postId,
    () => _getCommentsInternal(postId: postId),
    '댓글 조회 실패',
  );

  /// 위치 정보가 있는 원댓글만 반환합니다 (태그 오버레이용).
  ///
  /// 전체 댓글 조회 없이 원댓글 페이지만 순회하여 병목을 줄입니다.
  /// 동일 [postId]에 대한 중복 요청은 진행 중인 Future를 재사용합니다.
  ///
  /// - [postId]: 게시물 ID.
  ///
  /// Returns: hasLocation == true인 원댓글 목록.
  Future<List<Comment>> getTagComments({required int postId}) => _withDedup(
    _inFlightTagComments,
    postId,
    () => _getTagCommentsInternal(postId: postId),
    '태그 댓글 조회 실패',
  );

  /// [getTagComments]의 내부 구현. 원댓글 페이지를 순회하며 위치 있는 댓글을 수집합니다.
  ///
  /// - [postId]: 게시물 ID.
  ///
  /// Returns: 위치 정보가 있는 원댓글 목록.
  Future<List<Comment>> _getTagCommentsInternal({required int postId}) async {
    final result = <Comment>[];
    var page = _defaultPage;

    for (var i = 0; i < _maxSliceFetchPages; i++) {
      final slice = await getParentComments(postId: postId, page: page);
      if (slice.comments.isEmpty) return List.unmodifiable(result);
      result.addAll(slice.comments.where((c) => c.hasLocation));
      if (!slice.hasMore) return List.unmodifiable(result);
      page++;
    }

    _debugLog('[CommentService] 태그 댓글 페이지 조회 제한($_maxSliceFetchPages) 도달');
    return List<Comment>.unmodifiable(result);
  }

  /// [getComments]의 내부 구현.
  ///
  /// 원댓글 전체를 조회한 뒤, 각 원댓글의 대댓글을 병렬로 조회하여 스레드 순서로 병합합니다.
  ///
  /// - [postId]: 게시물 ID.
  ///
  /// Returns: A → A-1 → B → B-1 형태로 병합된 `List<Comment>`.
  Future<List<Comment>> _getCommentsInternal({required int postId}) async {
    final parentComments = await _fetchAllSliceComments(
      fetchPage: (page) => _commentApi.getParentComment(postId, page),
      errorMessage: '댓글 조회 실패',
    );

    if (parentComments.isEmpty) return const <Comment>[];

    final childGroups = await Future.wait(
      parentComments.map(_fetchChildCommentsForParent),
    );

    final merged = <Comment>[];
    for (var i = 0; i < parentComments.length; i++) {
      final parentComment = _normalizeCommentDto(parentComments[i]);
      merged.add(parentComment);
      final parentId = parentComment.threadParentId ?? parentComments[i].id;
      merged.addAll(
        childGroups[i].map(
          (dto) => _normalizeCommentDto(dto, parentCommentId: parentId),
        ),
      );
    }

    return List<Comment>.unmodifiable(merged);
  }

  /// 단일 원댓글 DTO에 대한 대댓글 전체를 페이지 순회하여 가져옵니다.
  ///
  /// - [parent]: 대댓글을 조회할 원댓글 DTO. id가 null이면 빈 목록을 반환.
  ///
  /// Returns: 대댓글 DTO 목록 (`List<CommentRespDto>`).
  Future<List<CommentRespDto>> _fetchChildCommentsForParent(
    CommentRespDto parent,
  ) async {
    final parentId = parent.id;
    if (parentId == null) return const <CommentRespDto>[];
    return _fetchAllSliceComments(
      fetchPage: (page) => _commentApi.getChildComment(parentId, page),
      errorMessage: '대댓글 조회 실패',
    );
  }

  /// 게시물의 전체 댓글 수를 반환합니다.
  ///
  /// - [postId]: 게시물 ID.
  ///
  /// Returns: 댓글 총 개수.
  Future<int> getCommentCount({required int postId}) async =>
      (await getComments(postId: postId)).length;

  /// 게시물의 원댓글 한 페이지를 조회합니다.
  ///
  /// 동일 (postId, page) 조합의 중복 요청은 진행 중인 Future를 재사용합니다.
  ///
  /// - [postId]: 게시물 ID.
  /// - [page]: 페이지 번호 (기본값 [_defaultPage]).
  ///
  /// Returns: `({List<Comment> comments, bool hasMore})` — 댓글 목록과 다음 페이지 존재 여부.
  Future<({List<Comment> comments, bool hasMore})> getParentComments({
    required int postId,
    int page = _defaultPage,
  }) => _withDedup(
    _inFlightSlice,
    'parent:$postId:$page',
    () => _fetchCommentSlice(
      request: () => _commentApi.getParentComment(postId, page),
      errorMessage: '원댓글 조회 실패',
    ),
    '원댓글 조회 실패',
  );

  /// 부모 댓글의 대댓글 한 페이지를 조회합니다.
  ///
  /// 동일 (parentCommentId, page) 조합의 중복 요청은 진행 중인 Future를 재사용합니다.
  ///
  /// - [parentCommentId]: 부모 댓글 ID.
  /// - [page]: 페이지 번호 (기본값 [_defaultPage]).
  ///
  /// Returns: `({List<Comment> comments, bool hasMore})`.
  Future<({List<Comment> comments, bool hasMore})> getChildComments({
    required int parentCommentId,
    int page = _defaultPage,
  }) => _withDedup(
    _inFlightSlice,
    'child:$parentCommentId:$page',
    () => _fetchCommentSlice(
      request: () => _commentApi.getChildComment(parentCommentId, page),
      errorMessage: '대댓글 조회 실패',
      parentCommentId: parentCommentId,
    ),
    '대댓글 조회 실패',
  );

  /// 로그인된 사용자가 작성한 댓글 한 페이지를 조회합니다.
  ///
  /// 동일 (userId, page) 조합의 중복 요청은 진행 중인 Future를 재사용합니다.
  ///
  /// - [userId]: 사용자 ID.
  /// - [page]: 페이지 번호 (기본값 [_defaultPage]).
  ///
  /// Returns: `({List<Comment> comments, bool hasMore})`.
  Future<({List<Comment> comments, bool hasMore})> getCommentsByUserId({
    required int userId,
    int page = _defaultPage,
  }) => _withDedup(
    _inFlightSlice,
    'user:$userId:$page',
    () => _fetchCommentSlice(
      request: () => _commentApi.getAllCommentByUserId(page),
      errorMessage: '댓글 조회 실패',
    ),
    '댓글 조회 실패',
  );

  /// [CommentRespDto]를 [Comment] 도메인 모델로 변환하고 threadParentId를 보정합니다.
  ///
  /// - [dto]: 변환할 댓글 DTO.
  /// - [parentCommentId]: 대댓글인 경우 주입할 부모 댓글 ID.
  ///
  /// Returns: threadParentId가 채워진 [Comment].
  Comment _normalizeCommentDto(CommentRespDto dto, {int? parentCommentId}) {
    final comment = Comment.fromDto(dto);
    if (parentCommentId != null) {
      return comment.copyWith(threadParentId: parentCommentId);
    }
    if (comment.isReply) return comment;
    return comment.copyWith(
      threadParentId: comment.threadParentId ?? comment.id,
    );
  }

  /// Slice 기반 API 응답 한 페이지를 [Comment] 목록과 hasMore 플래그로 변환합니다.
  ///
  /// - [request]: Slice 응답을 반환하는 API 호출 함수.
  /// - [errorMessage]: 응답 실패 시 사용할 에러 메시지.
  /// - [parentCommentId]: 대댓글 목록 조회 시 주입할 부모 댓글 ID.
  ///
  /// Returns: `({List<Comment> comments, bool hasMore})`.
  Future<({List<Comment> comments, bool hasMore})> _fetchCommentSlice({
    required Future<ApiResponseDtoSliceCommentRespDto?> Function() request,
    required String errorMessage,
    int? parentCommentId,
  }) async {
    final response = await request();
    if (response == null) return (comments: <Comment>[], hasMore: false);
    if (response.success != true) {
      throw SoiApiException(message: response.message ?? errorMessage);
    }

    final slice = response.data;
    if (slice == null) return (comments: <Comment>[], hasMore: false);

    final comments = List<Comment>.unmodifiable(
      slice.content.map(
        (dto) => _normalizeCommentDto(dto, parentCommentId: parentCommentId),
      ),
    );
    return (comments: comments, hasMore: slice.last == false);
  }

  /// Slice 기반 API를 페이지 단위로 순회하여 댓글 DTO 전체를 수집합니다.
  ///
  /// 마지막 페이지에 도달하거나 [_maxSliceFetchPages] 제한에 걸리면 종료합니다.
  ///
  /// - [fetchPage]: 페이지 번호를 받아 Slice 응답을 반환하는 함수.
  /// - [errorMessage]: 응답 실패 시 사용할 에러 메시지.
  ///
  /// Returns: 누적된 `List<CommentRespDto>`.
  Future<List<CommentRespDto>> _fetchAllSliceComments({
    required Future<ApiResponseDtoSliceCommentRespDto?> Function(int page)
    fetchPage,
    required String errorMessage,
  }) async {
    final result = <CommentRespDto>[];
    var page = _defaultPage;

    for (var i = 0; i < _maxSliceFetchPages; i++) {
      final response = await fetchPage(page);
      if (response == null) return result;
      if (response.success != true) {
        throw SoiApiException(message: response.message ?? errorMessage);
      }

      final slice = response.data;
      if (slice == null) return result;

      final content = slice.content;
      if (content.isNotEmpty) result.addAll(content);

      if (slice.last != false || slice.empty == true || content.isEmpty) {
        return result;
      }
      page++;
    }

    _debugLog('[CommentService] 댓글 페이지 조회 제한($_maxSliceFetchPages) 도달');
    return result;
  }

  // ============================================
  // 댓글 삭제
  // ============================================

  /// [commentId]에 해당하는 댓글을 삭제합니다.
  ///
  /// - [commentId]: 삭제할 댓글 ID.
  ///
  /// Returns: 삭제 성공 시 true.
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
  // 유틸리티
  // ============================================

  /// JSON 배열 형태의 파형 데이터를 쉼표 구분 문자열로 변환합니다.
  ///
  /// "[0.1, 0.5, 0.3]" → "0.1,0.5,0.3". 이미 올바른 형식이거나 파싱 실패 시 원본을 반환합니다.
  ///
  /// - [waveformData]: 변환할 파형 데이터 문자열.
  ///
  /// Returns: 정규화된 파형 데이터 문자열.
  String _normalizeWaveformData(String waveformData) {
    if (waveformData.isEmpty ||
        !waveformData.startsWith('[') ||
        !waveformData.endsWith(']')) {
      return waveformData;
    }
    try {
      return (jsonDecode(waveformData) as List).join(',');
    } catch (e) {
      _debugLog('waveformData 변환 실패, 원본 사용: $e');
      return waveformData;
    }
  }

  /// [CommentType]을 API DTO enum [CommentReqDtoCommentTypeEnum]으로 변환합니다.
  ///
  /// - [type]: 변환할 댓글 유형. null이면 TEXT를 반환합니다.
  ///
  /// Returns: [CommentReqDtoCommentTypeEnum].
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

  /// [ApiException]을 HTTP 상태 코드에 따라 적절한 [SoiApiException] 하위 타입으로 변환합니다.
  ///
  /// - [e]: 변환할 API 예외.
  ///
  /// Returns: 400 → [BadRequestException], 401 → [AuthException], 403 → [ForbiddenException],
  /// 404 → [NotFoundException], 5xx → [ServerException], 그 외 → [SoiApiException].
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
