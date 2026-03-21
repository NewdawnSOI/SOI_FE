import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../api/controller/audio_controller.dart';
import '../models/photo_editor_upload_models.dart';
import 'photo_editor_cleanup_service.dart';
import 'photo_editor_upload_service.dart';

class PhotoEditorUploadFlowService {
  const PhotoEditorUploadFlowService({
    required PhotoEditorUploadService uploadService,
    required AudioController audioController,
  }) : _uploadService = uploadService,
       _audioController = audioController;

  final PhotoEditorUploadService _uploadService;
  final AudioController _audioController;

  UploadSnapshot buildUploadSnapshot({
    required int userId,
    required String nickName,
    required String filePath,
    required bool isVideo,
    required bool isFromGallery,
    required String captionText,
    required String? recordedAudioPath,
    required List<double>? recordedWaveformData,
    required int? recordedAudioDurationSeconds,
    required List<int> categoryIds,
    required Future<File>? compressionTask,
    required File? compressedFile,
    required String? lastCompressedPath,
  }) {
    return UploadSnapshot(
      userId: userId,
      nickName: nickName,
      filePath: filePath,
      isVideo: isVideo,
      isFromGallery: isFromGallery,
      captionText: captionText,
      recordedAudioPath: recordedAudioPath,
      recordedWaveformData: recordedWaveformData != null
          ? List<double>.from(recordedWaveformData)
          : null,
      recordedAudioDurationSeconds: recordedAudioDurationSeconds,
      categoryIds: List<int>.from(categoryIds),
      compressionTask: compressionTask,
      compressedFile: compressedFile,
      lastCompressedPath: lastCompressedPath,
    );
  }

  Future<void> runTextOnlyUpload({
    required int userId,
    required String nickName,
    required List<int> categoryIds,
    required String inputText,
    required VoidCallback onComplete,
  }) async {
    try {
      await _uploadService.executeTextOnlyUpload(
        userId: userId,
        nickName: nickName,
        categoryIds: categoryIds,
        inputText: inputText,
      );
    } catch (e) {
      debugPrint('[PhotoEditor] 텍스트 게시물 업로드 실패: $e');
    } finally {
      onComplete();
    }
  }

  Future<void> runUploadPipelineAfterNavigation(
    UploadSnapshot snapshot, {
    required VoidCallback onComplete,
  }) async {
    try {
      unawaited(_audioController.stopRealtimeAudio());
      _audioController.clearCurrentRecording();
      PhotoEditorCleanupService.evictCurrentImageFromCache(
        filePath: snapshot.filePath,
      );

      await _uploadService.executeMediaUpload(snapshot);
    } catch (e) {
      debugPrint('[PhotoEditor] 업로드 파이프라인 실패: $e');
    } finally {
      onComplete();
    }
  }

  void prepareForNavigation() {
    _audioController.stopRealtimeAudio();
    _audioController.clearCurrentRecording();
  }

  static void scheduleUploadAfterNavigation(Future<void> Function() task) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        unawaited(task());
      });
    });
  }
}
