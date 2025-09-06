import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../repositories/category_repository.dart';
import '../models/category_data_model.dart';
import '../models/auth_result.dart';
import 'notification_service.dart';
import 'photo_service.dart';

/// 비즈니스 로직을 처리하는 Service
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class CategoryService {
  // Singleton pattern
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  final CategoryRepository _repository = CategoryRepository();

  // Lazy initialization으로 순환 의존성 방지
  NotificationService? _notificationService;
  NotificationService get notificationService {
    _notificationService ??= NotificationService();
    return _notificationService!;
  }

  PhotoService? _photoService;
  PhotoService get photoService {
    _photoService ??= PhotoService();
    return _photoService!;
  }

  // ==================== 비즈니스 로직 ====================

  /// 카테고리 이름 검증
  String? _validateCategoryName(String name) {
    if (name.trim().isEmpty) {
      return '카테고리 이름을 입력해주세요.';
    }

    if (name.trim().length > 20) {
      return '카테고리 이름은 20글자 이하여야 합니다.';
    }
    return null;
  }

  /// 카테고리 이름 정규화
  String _normalizeCategoryName(String name) {
    return name.trim();
  }

  // ==================== 카테고리 관리 ====================

  /// 사용자의 카테고리 목록을 스트림으로 가져오기
  Stream<List<CategoryDataModel>> getUserCategoriesStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }
    return _repository.getUserCategoriesStream(userId);
  }

  /// 단일 카테고리 실시간 스트림
  Stream<CategoryDataModel?> getCategoryStream(String categoryId) {
    if (categoryId.isEmpty) {
      return Stream.value(null);
    }
    return _repository.getCategoryStream(categoryId);
  }

  /// 사용자의 카테고리 목록을 한 번만 가져오기
  Future<List<CategoryDataModel>> getUserCategories(String userId) async {
    if (userId.isEmpty) {
      // // debugPrint('CategoryService: userId가 비어있습니다.');
      return [];
    }

    try {
      final categories = await _repository.getUserCategories(userId);

      return categories;
    } catch (e) {
      // // debugPrint('카테고리 목록 조회 오류: $e');
      return [];
    }
  }

  /// 카테고리 생성
  Future<AuthResult> createCategory({
    required String name,
    required List<String> mates,
  }) async {
    try {
      // 1. 카테고리 이름 검증
      final validationError = _validateCategoryName(name);
      if (validationError != null) {
        return AuthResult.failure(validationError);
      }

      // 2. 메이트 검증
      if (mates.isEmpty) {
        return AuthResult.failure('최소 1명의 멤버가 필요합니다.');
      }

      // 3. 카테고리 이름 정규화
      final normalizedName = _normalizeCategoryName(name);

      // 4. 카테고리 생성
      final category = CategoryDataModel(
        id: '', // Repository에서 생성됨
        name: normalizedName,
        mates: mates,
        createdAt: DateTime.now(),
      );

      final categoryId = await _repository.createCategory(category);

      // 5. 카테고리 초대 알림 생성 (카테고리 생성자가 액터)
      try {
        // 첫 번째 메이트를 생성자로 간주
        final creatorUserId = mates.first;
        await notificationService.createCategoryInviteNotification(
          categoryId: categoryId,
          actorUserId: creatorUserId,
          recipientUserIds: mates,
        );
        debugPrint('🔔 카테고리 초대 알림 생성 완료 - 카테고리: $categoryId');
      } catch (e) {
        // 알림 생성 실패는 전체 카테고리 생성을 실패시키지 않음
        debugPrint('⚠️ 알림 생성 실패 (카테고리 생성은 성공): $e');
      }

      return AuthResult.success(categoryId);
    } catch (e) {
      // // debugPrint('카테고리 생성 오류: $e');
      return AuthResult.failure('카테고리 생성 중 오류가 발생했습니다.');
    }
  }

  /// 사용자별 카테고리 커스텀 이름 업데이트
  Future<AuthResult> updateCustomCategoryName({
    required String categoryId,
    required String userId,
    required String customName,
  }) async {
    try {
      // 1. 카테고리 이름 검증
      final validationError = _validateCategoryName(customName);
      if (validationError != null) {
        return AuthResult.failure(validationError);
      }

      // 2. 카테고리 이름 정규화
      final normalizedName = _normalizeCategoryName(customName);

      // 3. customNames 맵 업데이트
      await _repository.updateCustomName(
        categoryId: categoryId,
        userId: userId,
        customName: normalizedName,
      );

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('커스텀 이름 설정 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 수정
  Future<AuthResult> updateCategory({
    required String categoryId,
    String? name,
    List<String>? mates,
    bool? isPinned,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      // 1. 이름 업데이트
      if (name != null) {
        final validationError = _validateCategoryName(name);
        if (validationError != null) {
          return AuthResult.failure(validationError);
        }
        updateData['name'] = _normalizeCategoryName(name);
      }

      // 2. 멤버 업데이트
      if (mates != null) {
        if (mates.isEmpty) {
          return AuthResult.failure('최소 1명의 멤버가 필요합니다.');
        }
        updateData['mates'] = mates;
      }

      // 3. 고정 상태 업데이트
      if (isPinned != null) {
        updateData['isPinned'] = isPinned;
      }

      if (updateData.isEmpty) {
        return AuthResult.failure('업데이트할 내용이 없습니다.');
      }

      await _repository.updateCategory(categoryId, updateData);
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('카테고리 수정 중 오류가 발생했습니다.');
    }
  }

  /// 사용자별 카테고리 고정 상태 업데이트
  Future<AuthResult> updateUserPinStatus({
    required String categoryId,
    required String userId,
    required bool isPinned,
  }) async {
    try {
      if (categoryId.isEmpty || userId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리 또는 사용자입니다.');
      }

      await _repository.updateUserPinStatus(
        categoryId: categoryId,
        userId: userId,
        isPinned: isPinned,
      );

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('고정 상태 업데이트 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 삭제
  Future<AuthResult> deleteCategory(String categoryId) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      await _repository.deleteCategory(categoryId);
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('카테고리 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 특정 카테고리 정보 가져오기
  Future<CategoryDataModel?> getCategory(String categoryId) async {
    try {
      if (categoryId.isEmpty) return null;

      return await _repository.getCategory(categoryId);
    } catch (e) {
      return null;
    }
  }

  // ==================== 사진 관리 ====================

  /// 카테고리에 사진 추가
  Future<AuthResult> addPhotoToCategory({
    required String categoryId,
    required File imageFile,
    String? description,
  }) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      // 1. 이미지 업로드
      final imageUrl = await _repository.uploadImage(categoryId, imageFile);

      // 2. 사진 데이터 생성
      final photoData = {
        'url': imageUrl,
        'description': description ?? '',
        'createdAt': DateTime.now(),
      };

      // 3. Firestore에 사진 정보 저장
      final photoId = await _repository.addPhotoToCategory(
        categoryId,
        photoData,
      );

      return AuthResult.success(photoId);
    } catch (e) {
      return AuthResult.failure('사진 추가 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리에서 사진 삭제
  Future<AuthResult> removePhotoFromCategory({
    required String categoryId,
    required String photoId,
    required String imageUrl,
  }) async {
    try {
      if (categoryId.isEmpty || photoId.isEmpty) {
        return AuthResult.failure('유효하지 않은 정보입니다.');
      }

      // 1. Storage에서 이미지 삭제
      await _repository.deleteImage(imageUrl);

      // 2. Firestore에서 사진 정보 삭제
      await _repository.removePhotoFromCategory(categoryId, photoId);

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('사진 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리의 사진들 가져오기
  Future<List<Map<String, dynamic>>> getCategoryPhotos(
    String categoryId,
  ) async {
    try {
      if (categoryId.isEmpty) return [];

      return await _repository.getCategoryPhotos(categoryId);
    } catch (e) {
      return [];
    }
  }

  // ==================== 기존 호환성 메서드 ====================

  // ==================== 표지사진 관리 ====================

  /// 갤러리에서 선택한 이미지로 표지사진 업데이트
  Future<AuthResult> updateCoverPhotoFromGallery({
    required String categoryId,
    required File imageFile,
  }) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      // 이미지 업로드
      final photoUrl = await _repository.uploadCoverImage(
        categoryId,
        imageFile,
      );

      // 카테고리 표지사진 업데이트
      await _repository.updateCategoryPhoto(
        categoryId: categoryId,
        photoUrl: photoUrl,
      );

      // 관련 알림들의 썸네일 업데이트
      try {
        await notificationService.updateCategoryThumbnailInNotifications(
          categoryId: categoryId,
          newThumbnailUrl: photoUrl,
        );
      } catch (e) {
        debugPrint('⚠️ 알림 썸네일 업데이트 실패 (표지사진은 성공적으로 업데이트됨): $e');
        // 표지사진 업데이트는 성공했으므로 계속 진행
      }

      return AuthResult.success(photoUrl);
    } catch (e) {
      return AuthResult.failure('표지사진 업데이트 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 내 사진으로 표지사진 업데이트
  Future<AuthResult> updateCoverPhotoFromCategory({
    required String categoryId,
    required String photoUrl,
  }) async {
    try {
      if (categoryId.isEmpty || photoUrl.isEmpty) {
        return AuthResult.failure('유효하지 않은 정보입니다.');
      }

      await _repository.updateCategoryPhoto(
        categoryId: categoryId,
        photoUrl: photoUrl,
      );

      // 관련 알림들의 썸네일 업데이트
      try {
        await notificationService.updateCategoryThumbnailInNotifications(
          categoryId: categoryId,
          newThumbnailUrl: photoUrl,
        );
      } catch (e) {
        debugPrint('⚠️ 알림 썸네일 업데이트 실패 (표지사진은 성공적으로 업데이트됨): $e');
        // 표지사진 업데이트는 성공했으므로 계속 진행
      }

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('표지사진 업데이트 중 오류가 발생했습니다.');
    }
  }

  /// 표지사진 삭제
  Future<AuthResult> deleteCoverPhoto(String categoryId) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      await _repository.deleteCategoryPhoto(categoryId);

      // 관련 알림들의 썸네일을 null로 업데이트 (기본 아이콘 표시)
      try {
        await notificationService.updateCategoryThumbnailInNotifications(
          categoryId: categoryId,
          newThumbnailUrl: '', // 빈 문자열로 설정하여 기본 아이콘 표시
        );
      } catch (e) {
        debugPrint('⚠️ 알림 썸네일 업데이트 실패 (표지사진 삭제는 성공적으로 완료됨): $e');
        // 표지사진 삭제는 성공했으므로 계속 진행
      }

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('표지사진 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 사진 스트림 (Map 형태로 반환)
  Stream<List<Map<String, dynamic>>> getCategoryPhotosStream(
    String categoryId,
  ) {
    return _repository.getCategoryPhotosStream(categoryId);
  }

  // ==================== 유틸리티 ====================

  /// 사용자가 카테고리의 멤버인지 확인
  bool isUserMemberOfCategory(CategoryDataModel category, String userId) {
    return category.mates.contains(userId);
  }

  /// 카테고리에 사용자 추가 (닉네임으로)
  Future<AuthResult> addUserToCategory({
    required String categoryId,
    required String nickName,
  }) async {
    try {
      await _repository.addUserToCategory(
        categoryId: categoryId,
        nickName: nickName,
      );
      return AuthResult.success(null);
    } catch (e) {
      return AuthResult.failure('카테고리에 사용자 추가 실패: $e');
    }
  }

  /// 카테고리에 사용자 추가 (UID로)
  Future<AuthResult> addUidToCategory({
    required String categoryId,
    required String uid,
  }) async {
    try {
      await _repository.addUidToCategory(categoryId: categoryId, uid: uid);
      return AuthResult.success(null);
    } catch (e) {
      return AuthResult.failure('카테고리에 사용자 추가 실패: $e');
    }
  }

  /// 카테고리에서 사용자 제거 (UID로)
  Future<AuthResult> removeUidFromCategory({
    required String categoryId,
    required String uid,
  }) async {
    try {
      // 현재 카테고리 정보 가져오기
      final category = await _repository.getCategory(categoryId);
      if (category == null) {
        return AuthResult.failure('카테고리를 찾을 수 없습니다.');
      }

      // mates 리스트에서 해당 UID 제거
      final updatedMates = List<String>.from(category.mates);
      if (!updatedMates.contains(uid)) {
        return AuthResult.failure('해당 사용자는 이 카테고리의 멤버가 아닙니다.');
      }

      updatedMates.remove(uid);

      // 멤버가 모두 없어지면 카테고리 삭제
      if (updatedMates.isEmpty) {
        await _repository.deleteCategory(categoryId);
        return AuthResult.success('카테고리에서 나갔습니다. 마지막 멤버였으므로 카테고리가 삭제되었습니다.');
      }

      // mates 업데이트
      await _repository.updateCategory(categoryId, {'mates': updatedMates});
      return AuthResult.success('카테고리에서 나갔습니다.');
    } catch (e) {
      return AuthResult.failure('카테고리 나가기 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리에 새 사진 업로드 정보 업데이트
  Future<void> updateLastPhotoInfo({
    required String categoryId,
    required String uploadedBy,
  }) async {
    try {
      final now = Timestamp.now();

      await _repository.updateCategory(categoryId, {
        'lastPhotoUploadedBy': uploadedBy,
        'lastPhotoUploadedAt': now,
      });
    } catch (e) {
      debugPrint('카테고리 최신 사진 정보 업데이트 실패: $e');
    }
  }

  /// 사용자가 카테고리를 확인했음을 기록
  Future<void> updateUserViewTime({
    required String categoryId,
    required String userId,
  }) async {
    try {
      final now = Timestamp.now();

      await _repository.updateCategory(categoryId, {
        'userLastViewedAt.$userId': now,
      });
    } catch (e) {
      debugPrint('사용자 확인 시간 업데이트 실패: $e');
    }
  }

  /// 카테고리 대표사진 삭제 후 최신 사진으로 자동 업데이트
  Future<void> updateCoverPhotoToLatestAfterDeletion(String categoryId) async {
    try {
      if (categoryId.isEmpty) {
        throw ArgumentError('카테고리 ID가 필요합니다.');
      }

      // 카테고리의 최신 사진 조회
      final photos = await photoService.getPhotosByCategory(categoryId);

      if (photos.isNotEmpty) {
        // 최신 사진으로 대표사진 업데이트 (자동 설정)
        await _repository.updateCategoryPhoto(
          categoryId: categoryId,
          photoUrl: photos.first.imageUrl, // 이미 최신순으로 정렬되어 있음
        );

        // 관련 알림들의 썸네일 업데이트
        try {
          await notificationService.updateCategoryThumbnailInNotifications(
            categoryId: categoryId,
            newThumbnailUrl: photos.first.imageUrl,
          );
        } catch (e) {
          debugPrint('⚠️ 알림 썸네일 업데이트 실패: $e');
        }
      } else {
        // 사진이 없으면 대표사진 제거
        await _repository.deleteCategoryPhoto(categoryId);

        // 관련 알림들의 썸네일을 null로 업데이트
        try {
          await notificationService.updateCategoryThumbnailInNotifications(
            categoryId: categoryId,
            newThumbnailUrl: '',
          );
        } catch (e) {
          debugPrint('⚠️ 알림 썸네일 업데이트 실패: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ 삭제 후 대표사진 자동 업데이트 실패: $e');
    }
  }
}
