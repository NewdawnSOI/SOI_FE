import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

import '../../../api/controller/category_controller.dart';
import '../../../api/controller/media_controller.dart';
import '../../../api/controller/post_controller.dart';
import '../../../api/models/models.dart';
import '../../../api/services/media_service.dart';
import '../models/photo_editor_upload_models.dart';
import 'photo_editor_media_processing_service.dart';

class PhotoEditorUploadService {
  /// 사진 편집기에서 미디어 업로드와 관련된 모든 로직을 처리하는 서비스입니다.
  /// 이 서비스는 미디어 파일의 준비(압축), 업로드, 게시물 생성, 카테고리 대표 이미지 업데이트까지의 전체 파이프라인을 관리합니다.
  /// 실패 시 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  ///
  /// fields:
  /// - [_postController]: 게시물 생성과 관련된 API 호출을 담당하는 컨트롤러입니다.
  /// - [_mediaController]: 미디어 파일의 업로드와 관련된 API 호출을 담당하는 컨트롤러입니다.
  /// - [_categoryController]: 카테고리 정보의 조회 및 업데이트를 담당하는 컨트롤러입니다.
  /// - [_mediaProcessingService]: 미디어 파일의 압축, 썸네일 추출, 가로세로 비율 계산 등 미디어 처리와 관련된 로직을 담당하는 서비스입니다.
  ///
  /// public methods:
  /// - [executeMediaUpload]
  ///   - **미디어 게시물 업로드 파이프라인**을 실행하는 메서드입니다.
  ///   - [UploadSnapshot]을 입력으로 받아, 미디어 파일 준비(압축), 미디어 업로드, 게시물 생성, 카테고리 대표 이미지 업데이트의 순서로 전체 업로드 프로세스를 관리합니다.
  ///   - 업로드 과정에서 실패가 발생할 경우 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  /// - [executeTextOnlyUpload]
  ///   - 텍스트 전용 게시물 업로드를 처리하는 메서드입니다.
  ///   - 사용자 ID, 닉네임, 카테고리 ID 목록, 입력 텍스트를 받아 텍스트 게시물을 생성합니다.
  ///   - 게시물 생성에 실패할 경우 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  /// - [uploadCategoryCoverImage]
  ///   - 카테고리 대표 이미지 업로드를 처리하는 메서드입니다.
  ///   - 이미지 파일, 사용자 ID, 참조 ID를 입력으로 받아 카테고리 대표 이미지를 업로드하고, 업로드된 이미지의 S3 키 목록을 반환합니다.
  ///   - 업로드 과정에서 실패가 발생할 경우 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  ///
  /// private methods:
  /// - [_preparePayload]
  ///   - 업로드에 필요한 데이터를 준비하는 메서드입니다.
  ///   - [UploadSnapshot]을 입력으로 받아, 미디어 파일의 압축, 오디오 파일의 존재 확인, 캡션 처리, 가로세로 비율 계산 등의 작업을 수행하여 [UploadPayload] 객체를 생성합니다.
  ///   - 준비 과정에서 실패가 발생할 경우 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  /// - [_uploadMedia]
  ///   - 미디어 파일을 서버에 업로드하는 메서드입니다.
  ///   - [UploadPayload]을 입력으로 받아, 미디어 파일과 오디오 파일(있는 경우)을 업로드하고, 업로드된 파일의 S3 키를 포함하는 [MediaUploadResult] 객체를 반환합니다.
  ///   - 업로드 과정에서 실패가 발생할 경우 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  /// - [_createPost]
  ///   - 게시물을 생성하는 메서드입니다.
  ///   - 카테고리 ID 목록, [UploadPayload], [MediaUploadResult]을 입력으로 받아 게시물을 생성하고, 생성 성공 여부를 반환합니다.
  ///   - 게시물 생성에 실패할 경우 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  /// - [_updateCategoryCoverFromVideo]
  ///   - 비디오 게시물 업로드 후 카테고리 대표 이미지를 업데이트하는 메서드입니다.
  ///   - 카테고리 ID 목록과 [UploadPayload]을 입력으로 받아, 비디오에서 썸네일을 추출하여 카테고리 대표 이미지로 업로드하고, 업데이트된 이미지의 S3 키 목록을 반환합니다.
  ///   - 업로드 및 업데이트 과정에서 실패가 발생할 경우 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  /// - [_deleteTemporaryFiles]
  ///   - 업로드 과정에서 생성된 임시 파일을 삭제하는 메서드입니다.
  ///   - [UploadPayload]을 입력으로 받아, 미디어 파일과 오디오 파일(있는 경우)이 임시 파일인지 확인하고, 임시 파일인 경우 삭제를 시도합니다.
  ///   - 파일 삭제에 실패할 경우 예외를 throw하지 않고, 실패 사실을 로그로 기록합니다.

  final PostController _postController;
  final MediaController _mediaController;
  final CategoryController _categoryController;
  final PhotoEditorMediaProcessingService _mediaProcessingService;

  const PhotoEditorUploadService({
    required PostController postController,
    required MediaController mediaController,
    required CategoryController categoryController,
    required PhotoEditorMediaProcessingService mediaProcessingService,
  }) : _postController = postController,
       _mediaController = mediaController,
       _categoryController = categoryController,
       _mediaProcessingService = mediaProcessingService;

  /// 미디어 게시물 업로드 파이프라인을 실행하는 메서드입니다.
  /// payload 준비(압축) → 미디어 업로드 → 게시물 생성 → 카테고리 커버 업데이트 순으로 진행합니다.
  /// 실패 시 [Exception]을 throw합니다.
  ///
  /// parameters:
  /// - [snapshot]
  ///   - 업로드에 필요한 모든 정보를 담고 있는 스냅샷 객체입니다.
  ///   - 파일 경로, 사용자 정보, 캡션, 카테고리 ID 목록 등이 포함되어 있습니다.
  Future<void> executeMediaUpload(UploadSnapshot snapshot) async {
    final payload = await _preparePayload(snapshot);
    if (payload == null) return;

    try {
      final mediaResult = await _uploadMedia(payload);
      if (mediaResult == null) {
        throw Exception('미디어 업로드에 실패했습니다.');
      }

      // 게시물 생성과 카테고리 커버 업데이트를 병렬로 실행합니다.
      final createPostFuture = _createPost(
        categoryIds: snapshot.categoryIds,
        payload: payload,
        mediaResult: mediaResult,
      );

      Future<List<String>?>? updateCoverFuture;
      if (payload.isVideo && snapshot.categoryIds.isNotEmpty) {
        updateCoverFuture = _updateCategoryCoverFromVideo(
          categoryIds: snapshot.categoryIds,
          payload: payload,
        );
      }

      final results = await Future.wait([
        createPostFuture,
        if (updateCoverFuture != null) updateCoverFuture,
      ]);

      final createSuccess = results.isNotEmpty && results.first == true;
      if (!createSuccess) {
        throw Exception('게시물 생성에 실패했습니다.');
      }

      if (payload.isVideo && results.length > 1) {
        final thumbnailKeys = results[1] as List<String>?;
        if (thumbnailKeys != null && thumbnailKeys.isNotEmpty) {
          final videoS3Key = mediaResult.mediaKeys.isNotEmpty
              ? mediaResult.mediaKeys[0]
              : null;
          if (videoS3Key != null) {
            _mediaController.cacheThumbnailForVideo(
              videoS3Key,
              thumbnailKeys[0],
            );
          } else {
            throw Exception('비디오 S3 키가 없어 캐싱 불가');
          }
        } else {
          throw Exception('카테고리 대표 이미지 업데이트에 실패했습니다.');
        }
      }

      try {
        await _categoryController.loadCategories(
          payload.userId,
          forceReload: true,
        );
      } catch (e) {
        debugPrint('[PhotoEditorUploadService] 카테고리 강제 갱신 실패(무시): $e');
      }

      unawaited(_deleteTemporaryFiles(payload));
    } catch (e) {
      throw Exception('[PhotoEditorUploadService] 업로드 실패: $e');
    } finally {
      if (!kIsWeb) {
        unawaited(VideoCompress.deleteAllCache());
      }
    }
  }

  /// 텍스트 전용 게시물 업로드
  /// 사용자 ID, 닉네임, 카테고리 ID 목록, 입력 텍스트를 받아 텍스트 게시물을 생성합니다.
  /// 게시물 생성에 실패할 경우 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  ///
  /// parameters:
  /// - [userId]: 게시물을 생성하는 사용자의 ID입니다.
  /// - [nickName]: 게시물을 생성하는 사용자의 닉네임입니다.
  /// - [categoryIds]: 게시물이 속할 카테고리 ID 목록입니다.
  /// - [inputText]: 게시물의 텍스트 콘텐츠입니다.
  Future<void> executeTextOnlyUpload({
    required int userId,
    required String nickName,
    required List<int> categoryIds,
    required String inputText,
  }) async {
    final success = await _postController.createPost(
      userId: userId,
      nickName: nickName,
      content: inputText,
      categoryIds: categoryIds,
      postFileKey: TextOnlyPostCreateDefaults.postFileKey,
      audioFileKey: TextOnlyPostCreateDefaults.audioFileKey,
      waveformData: TextOnlyPostCreateDefaults.waveformData,
      duration: TextOnlyPostCreateDefaults.duration,
      savedAspectRatio: TextOnlyPostCreateDefaults.savedAspectRatio,
      isFromGallery: TextOnlyPostCreateDefaults.isFromGallery,
      postType: PostType.textOnly,
    );

    if (!success) {
      throw Exception('텍스트 게시물 생성에 실패했습니다.');
    }

    try {
      await _categoryController.loadCategories(userId, forceReload: true);
    } catch (e) {
      debugPrint(
        '[PhotoEditorUploadService] text-only categories refresh failed: $e',
      );
    }
  }

  /// 카테고리 커버 이미지 업로드
  /// 이미지 파일, 사용자 ID, 참조 ID를 입력으로 받아 카테고리 대표 이미지를 업로드하고, 업로드된 이미지의 S3 키 목록을 반환합니다.
  /// 업로드 과정에서 실패가 발생할 경우 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  ///
  /// parameters:
  /// - [imageFile]: 업로드할 이미지 파일입니다.
  /// - [userId]: 업로드를 수행하는 사용자의 ID입니다.
  /// - [refId]: 업로드된 이미지가 참조하는 엔티티의 ID입니다(예: 카테고리 ID).
  Future<List<String>> uploadCategoryCoverImage({
    required File imageFile,
    required int userId,
    required int refId,
  }) async {
    final multipart = await _mediaController.fileToMultipart(imageFile);
    return _mediaController.uploadMedia(
      files: [multipart],
      types: [MediaType.image],
      usageTypes: [MediaUsageType.categoryProfile],
      userId: userId,
      refId: refId,
      usageCount: 1,
    );
  }

  // ========== Private Methods ==========

  /// 업로드에 필요한 데이터를 준비하는 메서드입니다.
  /// [UploadSnapshot]을 입력으로 받아, 미디어 파일의 압축, 오디오 파일의 존재 확인, 캡션 처리, 가로세로 비율 계산 등의 작업을 수행하여 [UploadPayload] 객체를 생성합니다.
  /// 준비 과정에서 실패가 발생할 경우 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  ///
  /// parameters:
  /// - [snapshot]: 업로드에 필요한 **모든 정보를 담고 있는 스냅샷 객체**입니다. **파일 경로, 사용자 정보, 캡션, 카테고리 ID 목록 등**이 포함되어 있습니다.
  Future<UploadPayload?> _preparePayload(UploadSnapshot snapshot) async {
    final filePath = snapshot.filePath;
    var mediaFile = File(filePath);
    if (!await mediaFile.exists()) {
      throw Exception('미디어 파일을 찾을 수 없습니다.');
    }

    if (snapshot.isVideo) {
      try {
        mediaFile = await _mediaProcessingService.compressVideoIfNeeded(
          mediaFile,
        );
      } catch (e) {
        debugPrint('[PhotoEditorUploadService] 비디오 압축 실패(원본 사용): $e');
      }
    } else {
      try {
        if (snapshot.compressedFile != null &&
            snapshot.lastCompressedPath == filePath) {
          mediaFile = snapshot.compressedFile!;
        } else if (snapshot.compressionTask != null &&
            snapshot.lastCompressedPath == filePath) {
          mediaFile = await snapshot.compressionTask!;
        } else {
          mediaFile = await _mediaProcessingService.compressImageIfNeeded(
            mediaFile,
          );
        }
      } catch (e) {
        debugPrint('[PhotoEditorUploadService] 이미지 압축 실패(원본 사용): $e');
      }
    }

    File? audioFile;
    String? audioPath;

    // 녹음된 오디오 파일 경로입니다. 존재 여부는 나중에 확인합니다.
    final candidatePath = snapshot.recordedAudioPath;

    // 녹음된 오디오 파일 경로가 존재하는지 확인하고, 존재한다면 File 객체로 준비합니다.
    if (candidatePath != null && candidatePath.isNotEmpty) {
      // File 객체로 준비하지만, 실제 존재 여부는 나중에 확인합니다.
      final file = File(candidatePath);

      // 파일이 실제로 존재하는지 확인합니다. 존재하지 않는다면 audioFile과 audioPath는 null로 유지됩니다.
      if (await file.exists()) {
        audioFile = file;
        audioPath = candidatePath;
      }
    }

    final captionText = snapshot.captionText;
    final caption = captionText.isNotEmpty ? captionText : '';
    final hasCaption = caption.isNotEmpty;
    final shouldIncludeAudio =
        !hasCaption &&
        audioFile != null &&
        snapshot.recordedWaveformData != null;
    final waveform = shouldIncludeAudio ? snapshot.recordedWaveformData : null;

    double? aspectRatio;
    if (!snapshot.isVideo) {
      aspectRatio = await _mediaProcessingService.calculateImageAspectRatio(
        mediaFile,
      );
    }

    return UploadPayload(
      userId: snapshot.userId,
      nickName: snapshot.nickName,
      mediaFile: mediaFile,
      mediaPath: mediaFile.path,
      isVideo: snapshot.isVideo,
      audioFile: shouldIncludeAudio ? audioFile : null,
      audioPath: shouldIncludeAudio ? audioPath : null,
      caption: caption,
      waveformData: waveform,
      audioDurationSeconds: shouldIncludeAudio
          ? snapshot.recordedAudioDurationSeconds
          : null,
      usageCount: snapshot.categoryIds.isNotEmpty
          ? snapshot.categoryIds.length
          : 1,
      aspectRatio: aspectRatio,
      isFromGallery: snapshot.isFromGallery,
    );
  }

  /// 미디어 파일(및 오디오 파일)을 서버에 업로드하고 S3 키를 반환합니다.
  Future<MediaUploadResult?> _uploadMedia(UploadPayload payload) async {
    final hasAudio = payload.audioFile != null;
    File? thumbnailFile;
    var hasThumbnail = false;

    if (payload.isVideo) {
      try {
        thumbnailFile = await _mediaProcessingService.extractVideoThumbnailFile(
          payload.mediaPath,
        );
        hasThumbnail = thumbnailFile != null;
      } catch (e) {
        debugPrint('[PhotoEditorUploadService] 게시물 썸네일 생성 실패(계속 진행): $e');
      }
    }

    // 미디어 + 오디오 파일을 병렬로 MultipartFile 변환
    final multiparts = await Future.wait([
      _mediaController.fileToMultipart(payload.mediaFile),
      if (hasAudio) _mediaController.fileToMultipart(payload.audioFile!),
      if (hasThumbnail) _mediaController.fileToMultipart(thumbnailFile!),
    ]);

    try {
      final keys = await _mediaController.uploadMedia(
        files: multiparts,
        types: [
          payload.isVideo ? MediaType.video : MediaType.image,
          if (hasAudio) MediaType.audio,
          if (hasThumbnail) MediaType.image,
        ],
        usageTypes: [
          MediaUsageType.post,
          if (hasAudio) MediaUsageType.post,
          if (hasThumbnail) MediaUsageType.post,
        ],
        userId: payload.userId,
        refId: payload.userId,
        usageCount: payload.usageCount,
      );

      if (keys.isEmpty) return null;

      // 반환된 키를 타입별로 분리: [media * n, audio * n, thumbnail * n]
      final n = payload.usageCount <= 0 ? 1 : payload.usageCount;

      // 오디오/썸네일이 있는 경우 각 타입별로 n개씩 키가 반환됩니다.
      final expectedTypeCount = 1 + (hasAudio ? 1 : 0) + (hasThumbnail ? 1 : 0);
      final expectedCount = n * expectedTypeCount;

      if (keys.length < expectedCount) {
        debugPrint(
          '[PhotoEditorUploadService] 키 수 불일치. expected: $expectedCount, keys: $keys',
        );
        return null;
      }

      final mediaKeys = keys.sublist(0, n);
      final audioStart = n;
      final audioEnd = hasAudio ? audioStart + n : audioStart;
      final thumbnailStart = audioEnd;
      final thumbnailEnd = hasThumbnail ? thumbnailStart + n : thumbnailStart;

      return MediaUploadResult(
        mediaKeys: mediaKeys,
        audioKeys: hasAudio
            ? keys.sublist(audioStart, audioEnd)
            : const <String>[],
        thumbnailKeys: hasThumbnail
            ? keys.sublist(thumbnailStart, thumbnailEnd)
            : const <String>[],
      );
    } finally {
      if (thumbnailFile != null) {
        try {
          await thumbnailFile.delete();
        } catch (_) {}
      }
    }
  }

  /// 게시물을 생성하는 메서드입니다.
  /// 카테고리 ID 목록, [UploadPayload], [MediaUploadResult]을 입력으로 받아 게시물을 생성하고, 생성 성공 여부를 반환합니다.
  /// 게시물 생성에 실패할 경우 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  ///
  /// parameters:
  /// - [categoryIds]: 게시물이 속할 카테고리 ID 목록입니다.
  /// - [payload]: 업로드에 필요한 모든 정보를 담고 있는 객체입니다. 미디어 파일, 오디오 파일, 캡션, 사용자 정보 등이 포함되어 있습니다.
  /// - [mediaResult]: 미디어 업로드 결과를 담고 있는 객체입니다. 업로드된 미디어 파일과 오디오 파일의 S3 키 목록이 포함되어 있습니다.
  Future<bool> _createPost({
    required List<int> categoryIds,
    required UploadPayload payload,
    required MediaUploadResult mediaResult,
  }) async {
    final waveformJson = await _mediaProcessingService.encodeWaveformDataAsync(
      payload.waveformData,
    );

    // 게시물 생성 API를 호출하여 게시물을 생성합니다. 반환된 성공 여부를 호출자에게 반환합니다.
    final success = await _postController.createPost(
      userId: payload.userId,
      nickName: payload.nickName,
      content: payload.caption,
      postFileKey: mediaResult.mediaKeys,
      audioFileKey: mediaResult.audioKeys,
      thumbnailFileKey: mediaResult.thumbnailKeys,
      categoryIds: categoryIds,
      waveformData: waveformJson,
      duration: payload.audioDurationSeconds,
      savedAspectRatio: payload.aspectRatio,
      isFromGallery: payload.isFromGallery,
      postType: payload.isVideo ? PostType.video : PostType.image,
    );

    if (kDebugMode) {
      debugPrint('[PhotoEditorUploadService] 게시물 생성 결과: $success');
      if (payload.isVideo && mediaResult.thumbnailKeys.isNotEmpty) {
        final videoS3Key = mediaResult.mediaKeys.isNotEmpty
            ? mediaResult.mediaKeys.first
            : null;
        if (videoS3Key != null) {
          _mediaController.cacheThumbnailForVideo(
            videoS3Key,
            mediaResult.thumbnailKeys.first,
          );
        }
      }
    }
    return success;
  }

  /// 비디오 게시물 업로드 후 카테고리 대표 이미지를 업데이트하는 메서드입니다.
  /// 카테고리 ID 목록과 [UploadPayload]을 입력으로 받아, 비디오에서 썸네일을 추출하여 카테고리 대표 이미지로 업로드하고,
  /// 업데이트된 이미지의 S3 키 목록을 반환합니다.
  /// 업로드 및 업데이트 과정에서 실패가 발생할 경우 예외를 throw하여 호출자에게 업로드 실패를 알립니다.
  ///
  /// parameters:
  /// - [categoryIds]: 대표 이미지를 업데이트할 카테고리 ID 목록입니다.
  /// - [payload]: 업로드에 필요한 모든 정보를 담고 있는 객체입니다. 미디어 파일, 오디오 파일, 캡션, 사용자 정보 등이 포함되어 있습니다.
  ///
  /// returns:
  /// - 업데이트된 카테고리 대표 이미지의 S3 키 목록입니다. 각 카테고리에 대해 하나의 키가 반환됩니다. 업데이트에 실패한 경우 null이 반환됩니다.
  Future<List<String>?> _updateCategoryCoverFromVideo({
    required List<int> categoryIds,
    required UploadPayload payload,
  }) async {
    if (!payload.isVideo || categoryIds.isEmpty) return null;

    final seenCategoryIds = <int>{};
    final categoriesToUpdate = <int>[];

    // 중복된 카테고리 ID를 제거하면서, 대표 이미지가 없는 카테고리만 업데이트 대상으로 선정합니다.
    for (final categoryId in categoryIds) {
      if (!seenCategoryIds.add(categoryId)) {
        continue;
      }

      final category = _categoryController.getCategoryById(categoryId);

      // 카테고리가 존재하고, 대표 이미지가 없는 경우에만 업데이트 대상으로 선정합니다.
      if (category != null &&
          (category.photoUrl == null || category.photoUrl!.trim().isEmpty)) {
        categoriesToUpdate.add(categoryId);
      }
    }

    if (categoriesToUpdate.isEmpty) {
      debugPrint('[PhotoEditorUploadService] 모든 카테고리에 이미 대표사진이 설정되어 있어 스킵');
      return null;
    }

    File? thumbnailFile;
    try {
      // 비디오에서 썸네일을 추출합니다.
      thumbnailFile = await _mediaProcessingService.extractVideoThumbnailFile(
        payload.mediaPath,
      );

      // 추출된 썸네일 파일이 null인 경우, 업로드를 진행할 수 없으므로 null을 반환하고 종료.
      if (thumbnailFile == null) {
        debugPrint('[PhotoEditorUploadService] 비디오 썸네일 생성 실패');
        return null;
      }

      // 썸네일 파일을 MultipartFile로 변환합니다.
      final multipart = await _mediaController.fileToMultipart(thumbnailFile);

      // 카테고리 대표 이미지로 업로드하고, 반환된 S3 키 목록을 처리하여 List<String> 객체로 반환합니다.
      final usageCount = categoriesToUpdate.length;

      // 업로드된 썸네일 이미지의 S3 키 목록을 반환합니다.
      // 각 카테고리에 대해 하나의 키가 반환됩니다.
      // 업로드에 실패한 경우 null이 반환됩니다.
      final keys = await _mediaController.uploadMedia(
        files: [multipart],
        types: [MediaType.image],
        usageTypes: [MediaUsageType.categoryProfile],
        userId: payload.userId,
        refId: categoriesToUpdate.first,
        usageCount: usageCount,
      );

      // 반환된 S3 키 목록의 개수가 기대치와 다를 경우 null을 반환합니다.
      if (keys.length < usageCount) {
        debugPrint(
          '[PhotoEditorUploadService] 카테고리 썸네일 키 수가 부족합니다. keys: $keys',
        );
        return null;
      }

      // 각 카테고리에 대해 업로드된 썸네일 이미지의 S3 키를 사용하여 카테고리 대표 이미지를 업데이트합니다.
      final profileImageKeysByCategoryId = <int, String>{
        for (var i = 0; i < usageCount; i++) categoriesToUpdate[i]: keys[i],
      };
      final allSuccess = await _categoryController.updateCustomProfilesBatch(
        profileImageKeysByCategoryId: profileImageKeysByCategoryId,
      );
      if (!allSuccess) {
        debugPrint('[PhotoEditorUploadService] 일부 카테고리 대표 이미지 업데이트 실패');
      }

      return keys;
    } catch (e) {
      debugPrint('[PhotoEditorUploadService] 비디오 썸네일 업로드/카테고리 업데이트 실패: $e');
      return null;
    } finally {
      if (thumbnailFile != null) {
        try {
          await thumbnailFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _deleteTemporaryFile(File file, String path) async {
    if (!path.contains('/tmp/')) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('임시 파일 삭제 실패: $e');
    }
  }

  Future<void> _deleteTemporaryFiles(UploadPayload payload) async {
    await _deleteTemporaryFile(payload.mediaFile, payload.mediaPath);
    if (payload.audioFile != null && payload.audioPath != null) {
      await _deleteTemporaryFile(payload.audioFile!, payload.audioPath!);
    }
  }
}
