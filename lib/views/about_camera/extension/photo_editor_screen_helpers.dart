part of '../photo_editor_screen.dart';

extension _PhotoEditorScreenHelperExtension on _PhotoEditorScreenState {
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    SnackBarUtils.showSnackBar(context, message);
  }

  void _clearImageCache() {
    _evictCurrentImageFromCache(
      filePath: _currentFilePath,
      downloadUrl: widget.downloadUrl,
    );
  }

  void _evictCurrentImageFromCache({String? filePath, String? downloadUrl}) {
    if (filePath != null && filePath.isNotEmpty) {
      PaintingBinding.instance.imageCache.evict(FileImage(File(filePath)));
    }
    if (downloadUrl != null && downloadUrl.isNotEmpty) {
      PaintingBinding.instance.imageCache.evict(NetworkImage(downloadUrl));
    }
  }

  void _disposeResources() {
    _isDisposing = true;

    _compressionTask = null;
    _compressedFile = null;
    _lastCompressedPath = null;

    if (!kIsWeb) {
      VideoCompress.cancelCompression();
      VideoCompress.dispose();
    }

    _audioController.stopRealtimeAudio();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _audioController.clearCurrentRecording();
    });
    _recordedWaveformData = null;
    _recordedAudioPath = null;
    _recordedAudioDurationSeconds = null;

    _clearImageCache();

    _captionController.removeListener(_handleCaptionChanged);
    _captionController.dispose();
    _captionFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(0.0);
    }
    _draggableScrollController.dispose();
  }
}
