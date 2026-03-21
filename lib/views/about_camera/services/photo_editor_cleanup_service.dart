import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_compress/video_compress.dart';

import '../../../api/controller/audio_controller.dart';
import '../../../utils/snackbar_utils.dart';

class PhotoEditorCleanupService {
  const PhotoEditorCleanupService._();

  static void showErrorSnackBar(BuildContext context, String message) {
    SnackBarUtils.showSnackBar(context, message);
  }

  static void evictCurrentImageFromCache({
    String? filePath,
    String? downloadUrl,
  }) {
    if (filePath != null && filePath.isNotEmpty) {
      PaintingBinding.instance.imageCache.evict(FileImage(File(filePath)));
    }
    if (downloadUrl != null && downloadUrl.isNotEmpty) {
      PaintingBinding.instance.imageCache.evict(NetworkImage(downloadUrl));
    }
  }

  static void disposeScreen({
    required WidgetsBindingObserver observer,
    required AudioController audioController,
    required TextEditingController captionController,
    required VoidCallback captionListener,
    required FocusNode captionFocusNode,
    required String? filePath,
    required String? downloadUrl,
  }) {
    if (!kIsWeb) {
      VideoCompress.cancelCompression();
      VideoCompress.dispose();
    }

    audioController.stopRealtimeAudio();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      audioController.clearCurrentRecording();
    });

    evictCurrentImageFromCache(filePath: filePath, downloadUrl: downloadUrl);

    captionController.removeListener(captionListener);
    captionController.dispose();
    captionFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(observer);
  }
}
