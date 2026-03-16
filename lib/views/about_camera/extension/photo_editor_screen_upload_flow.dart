part of '../photo_editor_screen.dart';

extension _PhotoEditorScreenUploadFlowExtension on _PhotoEditorScreenState {
  String? get _currentFilePath => _resolvedFilePath ?? widget.filePath;

  bool get _isTextOnlyMode {
    final text = widget.inputText?.trim();
    return text != null &&
        text.isNotEmpty &&
        widget.filePath == null &&
        widget.asset == null &&
        widget.downloadUrl == null;
  }

  String get _textOnlyContent => widget.inputText?.trim() ?? '';

  Future<void> _uploadThenNavigate(List<int> categoryIds) async {
    if (_uploadStarted) return;

    _uploadStarted = true;

    try {
      final currentUser = _userController.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar(tr('common.login_required_retry', context: context));
        _uploadStarted = false;
        return;
      }

      if (_isTextOnlyMode) {
        await _handleTextOnlyUploadFlow(
          currentUserId: currentUser.id,
          currentUserNickname: currentUser.userId,
          categoryIds: categoryIds,
        );
        return;
      }

      final filePath = _currentFilePath;
      if (filePath == null || filePath.isEmpty) {
        _safeSetState(() {
          _errorMessageKey = 'camera.editor.upload_file_not_found';
          _errorMessageArgs = null;
        });
        _uploadStarted = false;
        return;
      }

      final snapshot = UploadSnapshot(
        userId: currentUser.id,
        nickName: currentUser.userId,
        filePath: filePath,
        isVideo: widget.isVideo ?? false,
        isFromGallery: !widget.isFromCamera,
        captionText: _captionController.text.trim(),
        recordedAudioPath: _recordedAudioPath,
        recordedWaveformData: _recordedWaveformData != null
            ? List<double>.from(_recordedWaveformData!)
            : null,
        recordedAudioDurationSeconds: _recordedAudioDurationSeconds,
        categoryIds: List<int>.from(categoryIds),
        compressionTask: _compressionTask,
        compressedFile: _compressedFile,
        lastCompressedPath: _lastCompressedPath,
      );

      _navigateToHome();
      _scheduleUploadAfterNavigation(() {
        return _runUploadPipelineAfterNavigation(snapshot);
      });
    } catch (e) {
      debugPrint('업로드 실패: $e');
      _uploadStarted = false;
    }
  }

  Future<void> _runTextOnlyUpload({
    required int userId,
    required String nickName,
    required List<int> categoryIds,
    required String inputText,
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
      _uploadStarted = false;
    }
  }

  Future<void> _runUploadPipelineAfterNavigation(
    UploadSnapshot snapshot,
  ) async {
    try {
      unawaited(_audioController.stopRealtimeAudio());
      _audioController.clearCurrentRecording();
      _evictCurrentImageFromCache(filePath: snapshot.filePath);

      await _uploadService.executeMediaUpload(snapshot);
    } catch (e) {
      debugPrint('[PhotoEditor] 업로드 파이프라인 실패: $e');
    } finally {
      _uploadStarted = false;
    }
  }

  void _navigateToHome() {
    if (!mounted || _isDisposing) return;

    _audioController.stopRealtimeAudio();
    _audioController.clearCurrentRecording();

    HomePageNavigationBar.requestTab(0);

    final navigator = Navigator.of(context);
    var foundHome = false;
    navigator.popUntil((route) {
      final isHome = route.settings.name == '/home_navigation_screen';
      foundHome = foundHome || isHome;
      return isHome || route.isFirst;
    });

    if (!foundHome && mounted) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomePageNavigationBar(
            key: HomePageNavigationBar.rootKey,
            currentPageIndex: 0,
          ),
          settings: const RouteSettings(name: '/home_navigation_screen'),
        ),
        (route) => false,
      );
    }

    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(0.0);
    }
  }

  Future<void> _handleTextOnlyUploadFlow({
    required int currentUserId,
    required String currentUserNickname,
    required List<int> categoryIds,
  }) async {
    final inputText = _textOnlyContent;
    if (inputText.isEmpty) {
      _showErrorSnackBar(tr('camera.text_input_hint', context: context));
      _uploadStarted = false;
      return;
    }
    if (categoryIds.isEmpty) {
      _uploadStarted = false;
      return;
    }

    _navigateToHome();
    _scheduleUploadAfterNavigation(() {
      return _runTextOnlyUpload(
        userId: currentUserId,
        nickName: currentUserNickname,
        categoryIds: List<int>.from(categoryIds),
        inputText: inputText,
      );
    });
  }

  void _scheduleUploadAfterNavigation(Future<void> Function() task) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        unawaited(task());
      });
    });
  }
}
