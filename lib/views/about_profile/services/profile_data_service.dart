import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../../api/controller/category_controller.dart';
import '../../../api/controller/media_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/user.dart';

/// 프로필 화면에서 필요한 데이터와 기능을 담당하는 서비스입니다.
/// 사용자 정보와 프로필 사진 URL을 가져오고, 새로운 프로필 사진을 선택하고 업로드하는 기능을 제공합니다.
/// 화면에서 직접 API 호출이나 복잡한 로직을 처리하는 대신,
/// 이 서비스를 통해 필요한 데이터를 얻고 작업을 수행할 수 있도록 도와줍니다.
class ProfileScreenData {
  final User? userInfo;
  final String? profileImageUrl;

  const ProfileScreenData({this.userInfo, this.profileImageUrl});
}

/// 이 표시는 사진 올리기가 어떻게 끝났는지 알려줘요.
/// 성공했는지 실패했는지 쉽게 구분하게 해줘요.
enum ProfileImageUploadStatus { success, uploadFailed, failed }

/// 이 상자는 사진 올리기 결과를 한데 모아 담아줘요.
/// 화면이 다음에 무엇을 보여줄지 정하기 쉽게 해줘요.
class ProfileImageUploadResult {
  final ProfileImageUploadStatus status;
  final User? userInfo;
  final String? profileImageUrl;

  const ProfileImageUploadResult._({
    required this.status,
    this.userInfo,
    this.profileImageUrl,
  });

  const ProfileImageUploadResult.success({
    required User? userInfo,
    required String? profileImageUrl,
  }) : this._(
         status: ProfileImageUploadStatus.success,
         userInfo: userInfo,
         profileImageUrl: profileImageUrl,
       );

  const ProfileImageUploadResult.uploadFailed()
    : this._(status: ProfileImageUploadStatus.uploadFailed);

  const ProfileImageUploadResult.failed()
    : this._(status: ProfileImageUploadStatus.failed);
}

/// 커버 이미지 업로드 결과 상태
enum CoverImageUploadStatus { success, uploadFailed, failed }

/// 커버 이미지 업로드 결과
class CoverImageUploadResult {
  final CoverImageUploadStatus status;
  final String? coverImageKey;
  final String? coverImageUrl;

  const CoverImageUploadResult._({
    required this.status,
    this.coverImageKey,
    this.coverImageUrl,
  });

  const CoverImageUploadResult.success({
    required String? coverImageKey,
    required String? coverImageUrl,
  }) : this._(
         status: CoverImageUploadStatus.success,
         coverImageKey: coverImageKey,
         coverImageUrl: coverImageUrl,
       );

  const CoverImageUploadResult.uploadFailed()
    : this._(status: CoverImageUploadStatus.uploadFailed);

  const CoverImageUploadResult.failed()
    : this._(status: CoverImageUploadStatus.failed);
}

/// 이 도우미는 프로필 사진과 사용자 정보를 챙겨와요.
/// 화면 대신 바깥일을 맡아서 코드를 더 깔끔하게 해줘요.
class ProfileDataService {
  ProfileDataService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  /// 이 메서드는 사용자 정보와 프로필 사진 주소를 가져와요.
  /// 화면이 바로 쓸 수 있게 필요한 것만 묶어서 돌려줘요.
  Future<ProfileScreenData> loadUserData({
    required int userId,
    required UserController userController,
    required MediaController mediaController,
  }) async {
    final userInfo = await userController.getUser(userId);
    final profileImageKey = userInfo?.profileImageKey;

    String? profileImageUrl;
    if (profileImageKey != null && profileImageKey.isNotEmpty) {
      profileImageUrl = await mediaController.getPresignedUrl(profileImageKey);
    }

    return ProfileScreenData(
      userInfo: userInfo,
      profileImageUrl: profileImageUrl,
    );
  }

  /// 사진을 고르거나 찍어서 프로필 사진으로 쓸 수 있게 하는 메서드
  ///
  /// parameters:
  /// - [source]
  ///   - 사진을 고를지 카메라로 찍을지 정하는 소스입니다.
  ///   - ImageSource.gallery 또는 ImageSource.camera를 사용할 수 있어요.
  ///
  /// returns:
  /// - [File]: 사용자가 사진을 고르거나 찍으면 그 사진의 File 객체를 돌려줘요.
  Future<File?> pickProfileImage({required ImageSource source}) async {
    final pickedImage = await _imagePicker.pickImage(
      source: source,
      imageQuality: source == ImageSource.camera ? 85 : 70,
      maxWidth: 1080,
      maxHeight: 1080,
    );

    if (pickedImage == null) {
      return null;
    }

    return File(pickedImage.path);
  }

  /// 이 메서드는 사진 용량을 줄여서 더 가볍게 만들어요.
  /// 실패하면 원래 사진을 그대로 돌려줘서 멈추지 않아요.
  Future<File> compressProfileImage(File file) async {
    try {
      final targetPath =
          '${file.parent.path}/profile_${DateTime.now().millisecondsSinceEpoch}.webp';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
        format: CompressFormat.webp,
      );

      if (compressedFile != null) {
        return File(compressedFile.path);
      }

      return file;
    } catch (error) {
      debugPrint('프로필 이미지 압축 오류: $error');
      return file;
    }
  }

  /// 이 메서드는 사진을 서버에 올리고 새 프로필로 바꿔줘요.
  /// 끝나면 화면이 쓸 새 정보와 결과를 함께 알려줘요.
  Future<ProfileImageUploadResult> uploadProfileImage({
    required File file,
    required int userId,
    required UserController userController,
    required MediaController mediaController,
    required CategoryController categoryController,
  }) async {
    try {
      final multipartFile = await mediaController.fileToMultipart(file);
      final profileKey = await mediaController.uploadProfileImage(
        file: multipartFile,
        userId: userId,
      );

      if (profileKey == null) {
        return const ProfileImageUploadResult.uploadFailed();
      }

      final updatedUser = await userController.updateprofileImageUrl(
        userId: userId,
        profileImageKey: profileKey,
      );

      if (updatedUser != null) {
        userController.setCurrentUser(updatedUser);
      }

      await userController.refreshCurrentUser();

      categoryController.invalidateCache();
      await categoryController.loadCategories(userId, forceReload: true);

      final profileImageUrl = await mediaController.getPresignedUrl(profileKey);
      final refreshedUser = userController.currentUser;

      return ProfileImageUploadResult.success(
        userInfo: refreshedUser ?? updatedUser,
        profileImageUrl: profileImageUrl,
      );
    } catch (error) {
      debugPrint('프로필 이미지 업데이트 오류: $error');
      return const ProfileImageUploadResult.failed();
    }
  }

  /// 커버 이미지를 서버에 올리고 새 커버로 업데이트하는 메서드
  Future<CoverImageUploadResult> uploadCoverImage({
    required File file,
    required int userId,
    required UserController userController,
    required MediaController mediaController,
  }) async {
    try {
      final multipartFile = await mediaController.fileToMultipart(file);
      final coverKey = await mediaController.uploadProfileImage(
        file: multipartFile,
        userId: userId,
      );

      if (coverKey == null) {
        return const CoverImageUploadResult.uploadFailed();
      }

      final success = await userController.updateCoverImageUrl(
        userId: userId,
        coverImageKey: coverKey,
      );

      if (!success) {
        return const CoverImageUploadResult.failed();
      }

      final coverImageUrl = await mediaController.getPresignedUrl(coverKey);
      return CoverImageUploadResult.success(
        coverImageKey: coverKey,
        coverImageUrl: coverImageUrl,
      );
    } catch (error) {
      debugPrint('커버 이미지 업데이트 오류: $error');
      return const CoverImageUploadResult.failed();
    }
  }
}
