import 'dart:io';

import '../../../api/controller/category_controller.dart';
import '../models/add_category_draft.dart';
import 'photo_editor_upload_service.dart';

class PhotoEditorCategoryLoadResult {
  const PhotoEditorCategoryLoadResult({
    required this.didLoad,
    this.errorMessageKey,
    this.errorMessageArgs,
  });

  final bool didLoad;
  final String? errorMessageKey;
  final Map<String, String>? errorMessageArgs;
}

enum PhotoEditorCategoryCreationStatus {
  success,
  createFailed,
  coverUpdateFailed,
  unexpectedError,
}

class PhotoEditorCategoryCreationResult {
  const PhotoEditorCategoryCreationResult({
    required this.status,
    this.errorMessage,
  });

  final PhotoEditorCategoryCreationStatus status;
  final String? errorMessage;
}

class PhotoEditorCategoryFlowService {
  const PhotoEditorCategoryFlowService({
    required CategoryController categoryController,
    required PhotoEditorUploadService uploadService,
  }) : _categoryController = categoryController,
       _uploadService = uploadService;

  final CategoryController _categoryController;
  final PhotoEditorUploadService _uploadService;

  Future<PhotoEditorCategoryLoadResult> loadUserCategories({
    required int? currentUserId,
    bool forceReload = false,
  }) async {
    if (currentUserId == null) {
      return const PhotoEditorCategoryLoadResult(
        didLoad: false,
        errorMessageKey: 'common.login_required',
      );
    }

    try {
      await _categoryController.loadCategories(
        currentUserId,
        forceReload: forceReload,
      );
      return const PhotoEditorCategoryLoadResult(didLoad: true);
    } catch (e) {
      return PhotoEditorCategoryLoadResult(
        didLoad: false,
        errorMessageKey: 'camera.editor.category_load_error_with_reason',
        errorMessageArgs: {'error': e.toString()},
      );
    }
  }

  Future<PhotoEditorCategoryCreationResult> createCategory(
    AddCategoryDraft draft,
  ) async {
    try {
      final receiverIds = buildCategoryReceiverIds(draft);
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
        return PhotoEditorCategoryCreationResult(
          status: PhotoEditorCategoryCreationStatus.createFailed,
          errorMessage: _categoryController.errorMessage,
        );
      }

      var shouldWarnCoverUpdateFailure = false;
      if (selectedCover != null) {
        final didUpdateCover = await _updateCreatedCategoryCover(
          selectedCover: selectedCover,
          requesterId: draft.requesterId,
          createdCategoryId: createdCategoryId,
          uploadResult: uploadResult,
        );
        shouldWarnCoverUpdateFailure = !didUpdateCover;
      }

      await _reloadCategoriesAfterCategoryCreation(draft.requesterId);
      if (shouldWarnCoverUpdateFailure) {
        return PhotoEditorCategoryCreationResult(
          status: PhotoEditorCategoryCreationStatus.coverUpdateFailed,
          errorMessage: _categoryController.errorMessage,
        );
      }

      return const PhotoEditorCategoryCreationResult(
        status: PhotoEditorCategoryCreationStatus.success,
      );
    } catch (_) {
      return const PhotoEditorCategoryCreationResult(
        status: PhotoEditorCategoryCreationStatus.unexpectedError,
      );
    }
  }

  static List<int> buildCategoryReceiverIds(AddCategoryDraft draft) {
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
    } catch (_) {
      // 생성 자체는 성공했으므로 로드 실패는 종료를 막지 않습니다.
    }
  }
}

class _BackgroundCoverUploadResult {
  const _BackgroundCoverUploadResult({this.keys = const []});

  final List<String> keys;

  String? get firstKey => keys.isNotEmpty ? keys.first : null;
}
