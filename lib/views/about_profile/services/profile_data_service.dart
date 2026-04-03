import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../api/controller/category_controller.dart';
import '../../../api/controller/media_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/user.dart';
import '../../../api/media_processing/media_processing_backend.dart';

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
  /// 이미지 선택기와 공통 미디어 백엔드를 받아 프로필 업로드 경로를 테스트 가능하게 만듭니다.
  ProfileDataService({
    ImagePicker? imagePicker,
    MediaProcessingBackend? mediaProcessingBackend,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _mediaProcessingBackend =
           mediaProcessingBackend ?? DefaultMediaProcessingBackend.instance;

  final ImagePicker _imagePicker;
  final MediaProcessingBackend _mediaProcessingBackend;

  /// 이 메서드는 사용자 정보와 프로필 사진 주소를 가져와요.
  /// 화면이 바로 쓸 수 있게 필요한 것만 묶어서 돌려줘요.
  Future<ProfileScreenData> loadUserData({
    required int userId,
    required UserController userController,
    required MediaController mediaController,
  }) async {
    final userInfo = await userController.getUser(userId);
    String? profileImageUrl = userInfo?.displayProfileImageUrl;
    final profileImageKey = userInfo?.profileImageCacheKey;

    if ((profileImageUrl == null || profileImageUrl.isEmpty) &&
        profileImageKey != null &&
        profileImageKey.isNotEmpty) {
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
  /// EXIF 방향이 있는 업로드는 먼저 픽셀 기준으로 다시 저장해 플랫폼별 회전/반전 차이를 없앱니다.
  Future<File> compressProfileImage(File file) async {
    final preparedFile = await _normalizeUploadImageOrientation(file);
    try {
      final targetPath =
          '${file.parent.path}/profile_${DateTime.now().millisecondsSinceEpoch}.webp';

      final compressedFile = await _mediaProcessingBackend.compressImage(
        inputFile: preparedFile,
        outputPath: targetPath,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
        format: MediaImageOutputFormat.webp,
      );

      if (compressedFile != null) {
        await _deletePreparedUploadFile(
          originalFile: file,
          preparedFile: preparedFile,
        );
        return compressedFile;
      }

      return preparedFile;
    } catch (error) {
      debugPrint('프로필 이미지 압축 오류: $error');
      return preparedFile;
    }
  }

  /// 원본 바이트의 EXIF 방향을 먼저 읽고, 디코더가 바로 세운 픽셀을 새 파일로 고정해 업로드 결과를 안정화합니다.
  Future<File> _normalizeUploadImageOrientation(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final orientation = _readEncodedImageOrientation(bytes);
      if (orientation == null || orientation == 1) {
        return file;
      }

      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        return file;
      }

      final normalizedImage = _clearDecodedImageOrientation(decodedImage);
      final normalizedBytes = img.encodeJpg(normalizedImage, quality: 95);
      final normalizedPath =
          '${file.parent.path}/profile_upright_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final normalizedFile = File(normalizedPath);
      await normalizedFile.writeAsBytes(normalizedBytes, flush: true);
      return normalizedFile;
    } catch (error) {
      debugPrint('프로필 이미지 방향 정규화 오류: $error');
      return file;
    }
  }

  /// JPEG 원본의 EXIF 방향은 디코더가 픽셀에 반영하기 전에 별도로 읽어야 재인코딩 필요 여부를 판별할 수 있습니다.
  int? _readEncodedImageOrientation(Uint8List bytes) {
    return img.decodeJpgExif(bytes)?.imageIfd.orientation;
  }

  /// 디코딩된 이미지는 이미 표시 방향 기준 픽셀을 가지므로, EXIF 방향 태그만 제거해 업로드 결과를 고정합니다.
  img.Image _clearDecodedImageOrientation(img.Image decodedImage) {
    final normalizedImage = img.Image.from(decodedImage);
    normalizedImage.exif = img.ExifData.from(decodedImage.exif);
    normalizedImage.exif.imageIfd.orientation = null;
    return normalizedImage;
  }

  /// 압축 성공 뒤에는 임시 정규화 파일만 정리해 업로드 캐시가 불필요하게 남지 않게 합니다.
  Future<void> _deletePreparedUploadFile({
    required File originalFile,
    required File preparedFile,
  }) async {
    if (preparedFile.path == originalFile.path) {
      return;
    }

    try {
      if (await preparedFile.exists()) {
        await preparedFile.delete();
      }
    } catch (error) {
      debugPrint('프로필 업로드 임시 파일 정리 오류: $error');
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
