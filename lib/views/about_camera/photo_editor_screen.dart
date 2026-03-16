import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:video_compress/video_compress.dart';

import '../../api/controller/audio_controller.dart';
import '../../api/controller/category_controller.dart' as api_category;
import '../../api/controller/media_controller.dart' as api_media;
import '../../api/controller/post_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../utils/snackbar_utils.dart';
import '../home_navigator_screen.dart';
import 'add_category_screen.dart';
import 'models/add_category_draft.dart';
import 'models/photo_editor_upload_models.dart';
import 'services/photo_editor_media_processing_service.dart';
import 'services/photo_editor_upload_service.dart';
import 'widgets/about_photo_editor_screen/audio_recorder_widget.dart';
import 'widgets/about_photo_editor_screen/caption_input_widget.dart';
import 'widgets/about_photo_editor_screen/category_list_widget.dart';
import 'widgets/about_photo_editor_screen/photo_display_widget.dart';

part 'extension/photo_editor_screen_init.dart';
part 'extension/photo_editor_screen_category_flow.dart';
part 'extension/photo_editor_screen_upload_flow.dart';
part 'extension/photo_editor_screen_helpers.dart';
part 'extension/photo_editor_screen_view.dart';

/// 사진/비디오 편집 및 업로드 화면
///
/// 책임 분리:
/// - 화면 상태/라이프사이클: 이 파일
/// - 초기화/로딩: `photo_editor_screen_init.dart`
/// - 카테고리/바텀시트 흐름: `photo_editor_screen_category_flow.dart`
/// - 업로드/네비게이션 흐름: `photo_editor_screen_upload_flow.dart`
/// - 헬퍼/정리 로직: `photo_editor_screen_helpers.dart`
/// - UI 구성: `photo_editor_screen_view.dart`
/// - 업로드/미디어 처리: `services/`
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
  static const double _kInitialSheetExtent = 0.0;
  static const double _kLockedSheetExtent = 0.19;
  static const double _kExpandedSheetExtent = 0.31;
  static const double _kMaxSheetExtent = 0.8;

  bool _isLoading = true;
  bool _showImmediatePreview = false;
  String? _errorMessageKey;
  Map<String, String>? _errorMessageArgs;
  bool _useLocalImage = false;
  ImageProvider? _initialImageProvider;
  final List<int> _selectedCategoryIds = [];
  bool _categoriesLoaded = false;
  bool _shouldAutoOpenCategorySheet = true;
  bool _isDisposing = false;
  bool _uploadStarted = false;
  String? _resolvedFilePath;
  bool _isResolvingAsset = false;

  double _minChildSize = _kInitialSheetExtent;
  double _initialChildSize = _kLockedSheetExtent;
  bool _hasLockedSheetExtent = false;
  bool _isAnimatingSheet = false;

  List<double>? _recordedWaveformData;
  String? _recordedAudioPath;
  int? _recordedAudioDurationSeconds;
  bool _isCaptionEmpty = true;
  bool _showAudioRecorder = false;

  Future<File>? _compressionTask;
  File? _compressedFile;
  String? _lastCompressedPath;

  double get keyboardHeight => MediaQuery.of(context).viewInsets.bottom;
  bool get isKeyboardVisible => keyboardHeight > 0;
  bool get shouldHideBottomSheet => isKeyboardVisible;

  final _draggableScrollController = DraggableScrollableController();
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();

  late AudioController _audioController;
  late api_category.CategoryController _categoryController;
  late UserController _userController;
  late PostController _postController;
  late api_media.MediaController _mediaController;
  late PhotoEditorUploadService _uploadService;

  final PhotoEditorMediaProcessingService _mediaProcessingService =
      const PhotoEditorMediaProcessingService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (_isTextOnlyMode) {
      _captionController.text = _textOnlyContent;
      _isCaptionEmpty = _textOnlyContent.isEmpty;
    }

    _primeImmediatePreview();
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
  Widget build(BuildContext context) => _buildEditorScaffold(context);

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }
}
