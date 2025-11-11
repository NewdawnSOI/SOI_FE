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
  final bool? isVideo;
  final ImageProvider? initialImage;
  const PhotoEditorScreen({
    super.key,
    this.downloadUrl,
    this.filePath,
    this.isVideo,
    this.initialImage,
  });
  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen>
    with WidgetsBindingObserver {
  // ========== 상태 관리 변수들 ==========
  bool _isLoading = true;
  bool _showImmediatePreview = false;
  String? _errorMessage;
  bool _useLocalImage = false;
  ImageProvider? _initialImageProvider;
  bool _showAddCategoryUI = false;
  //String? _selectedCategoryId;
  final List<String> _selectedCategoryIds = [];
  bool _categoriesLoaded = false;
  bool _shouldAutoOpenCategorySheet = true;
  bool _isDisposing = false;
  static const double _kInitialSheetExtent = 0.0;
  static const double _kLockedSheetExtent = 0.19;
  static const double _kExpandedSheetExtent = 0.29; // 카테고리 선택 시 확장된 높이
  static const double _kMaxSheetExtent = 0.8;
  double _minChildSize = _kInitialSheetExtent;
  double _initialChildSize = _kInitialSheetExtent;
  bool _hasLockedSheetExtent = false;

  // 오디오 관련 변수들
  List<double>? _recordedWaveformData;
  String? _recordedAudioPath;
  bool _isCaptionEmpty = true;

  // 음성 녹음 UI 표시 여부
  bool _showAudioRecorder = false;

  // 키보드 높이
  double get keyboardHeight => MediaQuery.of(context).viewInsets.bottom;
  bool get isKeyboardVisible => keyboardHeight > 0;

  // 바텀시트를 숨겨야 하는지 판단 (caption 입력 중이고 카테고리 추가 화면이 아닐 때)
  bool get shouldHideBottomSheet => isKeyboardVisible && !_showAddCategoryUI;

  // 컨트롤러들
  final _draggableScrollController = DraggableScrollableController();
  final _categoryNameController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  late AudioController _audioController;
  late CategoryController _categoryController;
  late AuthController _authController;
  late PhotoController _photoController;

  final FocusNode _captionFocusNode = FocusNode();
  final FocusNode _categoryFocusNode = FocusNode();

  // ========== 생명주기 메서드들 ==========
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
    if (!_showImmediatePreview) {
      _loadImage();
    }
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
    if (localPath == null || localPath.isEmpty) {
      return;
    }

    final file = File(localPath);
    if (!file.existsSync()) {
      return;
    }

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
    if (isEmpty == _isCaptionEmpty) {
      return;
    }
    if (!mounted) {
      _isCaptionEmpty = isEmpty;
      return;
    }
    setState(() => _isCaptionEmpty = isEmpty);
  }

  void _loadCategoriesIfNeeded() {
    if (!_categoriesLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserCategories();
      });
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

    if (_showImmediatePreview && widget.initialImage != null) {
      _isLoading = false;
      if (mounted) setState(() {});
      return;
    }

    final primedLocalPath = widget.filePath;
    if (_showImmediatePreview &&
        primedLocalPath != null &&
        primedLocalPath.isNotEmpty) {
      final primedFile = File(primedLocalPath);
      if (primedFile.existsSync()) {
        _isLoading = false;
        if (mounted) setState(() {});
        return;
      }
    }

    _showImmediatePreview = false;

    final localPath = widget.filePath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);

      if (file.existsSync()) {
        _useLocalImage = true;
        _showImmediatePreview = true;
        _isLoading = false;
        if (mounted) setState(() {});
        return;
      }

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
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = "이미지 로딩 중 오류 발생: $e";
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _errorMessage = '이미지 파일을 찾을 수 없습니다.';
          _isLoading = false;
        });
      }
      return;
    }

    if (widget.downloadUrl != null && widget.downloadUrl!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      } else {
        _isLoading = false;
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadUserCategories({bool forceReload = false}) async {
    if (!forceReload && _categoriesLoaded) return;
    if (!forceReload) {
      setState(() {
        _isLoading = false;
      });
    }
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
    try {
      await _categoryController.loadUserCategories(
        currentUser.uid,
        forceReload: forceReload,
      );
      _categoriesLoaded = true;
      if (_shouldAutoOpenCategorySheet) {
        _shouldAutoOpenCategorySheet = false;
        _animateSheetTo(_kLockedSheetExtent, lockExtent: true);
      }
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
    // 이전 선택 상태 저장
    final wasEmpty = _selectedCategoryIds.isEmpty;

    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });

    // 카테고리 선택 상태에 따라 바텀시트 높이 조정
    if (_selectedCategoryIds.isEmpty) {
      // 모든 선택 해제 시 → 원래 위치로
      _animateSheetTo(_kLockedSheetExtent);
    } else if (wasEmpty) {
      // 처음 선택 시에만 → 확장
      _animateSheetTo(_kExpandedSheetExtent);
    }
    // 이미 선택된 상태에서 추가 선택/해제 시 → 높이 유지 (아무것도 하지 않음)
  }

  void _animateSheetTo(double size, {bool lockExtent = false}) {
    if (!mounted || _isDisposing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isDisposing) return;
      if (_draggableScrollController.isAttached) {
        await _draggableScrollController.animateTo(
          size,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      if (lockExtent) {
        _lockSheetExtent(size);
      }
    });
  }

  void _lockSheetExtent(double size) {
    if (!mounted || _isDisposing || _hasLockedSheetExtent) return;
    setState(() {
      _minChildSize = size;
      _initialChildSize = size;
      _hasLockedSheetExtent = true;
    });
    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(size);
    }
  }

  Future<void> _resetBottomSheetIfNeeded() async {
    if (_isDisposing || !_draggableScrollController.isAttached) {
      return;
    }
    final double targetSize = _hasLockedSheetExtent
        ? _kLockedSheetExtent
        : _initialChildSize;
    final double currentSize = _draggableScrollController.size;
    const double tolerance = 0.001;
    if ((currentSize - targetSize).abs() <= tolerance) {
      return;
    }
    await _draggableScrollController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _handleMicTap() {
    setState(() {
      _showAudioRecorder = true;
    });
    _captionFocusNode.unfocus(); // 키보드 숨김
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
      final String? userId = _authController.getUserId;
      if (userId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인이 필요합니다. 다시 로그인해주세요.')));
        return;
      }
      List<String> mates = [userId];
      for (final friend in selectedFriends) {
        if (!mates.contains(friend.uid)) {
          mates.add(friend.uid);
        }
      }
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
  Future<void> _uploadThenNavigate(List<String> categoryIds) async {
    if (!mounted) return;
    LoadingPopupWidget.show(
      context,
      message: '${categoryIds.length}개 카테고리에 사진을 업로드하고 있습니다.\n잠시만 기다려주세요',
    );
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
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

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (!mounted) return;
      LoadingPopupWidget.hide(context);
      if (!mounted) return;
      _navigateToHome();
    } catch (e) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!mounted) return;
      LoadingPopupWidget.hide(context);
      if (!mounted) return;
      _navigateToHome();
    }
  }

  Map<String, dynamic>? _extractUploadData(String categoryId) {
    final filePath = widget.filePath;
    final userId = _authController.getUserId;
    final audioPath =
        _recordedAudioPath ?? _audioController.currentRecordingPath;
    final waveformData = _recordedWaveformData;
    if (filePath == null || userId == null) return null;
    return {
      'categoryId': categoryId,
      'filePath': filePath,
      'userId': userId,
      'audioPath': audioPath,
      'waveformData': waveformData,
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
    final imageFile = File(filePath);

    if (!await imageFile.exists()) {
      throw Exception('이미지 파일을 찾을 수 없습니다: $filePath');
    }

    File? audioFile;
    if (audioPath != null && audioPath.isNotEmpty) {
      audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        audioFile = null;
      }
    }

    try {
      if (audioFile != null && waveformData.isNotEmpty) {
        await _photoController.uploadPhotoWithAudio(
          imageFilePath: imageFile.path,
          audioFilePath: audioFile.path,
          userID: userId,
          userIds: [userId],
          categoryId: categoryId,
          waveformData: waveformData,
          duration: Duration(seconds: _audioController.recordingDuration),
        );
      } else {
        await _photoController.uploadPhoto(
          imageFile: imageFile,
          categoryId: categoryId,
          userId: userId,
          userIds: [userId],
          audioFile: null,
          caption: data['caption'] as String?,
        );
      }

      // 업로드 성공 후 임시 파일 삭제
      if (filePath.contains('/tmp/')) {
        try {
          if (await imageFile.exists()) {
            await imageFile.delete();
            debugPrint('업로드 완료 후 임시 파일 삭제: $filePath');
          }
        } catch (e) {
          debugPrint('임시 파일 삭제 실패: $e');
        }
      }

      // 오디오 파일도 삭제
      if (audioFile != null && audioPath!.contains('/tmp/')) {
        try {
          if (await audioFile.exists()) {
            await audioFile.delete();
            debugPrint('업로드 완료 후 임시 오디오 파일 삭제: $audioPath');
          }
        } catch (e) {
          debugPrint('임시 오디오 파일 삭제 실패: $e');
        }
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
                      final double maxHeight = constraints.maxHeight;
                      final double desiredHandleHeight = _showAddCategoryUI
                          ? 12.h
                          : (3.h + 10.h + 12.h);
                      final double effectiveHandleHeight = math.min(
                        maxHeight,
                        desiredHandleHeight,
                      );
                      final double desiredSpacing = 4.h;
                      final double effectiveSpacing =
                          maxHeight > effectiveHandleHeight
                          ? desiredSpacing
                          : 0.0;
                      final double contentHeight = math.max(
                        0.0,
                        maxHeight - effectiveHandleHeight - effectiveSpacing,
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
                                height: effectiveHandleHeight,
                                child: _showAddCategoryUI
                                    ? Center(
                                        child: Container(
                                          margin: EdgeInsets.only(bottom: 12.h),
                                        ),
                                      )
                                    : Center(
                                        child: Container(
                                          height: math.min(
                                            3.h,
                                            effectiveHandleHeight,
                                          ),
                                          width: 56.w,
                                          margin: EdgeInsets.only(
                                            top: math.min(
                                              10.h,
                                              effectiveHandleHeight / 2,
                                            ),
                                            bottom: math.min(
                                              12.h,
                                              effectiveHandleHeight / 2,
                                            ),
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
                              SizedBox(height: effectiveSpacing),
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

    // 이미지 캐시 제거
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
