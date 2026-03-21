import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../../api/controller/audio_controller.dart';
import '../../api/controller/category_controller.dart' as api_category;
import '../../api/controller/media_controller.dart' as api_media;
import '../../api/controller/post_controller.dart';
import '../../api/controller/user_controller.dart';
import '../home_navigator_screen.dart';
import 'add_category_screen.dart';
import 'models/add_category_draft.dart';
import 'services/photo_editor_category_flow_service.dart';
import 'services/photo_editor_cleanup_service.dart';
import 'services/photo_editor_media_processing_service.dart';
import 'services/photo_editor_screen_init_service.dart';
import 'services/photo_editor_upload_flow_service.dart';
import 'services/photo_editor_upload_service.dart';
import 'widgets/about_photo_editor_screen/photo_editor_category_sheet.dart';
import 'widgets/about_photo_editor_screen/photo_editor_input_bar.dart';
import 'widgets/about_photo_editor_screen/photo_editor_scaffold.dart';

/// 사진/비디오 편집 및 업로드 화면
///
/// 화면은 lifecycle과 흐름 조립만 담당하고,
/// UI는 `widgets/about_photo_editor_screen/`,
/// 초기화/카테고리/업로드 처리는 `services/`에서 담당합니다.
class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({
    super.key,
    this.downloadUrl,
    this.filePath,
    this.asset,
    this.inputText,
    this.isVideo,
    this.initialImage,
    this.isFromCamera = true,
  });

  final String? downloadUrl;
  final String? filePath;
  final AssetEntity? asset;
  final String? inputText;
  final bool? isVideo;
  final ImageProvider? initialImage;
  final bool isFromCamera;

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen>
    with WidgetsBindingObserver {
  bool _controllersInitialized = false;
  bool _isLoading = true;
  bool _showImmediatePreview = false;
  String? _errorMessageKey;
  Map<String, String>? _errorMessageArgs;
  bool _useLocalImage = false;
  ImageProvider? _initialImageProvider;
  final List<int> _selectedCategoryIds = [];
  bool _categoriesLoaded = false;
  bool _isDisposing = false;
  bool _uploadStarted = false;
  String? _resolvedFilePath;
  bool _isResolvingAsset = false;

  List<double>? _recordedWaveformData;
  String? _recordedAudioPath;
  int? _recordedAudioDurationSeconds;
  bool _isCaptionEmpty = true;
  bool _showAudioRecorder = false;

  Future<File>? _compressionTask;
  File? _compressedFile;
  String? _lastCompressedPath;

  final PhotoEditorCategorySheetController _categorySheetController =
      PhotoEditorCategorySheetController();
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();

  late AudioController _audioController;
  late api_category.CategoryController _categoryController;
  late UserController _userController;
  late PostController _postController;
  late api_media.MediaController _mediaController;
  late PhotoEditorUploadService _uploadService;
  late PhotoEditorCategoryFlowService _categoryFlowService;
  late PhotoEditorUploadFlowService _uploadFlowService;

  final PhotoEditorMediaProcessingService _mediaProcessingService =
      const PhotoEditorMediaProcessingService();
  late final PhotoEditorScreenInitService _screenInitService =
      PhotoEditorScreenInitService(
        mediaProcessingService: _mediaProcessingService,
      );

  String? get _currentFilePath => _resolvedFilePath ?? widget.filePath;

  bool get _isTextOnlyMode => PhotoEditorScreenInitService.isTextOnlyMode(
    inputText: widget.inputText,
    filePath: widget.filePath,
    asset: widget.asset,
    downloadUrl: widget.downloadUrl,
  );

  String get _textOnlyContent =>
      PhotoEditorScreenInitService.textOnlyContent(widget.inputText);

  bool get _shouldHideBottomSheet =>
      MediaQuery.of(context).viewInsets.bottom > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (_isTextOnlyMode) {
      _captionController.text = _textOnlyContent;
      _isCaptionEmpty = _textOnlyContent.isEmpty;
    }

    _applyPreviewState(
      _screenInitService.primeImmediatePreview(
        initialImage: widget.initialImage,
        filePath: _currentFilePath,
      ),
    );
    _initializeScreen();
    _captionController.addListener(_handleCaptionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _captionFocusNode.unfocus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeControllers();
    _loadCategoriesIfNeeded();
    _startPreCompressionIfNeeded();
    _mediaController.clearVideoThumbnailCache();
  }

  @override
  void didUpdateWidget(PhotoEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handleWidgetUpdate(oldWidget);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _handleAppStateChange(state);
  }

  @override
  Widget build(BuildContext context) {
    return PhotoEditorScaffold(
      isLoading: _isLoading,
      showImmediatePreview: _showImmediatePreview,
      errorMessageKey: _errorMessageKey,
      errorMessageArgs: _errorMessageArgs,
      isTextOnlyMode: _isTextOnlyMode,
      textOnlyContent: _textOnlyContent,
      currentFilePath: _currentFilePath,
      useLocalImage: _useLocalImage,
      initialImageProvider: _initialImageProvider,
      isVideo: widget.isVideo ?? false,
      isFromCamera: widget.isFromCamera,
      onPreviewCancel: _categorySheetController.resetIfNeeded,
      captionInputBar: _isTextOnlyMode
          ? null
          : PhotoEditorInputBar(
              showAudioRecorder: _showAudioRecorder,
              audioController: _audioController,
              captionController: _captionController,
              captionFocusNode: _captionFocusNode,
              isCaptionEmpty: _isCaptionEmpty,
              recordedAudioPath: _recordedAudioPath,
              recordedWaveformData: _recordedWaveformData,
              onMicTap: () {
                _safeSetState(() => _showAudioRecorder = true);
                _captionFocusNode.unfocus();
              },
              onRecordingFinished: (audioFilePath, waveformData, duration) {
                _safeSetState(() {
                  _recordedAudioPath = audioFilePath;
                  _recordedWaveformData = waveformData;
                  _recordedAudioDurationSeconds = duration.inSeconds;
                });
              },
              onRecordingCleared: () {
                _safeSetState(() {
                  _showAudioRecorder = false;
                  _recordedAudioPath = null;
                  _recordedWaveformData = null;
                  _recordedAudioDurationSeconds = null;
                });
                _audioController.clearCurrentRecording();
              },
            ),
      bottomSheet: PhotoEditorCategorySheet(
        controller: _categorySheetController,
        selectedCategoryIds: _selectedCategoryIds,
        onCategorySelected: _handleCategorySelection,
        addCategoryPressed: _openAddCategoryScreen,
        onConfirmSelection: () => _uploadThenNavigate(_selectedCategoryIds),
        isHidden: _shouldHideBottomSheet,
        shouldAutoOpen:
            _controllersInitialized && _userController.currentUser != null,
      ),
    );
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) {
      return;
    }
    setState(fn);
  }

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

  void _initializeControllers() {
    if (_controllersInitialized) {
      return;
    }

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
    _categoryFlowService = PhotoEditorCategoryFlowService(
      categoryController: _categoryController,
      uploadService: _uploadService,
    );
    _uploadFlowService = PhotoEditorUploadFlowService(
      uploadService: _uploadService,
      audioController: _audioController,
    );
    _controllersInitialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioController.initialize();
    });
  }

  void _applyPreviewState(PhotoEditorPreviewState previewState) {
    _isLoading = previewState.isLoading;
    _showImmediatePreview = previewState.showImmediatePreview;
    _useLocalImage = previewState.useLocalImage;
    _initialImageProvider = previewState.initialImageProvider;
    _errorMessageKey = previewState.errorMessageKey;
    _errorMessageArgs = previewState.errorMessageArgs;
    _resolvedFilePath = previewState.resolvedFilePath;
  }

  void _handleCaptionChanged() {
    final isEmpty = _captionController.text.trim().isEmpty;
    if (isEmpty == _isCaptionEmpty) {
      return;
    }

    if (!mounted) {
      _isCaptionEmpty = isEmpty;
      return;
    }

    _safeSetState(() => _isCaptionEmpty = isEmpty);
  }

  void _loadCategoriesIfNeeded() {
    if (!_controllersInitialized || _categoriesLoaded) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadUserCategories());
    });
  }

  Future<void> _loadUserCategories({bool forceReload = false}) async {
    if (!_controllersInitialized) {
      return;
    }

    if (_userController.currentUser != null) {
      _categorySheetController.ensureLockedOpen();
    }

    final result = await _categoryFlowService.loadUserCategories(
      currentUserId: _userController.currentUser?.id,
      forceReload: forceReload,
    );

    if (!mounted) {
      return;
    }

    if (result.didLoad) {
      _categoriesLoaded = true;
      _safeSetState(() {});
      return;
    }

    _safeSetState(() {
      _errorMessageKey = result.errorMessageKey;
      _errorMessageArgs = result.errorMessageArgs;
      _isLoading = false;
    });
  }

  Future<void> _resolveAssetFileIfNeeded() async {
    if (widget.asset == null ||
        _isResolvingAsset ||
        _resolvedFilePath != null) {
      return;
    }

    _isResolvingAsset = true;
    try {
      final previewState = await _screenInitService.resolveAssetPreview(
        asset: widget.asset!,
        showImmediatePreview: _showImmediatePreview,
        initialImageProvider: _initialImageProvider,
        useLocalImage: _useLocalImage,
      );

      if (!mounted) {
        return;
      }

      _safeSetState(() => _applyPreviewState(previewState));
    } finally {
      _isResolvingAsset = false;
    }
  }

  void _handleWidgetUpdate(PhotoEditorScreen oldWidget) {
    final mediaChanged =
        oldWidget.filePath != widget.filePath ||
        oldWidget.downloadUrl != widget.downloadUrl ||
        oldWidget.initialImage != widget.initialImage ||
        oldWidget.asset?.id != widget.asset?.id ||
        oldWidget.inputText != widget.inputText;
    if (!mediaChanged) {
      return;
    }

    _categoriesLoaded = false;
    _resolvedFilePath = null;
    _isResolvingAsset = false;

    if (_isTextOnlyMode) {
      _resetTextOnlyEditorState();
    } else {
      _applyPreviewState(
        _screenInitService.primeImmediatePreview(
          initialImage: widget.initialImage,
          filePath: _currentFilePath,
        ),
      );

      if (widget.asset != null) {
        unawaited(_resolveAssetFileIfNeeded());
      } else if (!_showImmediatePreview) {
        unawaited(_loadImage());
      }
    }

    _startPreCompressionIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadUserCategories(forceReload: true));
    });
  }

  void _handleAppStateChange(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    _categoriesLoaded = false;
    unawaited(_loadUserCategories(forceReload: true));
  }

  Future<void> _loadImage() async {
    final previewState = await _screenInitService.loadImage(
      filePath: _currentFilePath,
      showImmediatePreview: _showImmediatePreview,
      initialImageProvider: _initialImageProvider,
      useLocalImage: _useLocalImage,
    );

    if (!mounted) {
      return;
    }

    _safeSetState(() => _applyPreviewState(previewState));
  }

  void _startPreCompressionIfNeeded() {
    final filePath = _currentFilePath;
    if (filePath == null || filePath.isEmpty) {
      return;
    }
    if (_lastCompressedPath == filePath && _compressionTask != null) {
      return;
    }

    final compressionTask = _screenInitService.createImagePreCompressionTask(
      isVideo: widget.isVideo == true,
      filePath: filePath,
    );
    if (compressionTask == null) {
      return;
    }

    _lastCompressedPath = filePath;
    _compressionTask = compressionTask
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
    _applyPreviewState(const PhotoEditorPreviewState.textOnly());
  }

  void _handleCategorySelection(int categoryId) {
    _safeSetState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }

  Future<void> _openAddCategoryScreen() async {
    final draft = await Navigator.push<AddCategoryDraft>(
      context,
      MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
    );

    if (draft == null || !mounted || _isDisposing) {
      return;
    }

    unawaited(_runAddCategoryInBackground(draft));
  }

  Future<void> _runAddCategoryInBackground(AddCategoryDraft draft) async {
    if (_isDisposing) {
      return;
    }

    _showErrorSnackBar(tr('common.please_wait', context: context));

    final result = await _categoryFlowService.createCategory(draft);
    if (!mounted || _isDisposing) {
      return;
    }

    switch (result.status) {
      case PhotoEditorCategoryCreationStatus.success:
        _showErrorSnackBar(
          tr('archive.create_category_success', context: context),
        );
        return;
      case PhotoEditorCategoryCreationStatus.createFailed:
        _showErrorSnackBar(
          result.errorMessage ??
              tr(
                'camera.editor.category_create_failed_retry',
                context: context,
              ),
        );
        return;
      case PhotoEditorCategoryCreationStatus.coverUpdateFailed:
        _showErrorSnackBar(
          result.errorMessage ??
              tr('category.cover.update_failed', context: context),
        );
        return;
      case PhotoEditorCategoryCreationStatus.unexpectedError:
        _showErrorSnackBar(
          tr('camera.editor.category_create_error', context: context),
        );
        return;
    }
  }

  Future<void> _uploadThenNavigate(List<int> categoryIds) async {
    if (_uploadStarted) {
      return;
    }

    _uploadStarted = true;

    try {
      final currentUser = _userController.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar(tr('common.login_required_retry', context: context));
        _uploadStarted = false;
        return;
      }

      if (_isTextOnlyMode) {
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
        PhotoEditorUploadFlowService.scheduleUploadAfterNavigation(() {
          return _uploadFlowService.runTextOnlyUpload(
            userId: currentUser.id,
            nickName: currentUser.userId,
            categoryIds: List<int>.from(categoryIds),
            inputText: inputText,
            onComplete: () => _uploadStarted = false,
          );
        });
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

      final snapshot = _uploadFlowService.buildUploadSnapshot(
        userId: currentUser.id,
        nickName: currentUser.userId,
        filePath: filePath,
        isVideo: widget.isVideo ?? false,
        isFromGallery: !widget.isFromCamera,
        captionText: _captionController.text.trim(),
        recordedAudioPath: _recordedAudioPath,
        recordedWaveformData: _recordedWaveformData,
        recordedAudioDurationSeconds: _recordedAudioDurationSeconds,
        categoryIds: categoryIds,
        compressionTask: _compressionTask,
        compressedFile: _compressedFile,
        lastCompressedPath: _lastCompressedPath,
      );

      _navigateToHome();
      PhotoEditorUploadFlowService.scheduleUploadAfterNavigation(() {
        return _uploadFlowService.runUploadPipelineAfterNavigation(
          snapshot,
          onComplete: () => _uploadStarted = false,
        );
      });
    } catch (e) {
      debugPrint('업로드 실패: $e');
      _uploadStarted = false;
    }
  }

  void _navigateToHome() {
    if (!mounted || _isDisposing) {
      return;
    }

    _uploadFlowService.prepareForNavigation();
    _categorySheetController.collapseToStart();
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
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }

    PhotoEditorCleanupService.showErrorSnackBar(context, message);
  }

  @override
  void dispose() {
    _isDisposing = true;
    _compressionTask = null;
    _compressedFile = null;
    _lastCompressedPath = null;
    _recordedWaveformData = null;
    _recordedAudioPath = null;
    _recordedAudioDurationSeconds = null;
    _categorySheetController.collapseToStart();

    if (_controllersInitialized) {
      PhotoEditorCleanupService.disposeScreen(
        observer: this,
        audioController: _audioController,
        captionController: _captionController,
        captionListener: _handleCaptionChanged,
        captionFocusNode: _captionFocusNode,
        filePath: _currentFilePath,
        downloadUrl: widget.downloadUrl,
      );
    } else {
      _captionController.removeListener(_handleCaptionChanged);
      _captionController.dispose();
      _captionFocusNode.dispose();
      WidgetsBinding.instance.removeObserver(this);
    }

    super.dispose();
  }
}
