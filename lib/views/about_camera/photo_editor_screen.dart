import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../firebase_logic/controllers/audio_controller.dart';
import '../../firebase_logic/controllers/auth_controller.dart';
import '../../firebase_logic/controllers/category_controller.dart';
import '../../firebase_logic/controllers/photo_controller.dart';
import '../../firebase_logic/models/selected_friend_model.dart';
import '../../utils/video_thumbnail_generator.dart';
import '../home_navigator_screen.dart';
import 'widgets/add_category_widget.dart';
import 'widgets/audio_recorder_widget.dart';
import 'widgets/caption_input_widget.dart';
import 'widgets/category_list_widget.dart';
import 'widgets/loading_popup_widget.dart';
import 'widgets/photo_display_widget.dart';

class PhotoEditorScreen extends StatefulWidget {
  final String? downloadUrl;
  final String? filePath;

  // 미디어가 비디오인지 여부를 체크하는 플래그
  final bool? isVideo;
  final ImageProvider? initialImage;

  // 카메라에서 직접 촬영된 미디어인지 여부 (true: 촬영됨, false: 갤러리에서 선택됨)
  final bool isFromCamera;

  const PhotoEditorScreen({
    super.key,
    this.downloadUrl,
    this.filePath,
    this.isVideo,
    this.initialImage,
    this.isFromCamera = true, // 기본값은 촬영된 것으로 설정
  });
  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _showImmediatePreview = false;
  String? _errorMessage;
  bool _useLocalImage = false;
  ImageProvider? _initialImageProvider;
  bool _showAddCategoryUI = false;
  final List<String> _selectedCategoryIds = [];
  bool _categoriesLoaded = false;
  bool _shouldAutoOpenCategorySheet = true;
  bool _isDisposing = false;
  static const double _kInitialSheetExtent = 0.0;
  static const double _kLockedSheetExtent = 0.19;
  static const double _kExpandedSheetExtent = 0.31;
  static const double _kMaxSheetExtent = 0.8;
  double _minChildSize = _kInitialSheetExtent;
  double _initialChildSize = _kInitialSheetExtent;
  bool _hasLockedSheetExtent = false;
  List<double>? _recordedWaveformData;
  String? _recordedAudioPath;
  bool _isCaptionEmpty = true;
  bool _showAudioRecorder = false;

  double get keyboardHeight => MediaQuery.of(context).viewInsets.bottom;
  bool get isKeyboardVisible => keyboardHeight > 0;
  bool get shouldHideBottomSheet => isKeyboardVisible && !_showAddCategoryUI;

  final _draggableScrollController = DraggableScrollableController();
  final _categoryNameController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  late AudioController _audioController;
  late CategoryController _categoryController;
  late AuthController _authController;
  late PhotoController _photoController;

  final FocusNode _captionFocusNode = FocusNode();
  final FocusNode _categoryFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _primeImmediatePreview();
    _initializeScreen();
    _captionController.addListener(_handleCaptionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeControllers();
    _loadCategoriesIfNeeded();
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

  // ========== 초기화 메서드들 ==========
  void _initializeScreen() {
    if (!_showImmediatePreview) _loadImage();
  }

  void _primeImmediatePreview() {
    if (widget.initialImage != null) {
      _initialImageProvider = widget.initialImage;
      _showImmediatePreview = true;
      _useLocalImage = true;
      _isLoading = false;
      return;
    }

    final localPath = widget.filePath;
    if (localPath == null || localPath.isEmpty) return;

    final file = File(localPath);
    if (!file.existsSync()) return;

    _useLocalImage = true;
    _showImmediatePreview = true;
    _isLoading = false;
  }

  void _initializeControllers() {
    _audioController = Provider.of<AudioController>(context, listen: false);
    _categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    _authController = Provider.of<AuthController>(context, listen: false);
    _photoController = Provider.of<PhotoController>(context, listen: false);
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
    setState(() => _isCaptionEmpty = isEmpty);
  }

  void _loadCategoriesIfNeeded() {
    if (!_categoriesLoaded) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadUserCategories(),
      );
    }
  }

  void _handleWidgetUpdate(PhotoEditorScreen oldWidget) {
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.downloadUrl != widget.downloadUrl ||
        oldWidget.initialImage != widget.initialImage) {
      _categoriesLoaded = false;
      if (widget.initialImage != null) {
        _initialImageProvider = widget.initialImage;
        _showImmediatePreview = true;
        _useLocalImage = true;
        _isLoading = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserCategories(forceReload: true);
      });
    }
  }

  void _handleAppStateChange(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _categoriesLoaded = false;
      _loadUserCategories(forceReload: true);
    }
  }

  // ========== 이미지 및 카테고리 로딩 메서드들 ==========
  Future<void> _loadImage() async {
    _errorMessage = null;

    // _primeImmediatePreview에서 이미 처리된 경우
    if (_showImmediatePreview) {
      _isLoading = false;
      if (mounted) setState(() {});
      return;
    }

    final localPath = widget.filePath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      try {
        final exists = await file.exists();
        if (!mounted) return;

        if (exists) {
          setState(() {
            _useLocalImage = true;
            _showImmediatePreview = true;
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _errorMessage = '이미지 파일을 찾을 수 없습니다.';
          _isLoading = false;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = "이미지 로딩 중 오류 발생: $e";
          _isLoading = false;
        });
        return;
      }
    }

    // downloadUrl이 있거나 둘 다 없는 경우
    _isLoading = false;
    if (mounted) setState(() {});
  }

  Future<void> _loadUserCategories({bool forceReload = false}) async {
    if (!forceReload && _categoriesLoaded) return;

    final currentUser = _authController.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _errorMessage = "로그인이 필요합니다.";
          _isLoading = false;
        });
      }
      return;
    }

    // 바텀시트를 먼저 올림 (로딩 시작 전)
    // 바텀 시트를 먼저 올리고 아래에서 로딩을 시작한다.
    if (_shouldAutoOpenCategorySheet) {
      _shouldAutoOpenCategorySheet = false;
      _animateSheetTo(_kLockedSheetExtent, lockExtent: true);
    }

    try {
      // 카테고리를 로드하는 동안, shimmer를 표시해서 사용자에게 로딩 중임을 알린다.
      await _categoryController.loadUserCategories(
        currentUser.uid,
        forceReload: forceReload,
      );
      _categoriesLoaded = true;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "카테고리 로드 중 오류 발생: $e";
        });
      }
    }
  }

  void _handleCategorySelection(String categoryId) {
    final wasEmpty = _selectedCategoryIds.isEmpty;

    // 현재 바텀시트 위치 확인
    final currentExtent = _draggableScrollController.isAttached
        ? _draggableScrollController.size
        : _kLockedSheetExtent;

    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });

    // 카테고리 선택 상태에 따라 바텀시트 높이 조정
    if (_selectedCategoryIds.isEmpty) {
      _animateSheetTo(_kLockedSheetExtent);
    } else if (wasEmpty) {
      // 바텀시트가 이미 확장된 상태(0.19보다 크게 열린 상태)라면 위치 유지
      if (currentExtent > _kLockedSheetExtent + 0.05) {
        // 바텀시트를 움직이지 않음 (사용자가 올린 위치 유지)
        return;
      }
      _animateSheetTo(_kExpandedSheetExtent);
    }
  }

  void _animateSheetTo(double size, {bool lockExtent = false}) {
    if (!mounted || _isDisposing) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isDisposing || !_draggableScrollController.isAttached) {
        return;
      }

      await _draggableScrollController.animateTo(
        size,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      // 애니메이션 완료 후 lockExtent 처리
      if (lockExtent && !_hasLockedSheetExtent && mounted) {
        _minChildSize = size;
        _initialChildSize = size;
        _hasLockedSheetExtent = true;
      }
    });
  }

  Future<void> _resetBottomSheetIfNeeded() async {
    if (_isDisposing || !_draggableScrollController.isAttached) return;

    final targetSize = _hasLockedSheetExtent
        ? _kLockedSheetExtent
        : _initialChildSize;
    final currentSize = _draggableScrollController.size;

    if ((currentSize - targetSize).abs() > 0.001) {
      await _draggableScrollController.animateTo(
        targetSize,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleMicTap() {
    setState(() => _showAudioRecorder = true);
    _captionFocusNode.unfocus();
  }

  Widget _buildCaptionInputBar() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _showAudioRecorder
          ? Padding(
              key: const ValueKey('audio_recorder'),
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: AudioRecorderWidget(
                autoStart: true,

                onRecordingFinished: (audioFilePath, waveformData, duration) {
                  setState(() {
                    _recordedAudioPath = audioFilePath;
                    _recordedWaveformData = waveformData;
                  });
                },
                onRecordingCleared: () {
                  setState(() {
                    _showAudioRecorder = false;
                    _recordedAudioPath = null;
                    _recordedWaveformData = null;
                  });
                },
                initialRecordingPath: _recordedAudioPath,
                initialWaveformData: _recordedWaveformData,
              ),
            )
          : FocusScope(
              key: const ValueKey('caption_input'),
              child: Focus(
                onFocusChange: (isFocused) {
                  if (_categoryFocusNode.hasFocus) {
                    FocusScope.of(context).requestFocus(_categoryFocusNode);
                  }
                },
                child: CaptionInputWidget(
                  controller: _captionController,
                  isCaptionEmpty: _isCaptionEmpty,
                  onMicTap: _handleMicTap,
                  isKeyboardVisible: !_categoryFocusNode.hasFocus,
                  keyboardHeight: keyboardHeight,
                  focusNode: _captionFocusNode,
                ),
              ),
            ),
    );
  }

  Future<void> _createNewCategory(
    List<SelectedFriendModel> selectedFriends,
  ) async {
    if (_categoryNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카테고리 이름을 입력해주세요')));
      return;
    }

    try {
      final userId = _authController.getUserId;
      if (userId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인이 필요합니다. 다시 로그인해주세요.')));
        return;
      }

      List<String> mates = [userId, ...selectedFriends.map((f) => f.uid)];

      await _categoryController.createCategory(
        name: _categoryNameController.text.trim(),
        mates: mates,
      );

      _categoriesLoaded = false;
      await _loadUserCategories(forceReload: true);

      if (!mounted) return;
      setState(() {
        _showAddCategoryUI = false;
        _categoryNameController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카테고리 생성 중 오류가 발생했습니다')));
    }
  }

  // ========== 업로드 및 화면 전환 관련 메서드들 ==========
  Future<void> _deleteTemporaryFile(File file, String path) async {
    if (!path.contains('/tmp/')) return;

    try {
      if (await file.exists()) {
        await file.delete();
        debugPrint('임시 파일 삭제: $path');
      }
    } catch (e) {
      debugPrint('임시 파일 삭제 실패: $e');
    }
  }

  // 비디오 출처 확인 헬퍼 메서드
  bool get isVideoFromCamera => widget.isVideo == true && widget.isFromCamera;
  bool get isVideoFromGallery => widget.isVideo == true && !widget.isFromCamera;

  Future<void> _uploadThenNavigate(List<String> categoryIds) async {
    if (!mounted) return;
    LoadingPopupWidget.show(
      context,
      message: '${categoryIds.length}개 카테고리에 미디어를 업로드하고 있습니다.\n잠시만 기다려주세요',
    );
    try {
      _clearImageCache();
      await _audioController.stopAudio();
      await _audioController.stopRealtimeAudio();
      _audioController.clearCurrentRecording();
      await Future.delayed(const Duration(milliseconds: 500));

      // 선택된 모든 카테고리에 업로드
      for (int i = 0; i < categoryIds.length; i++) {
        final categoryId = categoryIds[i];
        final uploadData = _extractUploadData(categoryId);
        if (uploadData == null) continue;

        // 마지막 업로드가 아니면 await로 순차 진행
        if (i == categoryIds.length - 1) {
          unawaited(_executeUploadWithExtractedData(uploadData));
        } else {
          _executeUploadWithExtractedData(uploadData);
        }
      }

      _clearImageCache();
      if (!mounted) return;
      LoadingPopupWidget.hide(context);
      if (!mounted) return;
      _navigateToHome();
    } catch (e) {
      _clearImageCache();
      if (!mounted) return;
      LoadingPopupWidget.hide(context);
      if (!mounted) return;
      _navigateToHome();
    }
  }

  Map<String, dynamic>? _extractUploadData(String categoryId) {
    final filePath = widget.filePath;
    final userId = _authController.getUserId;

    if (filePath == null || userId == null) return null;

    final isVideo = widget.isVideo ?? false;

    return {
      'categoryId': categoryId,
      'filePath': filePath,
      'userId': userId,
      'isVideo': isVideo,
      'audioPath': isVideo
          ? null
          : _recordedAudioPath ?? _audioController.currentRecordingPath,
      'waveformData': isVideo ? null : _recordedWaveformData,
      'caption': _captionController.text.trim().isNotEmpty
          ? _captionController.text.trim()
          : null,
    };
  }

  Future<void> _executeUploadWithExtractedData(
    Map<String, dynamic> data,
  ) async {
    final categoryId = data['categoryId'] as String;
    final filePath = data['filePath'] as String;
    final userId = data['userId'] as String;
    final audioPath = data['audioPath'] as String?;
    final waveformData = data['waveformData'] as List<double>? ?? const [];
    final isVideo = data['isVideo'] as bool? ?? false;
    final mediaFile = File(filePath);

    if (!await mediaFile.exists()) {
      throw Exception('미디어 파일을 찾을 수 없습니다: $filePath');
    }

    File? audioFile;
    if (!isVideo && audioPath != null && audioPath.isNotEmpty) {
      audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        audioFile = null;
      }
    }

    try {
      if (isVideo) {
        // 비디오 길이 자동 추출
        Duration? videoDuration;
        try {
          videoDuration = await VideoThumbnailGenerator.getVideoDuration(
            filePath,
          );
        } catch (e) {
          debugPrint('비디오 길이 추출 실패: $e');
        }

        // 비디오 썸네일 자동 생성
        File? thumbnailFile;
        try {
          thumbnailFile = await VideoThumbnailGenerator.generateThumbnail(
            filePath,
            quality: 85, // 비디오 썸네일 화질 설정
            maxWidth: 1920, // 비디오 썸네일 최대 너비
            maxHeight: 1080, // 비디오 썸네일 최대 높이
          );
          if (thumbnailFile == null) {
            debugPrint('썸네일 생성 실패 - 비디오 URL을 썸네일로 사용');
          }
        } catch (e) {
          debugPrint('썸네일 생성 오류: $e');
        }

        await _photoController.uploadVideo(
          videoFile: mediaFile,
          thumbnailFile: thumbnailFile,
          categoryId: categoryId,
          userId: userId,
          userIds: [userId],
          duration: videoDuration,
          caption: data['caption'] as String?,
          isFromCamera: widget.isFromCamera,
        );

        // 업로드 후 썸네일 임시 파일 삭제
        if (thumbnailFile != null) {
          try {
            await thumbnailFile.delete();
          } catch (e) {
            debugPrint('썸네일 임시 파일 삭제 실패: $e');
          }
        }
      } else if (audioFile != null && waveformData.isNotEmpty) {
        await _photoController.uploadPhotoWithAudio(
          imageFilePath: mediaFile.path,
          audioFilePath: audioFile.path,
          userID: userId,
          userIds: [userId],
          categoryId: categoryId,
          waveformData: waveformData,
          duration: Duration(seconds: _audioController.recordingDuration),
        );
      } else {
        await _photoController.uploadPhoto(
          imageFile: mediaFile,
          categoryId: categoryId,
          userId: userId,
          userIds: [userId],
          audioFile: null,
          caption: data['caption'] as String?,
        );
      }

      // 업로드 성공 후 임시 파일 삭제
      await _deleteTemporaryFile(mediaFile, filePath);
      if (audioFile != null && audioPath != null) {
        await _deleteTemporaryFile(audioFile, audioPath);
      }
    } catch (e) {
      debugPrint('업로드 실패: $e');
      rethrow;
    }
  }

  void _navigateToHome() {
    if (!mounted || _isDisposing) return;

    _audioController.stopAudio();
    _audioController.clearCurrentRecording();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomePageNavigationBar(currentPageIndex: 2),
        settings: RouteSettings(name: '/home_navigation_screen'),
      ),
      (route) => false,
    );

    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SOI',
              style: TextStyle(
                color: Color(0xfff9f9f9),
                fontSize: 20.sp,
                fontFamily: GoogleFonts.inter().fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30.h),
          ],
        ),
        toolbarHeight: 70.h,
        backgroundColor: Colors.black,
      ),
      body: _isLoading && !_showImmediatePreview
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : Stack(
              children: [
                // 사진 영역 (스크롤 가능)
                Positioned.fill(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PhotoDisplayWidget(
                          filePath: widget.filePath,
                          useLocalImage: _useLocalImage,
                          width: 354.w,
                          height: 500.h,
                          isVideo: widget.isVideo ?? false,
                          initialImage: _initialImageProvider,
                          onCancel: _resetBottomSheetIfNeeded,
                          isFromCamera: widget.isFromCamera,
                        ),
                      ],
                    ),
                  ),
                ),
                // 텍스트 필드 영역 (고정, 키보드에 따라 올라감)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: isKeyboardVisible
                      ? 10.h
                      : MediaQuery.of(context).size.height *
                            _kLockedSheetExtent,

                  child: SizedBox(child: _buildCaptionInputBar()),
                ),
              ],
            ),
      bottomSheet: (shouldHideBottomSheet)
          ? null
          : NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                // 🎯 카테고리가 선택된 상태에서는 바텀시트가 너무 내려가지 않도록 방지
                if (_selectedCategoryIds.isNotEmpty) {
                  // 바텀시트가 locked 위치 아래로 내려가려고 하면 방지
                  if (notification.extent < _kLockedSheetExtent - 0.02) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          !_isDisposing &&
                          _draggableScrollController.isAttached) {
                        _draggableScrollController.jumpTo(_kLockedSheetExtent);
                      }
                    });
                  }
                  return true;
                }

                // 카테고리 선택 없을 때는 기존 로직
                if (!_hasLockedSheetExtent && notification.extent < 0.01) {
                  if (mounted && !_isDisposing && !_hasLockedSheetExtent) {
                    _animateSheetTo(_kLockedSheetExtent, lockExtent: true);
                  }
                }
                return true;
              },
              child: DraggableScrollableSheet(
                controller: _draggableScrollController,
                initialChildSize: _initialChildSize,
                minChildSize: _minChildSize,
                maxChildSize: _kMaxSheetExtent,
                expand: false,
                builder: (context, scrollController) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final maxHeight = constraints.maxHeight;
                      final handleHeight = _showAddCategoryUI ? 12.h : 25.h;
                      final spacing = maxHeight > handleHeight ? 4.h : 0.0;
                      final contentHeight = math.max(
                        0.0,
                        maxHeight - handleHeight - spacing,
                      );

                      return Container(
                        decoration: BoxDecoration(
                          color: Color(0xff171717),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              SizedBox(
                                height: handleHeight,
                                child: _showAddCategoryUI
                                    ? SizedBox()
                                    : Center(
                                        child: Container(
                                          height: 3.h,
                                          width: 56.w,
                                          margin: EdgeInsets.symmetric(
                                            vertical: 11.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(0xffcdcdcd),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              SizedBox(height: spacing),
                              SizedBox(
                                height: contentHeight,
                                child: AnimatedSwitcher(
                                  duration: Duration(milliseconds: 300),
                                  child: _showAddCategoryUI
                                      ? ClipRect(
                                          child: LayoutBuilder(
                                            builder: (context, addConstraints) {
                                              return ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxHeight:
                                                      addConstraints.maxHeight,
                                                  maxWidth:
                                                      addConstraints.maxWidth,
                                                ),
                                                child: AddCategoryWidget(
                                                  textController:
                                                      _categoryNameController,
                                                  scrollController:
                                                      scrollController,
                                                  focusNode: _categoryFocusNode,
                                                  onBackPressed: () {
                                                    setState(() {
                                                      _showAddCategoryUI =
                                                          false;
                                                      _categoryNameController
                                                          .clear();
                                                    });
                                                    _animateSheetTo(
                                                      _kLockedSheetExtent,
                                                    );
                                                  },
                                                  onSavePressed:
                                                      (selectedFriends) =>
                                                          _createNewCategory(
                                                            selectedFriends,
                                                          ),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : CategoryListWidget(
                                          scrollController: scrollController,
                                          selectedCategoryIds:
                                              _selectedCategoryIds,
                                          onCategorySelected:
                                              _handleCategorySelection,
                                          onConfirmSelection: () {
                                            if (_selectedCategoryIds
                                                .isNotEmpty) {
                                              // 선택된 모든 카테고리에 업로드
                                              _uploadThenNavigate(
                                                _selectedCategoryIds,
                                              );
                                            }
                                          },
                                          addCategoryPressed: () {
                                            setState(
                                              () => _showAddCategoryUI = true,
                                            );
                                            _animateSheetTo(0.65);
                                          },
                                          isLoading:
                                              _categoryController.isLoading,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  // ========== 리소스 정리 메서드 ==========
  void _clearImageCache() {
    if (widget.filePath != null) {
      PaintingBinding.instance.imageCache.evict(
        FileImage(File(widget.filePath!)),
      );
    }
    if (widget.downloadUrl != null) {
      PaintingBinding.instance.imageCache.evict(
        NetworkImage(widget.downloadUrl!),
      );
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  void dispose() {
    _isDisposing = true;
    _audioController.stopAudio();
    _audioController.stopRealtimeAudio();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _audioController.clearCurrentRecording();
    });
    _recordedWaveformData = null;
    _recordedAudioPath = null;

    _clearImageCache();

    _categoryNameController.dispose();
    _captionController.removeListener(_handleCaptionChanged);
    _captionController.dispose();
    _captionFocusNode.dispose();
    _categoryFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(0.0);
    }
    _draggableScrollController.dispose();
    super.dispose();
  }
}
