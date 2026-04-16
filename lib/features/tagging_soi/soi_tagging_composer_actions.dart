import 'package:flutter/material.dart';

import '../../views/common_widget/comment/comment_audio_recording_bottom_sheet_widget.dart';
import '../../views/common_widget/comment/comment_camera_bottom_sheet_widget.dart';

/// SOI 전용 카메라/오디오 바텀시트를 열고 드래프트 staging 콜백까지 연결합니다.
class SoiTaggingComposerActions {
  const SoiTaggingComposerActions._();

  static Future<bool> requestCameraDraft({
    required BuildContext context,
    required Future<void> Function(String localFilePath, bool isVideo)
    onSelected,
  }) async {
    final result = await showModalBottomSheet<CommentCameraSheetResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const CommentCameraRecordingBottomSheetWidget(),
    );

    if (result == null) {
      return false;
    }

    await onSelected(result.localFilePath, result.isVideo);
    return true;
  }

  static Future<bool> requestAudioDraft({
    required BuildContext context,
    required Future<void> Function(
      String audioPath,
      List<double> waveformData,
      int durationMs,
    )
    onSelected,
  }) async {
    final result = await showModalBottomSheet<CommentAudioSheetResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const CommentAudioRecordingBottomSheetWidget(),
    );

    if (result == null) {
      return false;
    }

    await onSelected(result.audioPath, result.waveformData, result.durationMs);
    return true;
  }
}
