part of '../photo_editor_screen.dart';

extension _PhotoEditorScreenInitializationExtension on _PhotoEditorScreenState {
  void _initializeScreen() {
    if (_isTextOnlyMode) {
      _resetTextOnlyEditorState();
      return;
    }

    if (widget.asset != null) {
      unawaited(_resolveAssetFileIfNeeded());
      return;
    }
    if (!_showImmediatePreview) {
      unawaited(_loadImage());
    }
  }

  Future<void> _resolveAssetFileIfNeeded() async {
    if (widget.asset == null) return;
    if (_isResolvingAsset || _resolvedFilePath != null) return;

    _isResolvingAsset = true;
    try {
      final file = await widget.asset!.file;
      if (!mounted) return;

      if (file != null) {
        _resolvedFilePath = file.path;
      } else {
        _errorMessageKey = 'camera.editor.image_not_found';
        _errorMessageArgs = null;
      }
    } catch (e) {
      if (!mounted) return;
      _errorMessageKey = 'camera.editor.image_load_error_with_reason';
      _errorMessageArgs = {'error': e.toString()};
    } finally {
      _isResolvingAsset = false;
    }

    if (!mounted) return;
    if (!_showImmediatePreview) {
      await _loadImage();
    } else {
      _safeSetState(() {});
    }
  }

  void _primeImmediatePreview() {
    if (widget.initialImage != null) {
      _applyInitialImagePreview(widget.initialImage!);
      return;
    }

    final localPath = _currentFilePath;
    if (localPath == null || localPath.isEmpty) return;

    final file = File(localPath);
    if (!file.existsSync()) return;

    _useLocalImage = true;
    _showImmediatePreview = true;
    _isLoading = false;
  }

  void _initializeControllers() {
    _audioController = Provider.of<AudioController>(context, listen: false);
    _categoryController = Provider.of<api_category.CategoryController>(
      context,
      listen: false,
    );
    _userController = Provider.of<UserController>(context, listen: false);
    _postController = Provider.of<PostController>(context, listen: false);
    _mediaController = Provider.of<api_media.MediaController>(
      context,
      listen: false,
    );
    _uploadService = PhotoEditorUploadService(
      postController: _postController,
      mediaController: _mediaController,
      categoryController: _categoryController,
      mediaProcessingService: _mediaProcessingService,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioController.initialize();
    });
  }

  void _handleCaptionChanged() {
    final isEmpty = _captionController.text.trim().isEmpty;
    if (isEmpty == _isCaptionEmpty) return;

    if (!mounted) {
      _isCaptionEmpty = isEmpty;
      return;
    }
    _safeSetState(() => _isCaptionEmpty = isEmpty);
  }

  void _loadCategoriesIfNeeded() {
    if (_categoriesLoaded) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadUserCategories());
    });
  }

  void _handleWidgetUpdate(PhotoEditorScreen oldWidget) {
    final mediaChanged =
        oldWidget.filePath != widget.filePath ||
        oldWidget.downloadUrl != widget.downloadUrl ||
        oldWidget.initialImage != widget.initialImage ||
        oldWidget.asset?.id != widget.asset?.id ||
        oldWidget.inputText != widget.inputText;
    if (!mediaChanged) return;

    _categoriesLoaded = false;
    _resolvedFilePath = null;
    _isResolvingAsset = false;

    if (_isTextOnlyMode) {
      _resetTextOnlyEditorState();
    } else {
      if (widget.initialImage != null) {
        _applyInitialImagePreview(widget.initialImage!);
      }
      if (widget.asset != null) {
        unawaited(_resolveAssetFileIfNeeded());
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadUserCategories(forceReload: true));
    });
  }

  void _handleAppStateChange(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    _categoriesLoaded = false;
    unawaited(_loadUserCategories(forceReload: true));
  }

  Future<void> _loadImage() async {
    _errorMessageKey = null;
    _errorMessageArgs = null;

    if (_showImmediatePreview) {
      _isLoading = false;
      _safeSetState(() {});
      return;
    }

    final localPath = _currentFilePath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      try {
        final exists = await file.exists();
        if (!mounted) return;

        if (exists) {
          _safeSetState(() {
            _useLocalImage = true;
            _showImmediatePreview = true;
            _isLoading = false;
          });
          return;
        }

        _safeSetState(() {
          _errorMessageKey = 'camera.editor.image_not_found';
          _errorMessageArgs = null;
          _isLoading = false;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        _safeSetState(() {
          _errorMessageKey = 'camera.editor.image_load_error_with_reason';
          _errorMessageArgs = {'error': e.toString()};
          _isLoading = false;
        });
        return;
      }
    }

    _isLoading = false;
    _safeSetState(() {});
  }

  void _startPreCompressionIfNeeded() {
    if (widget.isVideo == true) return;

    final filePath = _currentFilePath;
    if (filePath == null || filePath.isEmpty) return;
    if (_lastCompressedPath == filePath && _compressionTask != null) return;

    _lastCompressedPath = filePath;
    _compressionTask = _mediaProcessingService
        .compressImageIfNeeded(File(filePath))
        .then((compressed) {
          _compressedFile = compressed;
          return compressed;
        })
        .catchError((error) {
          debugPrint('백그라운드 압축 실패: $error');
          final fallbackFile = File(filePath);
          _compressedFile = fallbackFile;
          return fallbackFile;
        });
  }

  void _resetTextOnlyEditorState() {
    _captionController.text = _textOnlyContent;
    _isCaptionEmpty = _textOnlyContent.isEmpty;
    _showImmediatePreview = false;
    _useLocalImage = false;
    _isLoading = false;
    _errorMessageKey = null;
    _errorMessageArgs = null;
  }

  void _applyInitialImagePreview(ImageProvider imageProvider) {
    _initialImageProvider = imageProvider;
    _showImmediatePreview = true;
    _useLocalImage = true;
    _isLoading = false;
  }
}
