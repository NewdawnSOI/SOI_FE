part of '../photo_editor_screen.dart';

extension _PhotoEditorScreenCategoryFlowExtension on _PhotoEditorScreenState {
  Future<void> _loadUserCategories({bool forceReload = false}) async {
    if (!forceReload && _categoriesLoaded) return;

    final currentUser = _userController.currentUser;
    if (currentUser == null) {
      _safeSetState(() {
        _errorMessageKey = 'common.login_required';
        _errorMessageArgs = null;
        _isLoading = false;
      });
      return;
    }

    if (_shouldAutoOpenCategorySheet) {
      _shouldAutoOpenCategorySheet = false;
      _animateSheetTo(
        _PhotoEditorScreenState._kLockedSheetExtent,
        lockExtent: true,
      );
    }

    try {
      await _categoryController.loadCategories(
        currentUser.id,
        forceReload: forceReload,
      );
      _categoriesLoaded = true;
      _safeSetState(() {});
    } catch (e) {
      _safeSetState(() {
        _errorMessageKey = 'camera.editor.category_load_error_with_reason';
        _errorMessageArgs = {'error': e.toString()};
      });
    }
  }

  void _handleCategorySelection(int categoryId) {
    _safeSetState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });

    if (_selectedCategoryIds.isEmpty) {
      _animateSheetTo(_PhotoEditorScreenState._kLockedSheetExtent);
    } else {
      _animateSheetToIfNeeded(_PhotoEditorScreenState._kExpandedSheetExtent);
    }
  }

  Future<void> _openAddCategoryScreen() async {
    final draft = await Navigator.push<AddCategoryDraft>(
      context,
      MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
    );

    if (draft == null || !mounted || _isDisposing) return;
    unawaited(_runAddCategoryInBackground(draft));
  }

  Future<void> _runAddCategoryInBackground(AddCategoryDraft draft) async {
    if (_isDisposing) return;
    _showErrorSnackBar(tr('common.please_wait', context: context));

    try {
      final receiverIds = _buildCategoryReceiverIds(draft);
      final isPublicCategory = draft.selectedFriends.isNotEmpty;
      final selectedCover = draft.selectedCoverImageFile;

      final createCategoryFuture = _categoryController.createCategory(
        requesterId: draft.requesterId,
        name: draft.categoryName,
        receiverIds: receiverIds,
        isPublic: isPublicCategory,
      );
      final uploadFuture = _createCoverUploadFuture(
        selectedCover: selectedCover,
        requesterId: draft.requesterId,
      );

      final parallelResults = await Future.wait<dynamic>([
        createCategoryFuture,
        uploadFuture,
      ]);

      final createdCategoryId = parallelResults[0] as int?;
      final uploadResult = parallelResults[1] as _BackgroundCoverUploadResult;

      if (createdCategoryId == null) {
        if (!mounted) return;
        final message =
            _categoryController.errorMessage ??
            tr('camera.editor.category_create_failed_retry', context: context);
        _showErrorSnackBar(message);
        return;
      }

      var shouldWarnCoverUpdateFailure = false;
      if (selectedCover != null) {
        shouldWarnCoverUpdateFailure = !await _updateCreatedCategoryCover(
          selectedCover: selectedCover,
          requesterId: draft.requesterId,
          createdCategoryId: createdCategoryId,
          uploadResult: uploadResult,
        );
      }

      await _reloadCategoriesAfterCategoryCreation(draft.requesterId);
      if (!mounted) return;

      if (shouldWarnCoverUpdateFailure) {
        final warningMessage =
            _categoryController.errorMessage ??
            tr('category.cover.update_failed', context: context);
        _showErrorSnackBar(warningMessage);
        return;
      }

      _showErrorSnackBar(
        tr('archive.create_category_success', context: context),
      );
    } catch (_) {
      if (!mounted) return;
      _showErrorSnackBar(
        tr('camera.editor.category_create_error', context: context),
      );
    }
  }

  void _animateSheetToIfNeeded(double targetSize) {
    if (!mounted || _isDisposing) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposing) return;
      if (!_draggableScrollController.isAttached) return;

      final currentExtent = _draggableScrollController.size;
      if (currentExtent >= targetSize - 0.02) return;

      _animateSheetTo(targetSize);
    });
  }

  void _animateSheetTo(
    double size, {
    bool lockExtent = false,
    int retryCount = 0,
  }) {
    if (!mounted || _isDisposing) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isDisposing) return;

      if (!_draggableScrollController.isAttached) {
        if (retryCount < 50) {
          await Future.delayed(const Duration(milliseconds: 10));
          _animateSheetTo(
            size,
            lockExtent: lockExtent,
            retryCount: retryCount + 1,
          );
        } else {
          debugPrint('DraggableScrollableController attach 실패 (최대 재시도 횟수 초과)');
        }
        return;
      }

      _isAnimatingSheet = true;

      try {
        await _draggableScrollController.animateTo(
          size,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );

        if (lockExtent && !_hasLockedSheetExtent && mounted) {
          _safeSetState(() {
            _minChildSize = size;
            _initialChildSize = size;
            _hasLockedSheetExtent = true;
          });
        }
      } finally {
        _isAnimatingSheet = false;
      }
    });
  }

  Future<void> _resetBottomSheetIfNeeded() async {
    if (_isDisposing || !_draggableScrollController.isAttached) return;

    final targetSize = _hasLockedSheetExtent
        ? _PhotoEditorScreenState._kLockedSheetExtent
        : _initialChildSize;
    final currentSize = _draggableScrollController.size;
    if ((currentSize - targetSize).abs() <= 0.001) return;

    await _draggableScrollController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  List<int> _buildCategoryReceiverIds(AddCategoryDraft draft) {
    if (draft.selectedFriends.isEmpty) {
      return const [];
    }

    final receiverIds = <int>[draft.requesterId];
    for (final friend in draft.selectedFriends) {
      final parsedId = int.tryParse(friend.uid);
      if (parsedId != null && !receiverIds.contains(parsedId)) {
        receiverIds.add(parsedId);
      }
    }
    return receiverIds;
  }

  Future<_BackgroundCoverUploadResult> _createCoverUploadFuture({
    required File? selectedCover,
    required int requesterId,
  }) {
    if (selectedCover == null) {
      return Future.value(const _BackgroundCoverUploadResult());
    }

    return _uploadService
        .uploadCategoryCoverImage(
          imageFile: selectedCover,
          userId: requesterId,
          refId: requesterId,
        )
        .then((keys) => _BackgroundCoverUploadResult(keys: keys))
        .catchError((_) => const _BackgroundCoverUploadResult());
  }

  Future<bool> _updateCreatedCategoryCover({
    required File selectedCover,
    required int requesterId,
    required int createdCategoryId,
    required _BackgroundCoverUploadResult uploadResult,
  }) async {
    var profileImageKey = uploadResult.firstKey;

    if (profileImageKey == null) {
      final retryKeys = await _uploadService.uploadCategoryCoverImage(
        imageFile: selectedCover,
        userId: requesterId,
        refId: createdCategoryId,
      );
      if (retryKeys.isNotEmpty) {
        profileImageKey = retryKeys.first;
      }
    }

    if (profileImageKey == null) {
      return false;
    }

    return _categoryController.updateCustomProfile(
      categoryId: createdCategoryId,
      profileImageKey: profileImageKey,
    );
  }

  Future<void> _reloadCategoriesAfterCategoryCreation(int requesterId) async {
    try {
      await _categoryController.loadCategories(
        requesterId,
        forceReload: true,
        fetchAllPages: true,
        maxPages: 2,
      );
      _categoriesLoaded = true;
      _safeSetState(() {});
    } catch (_) {
      // 생성 자체는 성공했으므로 로드 실패는 종료를 막지 않습니다.
    }
  }
}

class _BackgroundCoverUploadResult {
  final List<String> keys;

  const _BackgroundCoverUploadResult({this.keys = const []});

  String? get firstKey => keys.isNotEmpty ? keys.first : null;
}
