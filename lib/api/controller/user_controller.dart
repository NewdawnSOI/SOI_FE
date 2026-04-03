import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/utils/username_validator.dart';

import '../api_client.dart';

/// 현재 사용자와 뷰의 대상 사용자를 맞춰 프로필/커버 이미지 구독값을 전달합니다.
@immutable
class UserImageSelection {
  const UserImageSelection({this.imageUrl, this.imageKey});

  final String? imageUrl;
  final String? imageKey;

  /// 뷰가 기존 렌더링 방식을 유지하면서도 현재 선택된 이미지를 바로 쓸 수 있게 합니다.
  String? get displayImageUrl => imageUrl ?? imageKey;

  /// key 기반 캐시를 쓰는 위젯이 중앙 선택 결과를 그대로 재사용할 수 있게 합니다.
  String? get cacheKey => imageKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserImageSelection &&
          runtimeType == other.runtimeType &&
          imageUrl == other.imageUrl &&
          imageKey == other.imageKey;

  @override
  int get hashCode => Object.hash(imageUrl, imageKey);
}

/// 사용자 및 인증 컨트롤러
///
/// 사용자 관련 UI 상태 관리 및 인증 기능을 담당합니다.
/// UserService를 내부적으로 사용하며, API 변경 시 Service만 수정하면 됩니다.
///
/// 사용 예시:
/// ```dart
/// final controller = Provider.of<UserController>(context, listen: false);
///
/// // SMS 인증 요청
/// await controller.requestSmsVerification('01012345678');
///
/// // 로그인
/// final user = await controller.login(
///   nickName: 'hong123',
///   phoneNumber: '01012345678',
/// );
/// ```
class UserController extends ChangeNotifier {
  final UserService _userService;

  // SharedPreferences 키 상수
  static const String _keyIsLoggedIn = 'api_is_logged_in';
  static const String _keynickName = 'api_user_id';
  static const String _keyPhoneNumber = 'api_phone_number';
  static const String _keyAccessToken = 'api_access_token';
  static const String _keyOnboardingCompleted = 'api_onboarding_completed';
  static const String _keyCoverImageKey = 'api_cover_image_key';

  User? _currentUser;
  String? _coverImageUrlKey;
  bool _isLoading = false;
  String? _errorMessage;

  /// 생성자
  ///
  /// [userService]를 주입받아 사용합니다. 테스트 시 MockUserService를 주입할 수 있습니다.
  UserController({UserService? userService})
    : _userService = userService ?? UserService();

  /// 인증 오케스트레이션의 단계만 debug 로그로 남겨 수동/자동 로그인 실패 지점을 추적합니다.
  void _debugLogAuthStage(
    String flow,
    String stage, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    if (!kDebugMode) return;

    final payload = details.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    final suffix = payload.isEmpty ? '' : ', $payload';
    debugPrint('[UserController.auth] flow=$flow, stage=$stage$suffix');
  }

  /// 인증 상태 흐름에서 발생한 예외를 status와 타입 중심으로 축약해 debug 로그로 남깁니다.
  void _debugLogAuthError(String flow, String stage, Object error) {
    if (!kDebugMode) return;

    if (error is SoiApiException) {
      debugPrint(
        '[UserController.auth] flow=$flow, stage=$stage, errorType=${error.runtimeType}, status=${error.statusCode}, message=${error.message}',
      );
      return;
    }

    debugPrint(
      '[UserController.auth] flow=$flow, stage=$stage, errorType=${error.runtimeType}, error=$error',
    );
  }

  /// 현재 로그인된 사용자
  User? get currentUser => _currentUser;

  /// 현재 로그인된 사용자 ID
  int? get currentUserId => _currentUser?.id;

  /// 현재 사용자의 커버 이미지 키
  String? get coverImageUrlKey => _coverImageUrlKey;

  /// 뷰가 현재 사용자 프로필 이미지만 부분 구독할 수 있도록 fallback과 현재 상태를 합칩니다.
  UserImageSelection selectProfileImage({
    int? userId,
    String? nickname,
    String? fallbackImageUrl,
    String? fallbackImageKey,
  }) {
    // fallback 이미지 source와 UserController 선택값을 합쳐 렌더용 URL/cache key를 제공합니다.
    final fallback = UserImageSelection(
      imageUrl: _normalizeOptionalImageValue(fallbackImageUrl),
      imageKey: _normalizeOptionalImageValue(fallbackImageKey),
    );
    if (!_matchesCurrentUser(userId: userId, nickname: nickname)) {
      return fallback;
    }

    final currentUser = _currentUser;
    if (currentUser == null) {
      return fallback;
    }

    return _mergeUserImageSelection(
      fallback: fallback,
      currentImageUrl: currentUser.displayProfileImageUrl,
      currentImageKey: currentUser.profileImageCacheKey,
    );
  }

  /// 뷰가 현재 사용자 커버 이미지만 부분 구독할 수 있도록 fallback과 현재 상태를 합칩니다.
  UserImageSelection selectCoverImage({
    int? userId,
    String? nickname,
    String? fallbackImageUrl,
    String? fallbackImageKey,
  }) {
    final fallback = UserImageSelection(
      imageUrl: _normalizeOptionalImageValue(fallbackImageUrl),
      imageKey: _normalizeOptionalImageValue(fallbackImageKey),
    );
    if (!_matchesCurrentUser(userId: userId, nickname: nickname)) {
      return fallback;
    }

    final currentUser = _currentUser;
    if (currentUser == null) {
      return fallback;
    }

    return _mergeUserImageSelection(
      fallback: fallback,
      currentImageUrl: currentUser.displayCoverImageUrl,
      currentImageKey: currentUser.profileCoverImageCacheKey,
    );
  }

  /// 로그인 상태
  bool get isLoggedIn => _currentUser != null;

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// Firebase 전화번호 인증이 즉시 완료된 경우 화면이 SMS 단계를 건너뛸 수 있게 상태를 노출합니다.
  bool get isPhoneVerificationCompleted => _userService.isPhoneNumberVerified;

  /// 전화번호 인증 채널이나 입력 번호가 바뀌면 이전 인증 상태를 비워 현재 시도와 섞이지 않게 합니다.
  void resetPhoneVerificationState() {
    _userService.resetPhoneVerificationState();
  }

  // ============================================
  // SMS 인증
  // ============================================

  /// SMS 인증 요청
  /// [phoneNumber]로 인증 SMS를 전송합니다.
  /// 한국 번호는 API, 그 외는 Firebase를 선택할 수 있게 호출 옵션을 전달받습니다.
  ///
  /// Parameters:
  ///   - [phoneNumber]: 인증할 전화번호 (String)
  ///
  /// Returns: 요청 성공 여부
  ///   - true: 요청 성공
  ///   - false: 요청 실패

  Future<bool> requestSmsVerification(
    String phoneNumber, {
    bool useFirebase = true,
  }) async {
    final normalizedPhoneNumber = phoneNumber.trim();

    _beginLoading();

    try {
      return await _userService.sendSmsVerification(
        normalizedPhoneNumber,
        useFirebase: useFirebase,
      );
    } on SoiApiException catch (e) {
      _finishLoading(errorMessage: e.message);
      rethrow;
    } catch (e) {
      final wrapped = SoiApiException(
        message: 'SMS 인증 요청 실패: $e',
        originalException: e,
      );
      _finishLoading(errorMessage: wrapped.message);
      throw wrapped;
    } finally {
      if (_isLoading) {
        _finishLoading();
      }
    }
  }

  /// 인증 코드 확인
  /// [phoneNumber]와 [code]를 사용하여 인증 코드를 확인합니다.
  /// 한국 번호는 API, 그 외는 Firebase를 선택할 수 있게 호출 옵션을 전달받습니다.
  ///
  /// Parameters:
  ///   - [phoneNumber]: 인증할 전화번호 (String)
  ///   - [code]: 인증 코드 (String)
  ///
  /// Returns: 확인 성공 여부
  ///   - true: 확인 성공
  ///   - false: 확인 실패

  Future<bool> verifySmsCode(
    String phoneNumber,
    String code, {
    bool useFirebase = true,
  }) async {
    final normalizedPhoneNumber = phoneNumber.trim();
    final normalizedCode = code.trim();

    _beginLoading();

    try {
      return await _userService.verifySmsCode(
        normalizedPhoneNumber,
        normalizedCode,
        useFirebase: useFirebase,
      );
    } on SoiApiException catch (e) {
      _finishLoading(errorMessage: e.message);
      rethrow;
    } catch (e) {
      final wrapped = SoiApiException(
        message: '인증 코드 확인 실패: $e',
        originalException: e,
      );
      _finishLoading(errorMessage: wrapped.message);
      throw wrapped;
    } finally {
      if (_isLoading) {
        _finishLoading();
      }
    }
  }

  // ============================================
  // 로그인/로그아웃
  // ============================================

  /// 로그인
  /// [nickName]과 [phoneNumber]를 함께 사용해 로그인합니다.
  ///
  /// Parameters:
  ///   - [nickName]: 로그인할 닉네임/ID
  ///   - [phoneNumber]: 로그인할 전화번호
  ///
  /// Returns: 로그인된 사용자 정보 (User)
  ///   - null: 로그인 실패

  Future<User?> login({String? nickName, String? phoneNumber}) async {
    final normalizedNickname = nickName?.trim();
    final normalizedPhoneNumber = phoneNumber?.trim();
    _debugLogAuthStage(
      'manual-login',
      'start',
      details: <String, Object?>{
        'hasNickname': normalizedNickname?.isNotEmpty ?? false,
        'nicknameLength': normalizedNickname?.length,
        'phoneLength': normalizedPhoneNumber?.length,
      },
    );

    _beginLoading();

    try {
      final user = await _userService.login(
        nickName: normalizedNickname,
        phoneNum: normalizedPhoneNumber,
      );
      _debugLogAuthStage(
        'manual-login',
        'service-returned',
        details: <String, Object?>{'hasUser': user != null},
      );
      _syncCurrentUserState(user);

      // 로그인 성공 시 상태 저장
      if (user != null) {
        await saveLoginState(userId: user.id, phoneNumber: user.phoneNumber);
        await _persistCoverImageKey(_coverImageUrlKey);
        _debugLogAuthStage(
          'manual-login',
          'session-persisted',
          details: <String, Object?>{
            'hasCoverImageKey': _coverImageUrlKey?.isNotEmpty ?? false,
          },
        );
      } else {
        await _persistCoverImageKey(null);
        _debugLogAuthStage('manual-login', 'not-found');
        debugPrint('[UserController.login] 로그인 실패 code=404');
      }

      _finishLoading(notify: false);
      notifyListeners();
      return user;
    } on NotFoundException catch (e) {
      _debugLogAuthError('manual-login', 'service-login', e);
      debugPrint(
        '[UserController.login] 로그인 실패 code=${e.statusCode ?? 404}, message=${e.message}',
      );
      _syncCurrentUserState(null);
      await _persistCoverImageKey(null);
      _finishLoading(notify: false);
      notifyListeners();
      return null;
    } on SoiApiException catch (e) {
      _debugLogAuthError('manual-login', 'service-login', e);
      debugPrint(
        '[UserController.login] 로그인 실패 code=${e.statusCode ?? 'unknown'}, message=${e.message}',
      );
      _finishLoading(errorMessage: '로그인 실패: $e');
      rethrow;
    } catch (e) {
      _debugLogAuthError('manual-login', 'service-login', e);
      debugPrint('[UserController.login] 로그인 실패 code=unknown, error=$e');
      final wrapped = SoiApiException(
        message: '로그인 실패: $e',
        originalException: e,
      );
      _finishLoading(errorMessage: wrapped.message);
      throw wrapped;
    }
  }

  /// 로그아웃
  /// 현재 로그인된 사용자를 로그아웃 처리합니다.
  Future<void> logout() async {
    _syncCurrentUserState(null);
    _clearError();

    // 저장된 로그인 상태도 삭제
    await clearLoginState();
    notifyListeners();
  }

  /// 현재 사용자 정보 갱신
  /// 서버 응답에 포함된 커버 이미지 키까지 함께 동기화해 UI와 로컬 세션을 같은 상태로 유지합니다.
  Future<void> refreshCurrentUser() async {
    if (!SoiApiClient.instance.isAuthenticated) return;
    _debugLogAuthStage(
      'refresh-current-user',
      'start',
      details: <String, Object?>{
        'isAuthenticated': SoiApiClient.instance.isAuthenticated,
      },
    );

    _beginLoading();
    try {
      final user = await _userService.getCurrentUser();
      _syncCurrentUserState(user);
      await _persistCoverImageKey(_coverImageUrlKey);
      _debugLogAuthStage(
        'refresh-current-user',
        'success',
        details: <String, Object?>{
          'hasCoverImageKey': _coverImageUrlKey?.isNotEmpty ?? false,
        },
      );
      _finishLoading(notify: false);
      notifyListeners();
    } catch (e) {
      _debugLogAuthError('refresh-current-user', 'get-current-user', e);
      _finishLoading(errorMessage: '사용자 정보 갱신 실패: $e');
    }
  }

  /// 현재 사용자 설정 (외부에서 직접 설정 필요 시)
  void setCurrentUser(User? user) {
    if (_hasSameCurrentUserSnapshot(user)) {
      return;
    }
    _syncCurrentUserState(user);
    unawaited(_persistCoverImageKey(_coverImageUrlKey));
    notifyListeners();
  }

  // ============================================
  // 사용자 생성
  // ============================================

  /// 사용자 생성
  /// 새로운 사용자를 생성합니다.
  ///
  /// Parameters:
  ///   - [name]: 사용자 이름 (String)
  ///   - [nickName]: 사용자 닉네임 (String)
  ///   - [phoneNum]: 전화번호 (String)
  ///   - [birthDate]: 생년월일 (String, YYYY-MM-DD)
  ///   - [profileImageKey]: 프로필 이미지 파일 키 (선택)
  ///   - [profileCoverImageKey]: 프로필 커버 이미지 파일 키 (선택)
  ///   - [serviceAgreed]: 서비스 이용약관 동의 여부 (기본값: true)
  ///   - [privacyPolicyAgreed]: 개인정보 처리방침 동의 여부 (기본값: true)
  ///   - [marketingAgreed]: 마케팅 정보 수신 동의 여부 (기본값: false)
  ///
  /// 회원가입 직전 입력과 프로필/커버 이미지 키를 정규화해 빈 값이 null 대신 빈 문자열 흐름을 타도록 맞춥니다.
  /// Returns: 생성된 사용자 정보 (User)
  ///   - null: 생성 실패

  Future<User?> createUser({
    required String name,
    required String nickName,
    required String phoneNum,
    required String birthDate,
    String? profileImageKey,
    String? profileCoverImageKey,
    bool serviceAgreed = true,
    bool privacyPolicyAgreed = true,
    bool marketingAgreed = false,
  }) async {
    final normalizedName = name.trim();
    final normalizedNickName = nickName.trim();
    final normalizedPhoneNum = phoneNum.trim();
    final normalizedBirthDate = birthDate.trim();
    final normalizedProfileImageKey = profileImageKey?.trim() ?? '';
    final normalizedProfileCoverImageKey = profileCoverImageKey?.trim() ?? '';

    _debugLogAuthStage(
      'signup',
      'start',
      details: <String, Object?>{
        'nameLength': normalizedName.length,
        'nicknameLength': normalizedNickName.length,
        'phoneLength': normalizedPhoneNum.length,
        'birthDateLength': normalizedBirthDate.length,
        'hasProfileImageKey': normalizedProfileImageKey.isNotEmpty,
        'hasProfileCoverImageKey': normalizedProfileCoverImageKey.isNotEmpty,
      },
    );

    _beginLoading();

    try {
      final createdUser = await _userService.createUser(
        name: normalizedName,
        nickName: normalizedNickName,
        phoneNum: normalizedPhoneNum,
        birthDate: normalizedBirthDate,
        profileImageKey: normalizedProfileImageKey,
        profileCoverImageKey: normalizedProfileCoverImageKey,
        serviceAgreed: serviceAgreed,
        privacyPolicyAgreed: privacyPolicyAgreed,
        marketingAgreed: marketingAgreed,
      );
      _debugLogAuthStage(
        'signup',
        'user-created',
        details: <String, Object?>{
          'createdUserId': createdUser.id,
          'hasCoverImageKey':
              createdUser.profileCoverImageKey?.isNotEmpty ?? false,
          'hasProfileImageKey':
              createdUser.profileImageKey?.isNotEmpty ?? false,
        },
      );

      _debugLogAuthStage('signup', 'auth-after-signup.start');
      final authenticatedUser = await _authenticateAfterSignup(
        phoneNum: normalizedPhoneNum,
        nickName: normalizedNickName,
      );
      if (authenticatedUser == null) {
        throw const AuthException(message: '회원가입 후 로그인에 실패했습니다.');
      }

      _syncCurrentUserState(authenticatedUser);
      await saveLoginState(
        userId: authenticatedUser.id,
        phoneNumber: authenticatedUser.phoneNumber,
      );
      await _persistCoverImageKey(_coverImageUrlKey);
      _finishLoading(notify: false);
      notifyListeners();
      return authenticatedUser;
    } catch (e) {
      _debugLogAuthError('signup', 'create-or-authenticate', e);
      _syncCurrentUserState(null);
      await clearLoginState();
      _finishLoading(errorMessage: '사용자 생성 실패: $e');
      return null;
    }
  }

  Future<User?> _authenticateAfterSignup({
    required String phoneNum,
    required String nickName,
  }) async {
    return _userService.login(nickName: nickName, phoneNum: phoneNum);
  }

  // ============================================
  // 사용자 조회
  // ============================================

  /// 사용자 조회
  /// [id]에 해당하는 사용자를 조회합니다.
  ///
  /// Parameters:
  ///   - [id]: 사용자의 Uid (int)
  ///
  /// Returns: 조회된 사용자 정보 (User)
  ///   - null: 조회 실패
  Future<User?> getUser(int id) async {
    _beginLoading();

    try {
      return await _userService.getUser(id);
    } catch (e) {
      _finishLoading(errorMessage: '사용자 조회 실패: $e');
      return null;
    } finally {
      if (_isLoading) {
        _finishLoading();
      }
    }
  }

  /// 닉네임으로 사용자 조회
  Future<User?> getUserByNickname(String nickname) async {
    final numericId = int.tryParse(nickname);
    if (numericId != null) {
      return getUser(numericId);
    }

    try {
      final users = await findUsersByKeyword(nickname);
      try {
        return users.firstWhere((user) => user.userId == nickname);
      } catch (_) {
        return users.isNotEmpty ? users.first : null;
      }
    } catch (e) {
      debugPrint('[UserController] 닉네임 조회 실패: $e');
      return null;
    }
  }

  /// 모든 사용자 정보를 가지고 오는 메서드
  /// Returns: 사용자 목록 (`List<User>`)
  Future<List<User>> getAllUsers() async {
    _beginLoading();

    try {
      return await _userService.getAllUsers();
    } catch (e) {
      _finishLoading(errorMessage: '사용자 목록 조회 실패: $e');
      return [];
    } finally {
      if (_isLoading) {
        _finishLoading();
      }
    }
  }

  /// 키워드로 사용자 검색
  /// [keyword]를 포함하는 사용자들을 검색합니다.
  ///
  /// Parameters:
  ///   - [keyword]: 검색 키워드 (String)
  ///
  /// Returns: 검색된 사용자 목록 (`List<User>`)
  Future<List<User>> findUsersByKeyword(String keyword) async {
    _beginLoading();

    try {
      return await _userService.findUsersByKeyword(keyword);
    } catch (e) {
      _finishLoading(errorMessage: '사용자 검색 실패: $e');
      return [];
    } finally {
      if (_isLoading) {
        _finishLoading();
      }
    }
  }

  // ============================================
  // 사용자 ID 중복 확인
  // ============================================

  /// nickName 중복 확인
  ///
  /// Parameters:
  /// - [nickName]: 확인할 nickName (String)
  ///
  /// Returns: 사용 가능한 경우 true, 중복된 경우 false
  Future<bool> checknickNameAvailable(String nickName) async {
    _beginLoading();

    try {
      return await _userService.checknickNameAvailable(nickName);
    } catch (e) {
      _finishLoading(errorMessage: 'ID 중복 확인 실패: $e');
      return false;
    } finally {
      if (_isLoading) {
        _finishLoading();
      }
    }
  }

  // ============================================
  // 사용자 정보 수정
  // ============================================

  /// 사용자 정보 수정
  /// 기존 사용자 정보를 수정합니다.
  ///
  /// Parameters:
  /// - [id]: 사용자 ID (int)
  /// - [name]: 사용자 이름 (선택)
  /// - [nickName]: 사용자 닉네임 (선택)
  /// - [phoneNum]: 전화번호 (선택)
  /// - [birthDate]: 생년월일 (선택)
  /// - [profileImageKey]: 프로필 이미지 파일 키 (선택)
  ///
  /// Returns: 수정된 사용자 정보 (User)
  ///   - null: 수정 실패
  Future<User?> updateUser({
    required int id,
    String? name,
    String? nickName,
    String? phoneNum,
    String? birthDate,
    String? profileImageKey,
  }) async {
    _beginLoading();

    try {
      if (nickName != null && isForbiddenUsername(nickName)) {
        _finishLoading(
          errorMessage: 'This username is not allowed. Please choose another.',
        );
        return null;
      }
      return await _userService.updateUser(
        id: id,
        name: name,
        nickName: nickName,
        phoneNum: phoneNum,
        birthDate: birthDate,
        profileImageKey: profileImageKey,
      );
    } catch (e) {
      _finishLoading(errorMessage: '사용자 정보 수정 실패: $e');
      return null;
    } finally {
      if (_isLoading) {
        _finishLoading();
      }
    }
  }

  /// 사용자의 프로필 이미지를 업데이트합니다.
  ///
  /// Parameters:
  /// - [userId]
  ///   - 프로필 이미지를 수정할 사용자 ID
  ///   - 보안을 위해, JWT 인증된 사용자와 [userId]가 일치하는지 확인합니다.
  /// - [profileImageKey]: 프로필 이미지 키
  ///
  /// Returns:
  /// - [User]: 수정된 사용자 정보
  ///
  /// Throws:
  /// - [ForbiddenException]: JWT 인증 사용자와 요청 대상 사용자가 일치하지 않는 경우
  /// - [SoiApiException]: 기타 API 에러
  Future<User?> updateprofileImageUrl({
    required int userId,
    required String profileImageKey,
  }) async {
    _beginLoading();

    try {
      final updatedUser = await _userService.updateProfileImage(
        userId: userId,
        profileImageKey: profileImageKey,
      );
      if (_matchesCurrentUser(userId: userId, nickname: updatedUser.userId)) {
        _syncCurrentUserState(_mergeCurrentUserProfileUpdate(updatedUser));
      }
      _finishLoading(notify: false);
      notifyListeners();
      return updatedUser;
    } catch (e) {
      _finishLoading(errorMessage: '프로필 이미지 수정 실패: $e');
      return null;
    }
  }

  /// 커버 이미지 업데이트
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  /// - [coverImageKey]: 새 커버 이미지 키
  ///
  /// Returns: 성공 여부
  Future<bool> updateCoverImageUrl({
    required int userId,
    required String coverImageKey,
  }) async {
    _beginLoading();
    try {
      final updatedUser = await _userService.updateCoverImage(
        userId: userId,
        coverImageKey: coverImageKey,
      );
      final resolvedUser = User(
        id: updatedUser.id,
        userId: updatedUser.userId,
        name: updatedUser.name,
        profileImageKey: updatedUser.profileImageKey,
        profileImageUrl: updatedUser.profileImageUrl,
        profileCoverImageKey: updatedUser.profileCoverImageKey ?? coverImageKey,
        profileCoverImageUrl: updatedUser.profileCoverImageUrl,
        birthDate: updatedUser.birthDate,
        phoneNumber: updatedUser.phoneNumber,
        active: updatedUser.active,
      );
      _syncCurrentUserState(resolvedUser);
      await _persistCoverImageKey(_coverImageUrlKey);
      _finishLoading(notify: false);
      notifyListeners();
      return true;
    } catch (e) {
      _finishLoading(errorMessage: '커버 이미지 수정 실패: $e');
      return false;
    }
  }

  /// 현재 사용자와 커버 이미지 키를 한 번에 맞춰 controller 상태를 일관되게 유지합니다.
  void _syncCurrentUserState(User? user) {
    _currentUser = user;
    _coverImageUrlKey = user?.profileCoverImageKey;
  }

  /// 프로필 이미지 응답이 일부 필드를 생략해도 현재 사용자 커버/세션 스냅샷이 유지되게 병합합니다.
  User _mergeCurrentUserProfileUpdate(User updatedUser) {
    final currentUser = _currentUser;
    if (currentUser == null || currentUser.id != updatedUser.id) {
      return updatedUser;
    }

    return User(
      id: updatedUser.id,
      userId: updatedUser.userId,
      name: updatedUser.name,
      profileImageKey: updatedUser.profileImageKey,
      profileImageUrl: updatedUser.profileImageUrl,
      profileCoverImageKey:
          updatedUser.profileCoverImageKey ?? currentUser.profileCoverImageKey,
      profileCoverImageUrl:
          updatedUser.profileCoverImageUrl ?? currentUser.profileCoverImageUrl,
      birthDate: updatedUser.birthDate ?? currentUser.birthDate,
      phoneNumber: updatedUser.phoneNumber.isNotEmpty
          ? updatedUser.phoneNumber
          : currentUser.phoneNumber,
      active: updatedUser.active || currentUser.active,
    );
  }

  /// 현재 뷰의 대상 사용자가 로그인 사용자와 같은지 식별해 selector 범위를 현재 사용자로만 제한합니다.
  bool _matchesCurrentUser({int? userId, String? nickname}) {
    final currentUser = _currentUser;
    if (currentUser == null) {
      return false;
    }

    if (userId != null) {
      return currentUser.id == userId;
    }

    final normalizedNickname = nickname?.trim();
    if (normalizedNickname == null || normalizedNickname.isEmpty) {
      return false;
    }
    return currentUser.userId == normalizedNickname;
  }

  /// 같은 사용자라도 이미지나 핵심 필드가 달라지면 selector가 즉시 갱신되도록 전체 스냅샷을 비교합니다.
  bool _hasSameCurrentUserSnapshot(User? user) {
    final currentUser = _currentUser;
    if (identical(currentUser, user)) {
      return true;
    }
    if (currentUser == null || user == null) {
      return currentUser == user;
    }

    return mapEquals(currentUser.toJson(), user.toJson()) &&
        _coverImageUrlKey == user.profileCoverImageKey;
  }

  /// selector 비교 전에 이미지 관련 선택 문자열을 공백 없는 값으로 정규화합니다.
  String? _normalizeOptionalImageValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 현재 사용자 key가 바뀌면 예전 fallback URL을 버려 새 이미지가 같은 셀에서 즉시 교체되게 합니다.
  UserImageSelection _mergeUserImageSelection({
    required UserImageSelection fallback,
    required String? currentImageUrl,
    required String? currentImageKey,
  }) {
    final normalizedCurrentImageUrl = _normalizeOptionalImageValue(
      currentImageUrl,
    );
    final normalizedCurrentImageKey = _normalizeOptionalImageValue(
      currentImageKey,
    );

    if (normalizedCurrentImageKey == null) {
      return UserImageSelection(
        imageUrl: normalizedCurrentImageUrl ?? fallback.imageUrl,
        imageKey: fallback.imageKey,
      );
    }

    return UserImageSelection(
      imageUrl:
          normalizedCurrentImageUrl ??
          (normalizedCurrentImageKey == fallback.imageKey
              ? fallback.imageUrl
              : null),
      imageKey: normalizedCurrentImageKey,
    );
  }

  /// 로컬 세션이 서버 응답과 같은 커버 이미지 키를 재사용하도록 SharedPreferences를 갱신합니다.
  Future<void> _persistCoverImageKey(String? key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalizedKey = key?.trim();
      if (normalizedKey == null || normalizedKey.isEmpty) {
        await prefs.remove(_keyCoverImageKey);
        return;
      }
      await prefs.setString(_keyCoverImageKey, normalizedKey);
    } catch (e) {
      debugPrint('[UserController] 커버 이미지 키 저장 실패: $e');
    }
  }

  // ============================================
  // 사용자 삭제
  // ============================================

  /// 사용자 삭제
  /// [id]에 해당하는 사용자를 삭제합니다.
  ///
  /// Parameters:
  ///   - [id]: 사용자의 Uid (int)
  ///
  /// Returns: 삭제된 사용자 정보 (User)
  ///   - null: 삭제 실패
  Future<User?> deleteUser(int id) async {
    _beginLoading();

    try {
      final user = await _userService.deleteUser(id);
      _currentUser = null;
      await clearLoginState();
      _finishLoading(notify: false);
      notifyListeners();
      return user;
    } catch (e) {
      _finishLoading(errorMessage: '사용자 삭제 실패: $e');
      return null;
    }
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void _beginLoading() {
    final shouldNotify = !_isLoading || _errorMessage != null;
    _isLoading = true;
    _errorMessage = null;
    if (shouldNotify) {
      notifyListeners();
    }
  }

  void _finishLoading({String? errorMessage, bool notify = true}) {
    final shouldNotify = _isLoading || _errorMessage != errorMessage;
    _isLoading = false;
    _errorMessage = errorMessage;
    if (notify && shouldNotify) {
      notifyListeners();
    }
  }

  // ============================================================
  // 로그인 상태 유지 (SharedPreferences) 메서드
  // ============================================================

  /// 로그인 상태를 SharedPreferences에 저장합니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  /// - [phoneNumber]: 전화번호
  Future<void> saveLoginState({
    required int userId,
    required String phoneNumber,
    String? accessToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveAccessToken =
          accessToken ?? SoiApiClient.instance.authToken;
      final hasAccessToken =
          effectiveAccessToken != null && effectiveAccessToken.isNotEmpty;

      final operations = <Future<bool>>[
        prefs.setBool(_keyIsLoggedIn, hasAccessToken),
        prefs.setInt(_keynickName, userId),
        prefs.setString(_keyPhoneNumber, phoneNumber),
      ];
      if (hasAccessToken) {
        operations.add(prefs.setString(_keyAccessToken, effectiveAccessToken));
      } else {
        operations.add(prefs.remove(_keyAccessToken));
      }
      await Future.wait(operations);
      debugPrint('[UserController] 로그인 상태 저장 완료: userId=$userId');
    } catch (e) {
      debugPrint('[UserController] 로그인 상태 저장 실패: $e');
    }
  }

  /// 온보딩 완료 상태를 저장합니다.
  /// [completed]가 true이면 온보딩이 완료된 상태로 저장합니다.
  /// false이면 미완료 상태로 저장합니다.
  ///
  /// Parameters:
  ///   - [completed]: 온보딩 완료 여부 (bool)
  Future<void> setOnboardingCompleted(bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingCompleted, completed);
      debugPrint('[UserController] 온보딩 완료 상태 저장: $completed');
    } catch (e) {
      debugPrint('[UserController] 온보딩 완료 상태 저장 실패: $e');
    }
  }

  /// 온보딩 완료 여부를 확인합니다.
  /// Returns: 온보딩 완료 여부 (bool)
  ///   - true: 온보딩 완료
  ///   - false: 온보딩 미완료
  Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyOnboardingCompleted) ?? false;
    } catch (e) {
      debugPrint('[UserController] 온보딩 완료 상태 확인 실패: $e');
      return false;
    }
  }

  /// 저장된 로그인 상태를 확인합니다.
  /// Returns: 로그인 상태 (bool)
  ///  - true: 로그인 상태
  ///  - false: 비로그인 상태
  Future<bool> isLoggedInPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      debugPrint('[UserController] 로그인 상태 확인 실패: $e');
      return false;
    }
  }

  /// 저장된 사용자 정보를 가져옵니다.
  /// Returns: 사용자 정보 맵 (`Map<String, dynamic>`)
  ///   - null: 저장된 정보 없음
  Future<Map<String, dynamic>?> getSavedUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

      if (!isLoggedIn) {
        return null;
      }

      final userId = prefs.getInt(_keynickName);
      final phoneNumber = prefs.getString(_keyPhoneNumber);
      final accessToken = prefs.getString(_keyAccessToken);

      if (userId == null) {
        return null;
      }

      return {
        'userId': userId,
        'phoneNumber': phoneNumber,
        'accessToken': accessToken,
        'onboardingCompleted': prefs.getBool(_keyOnboardingCompleted) ?? false,
      };
    } catch (e) {
      debugPrint('[UserController] 저장된 사용자 정보 조회 실패: $e');
      return null;
    }
  }

  /// 자동 로그인을 시도합니다.
  /// 저장된 사용자 ID로 서버에서 사용자 정보를 가져옵니다.
  /// Returns: 자동 로그인 성공 여부 (bool)
  ///  - true: 자동 로그인 성공
  ///  - false: 자동 로그인 실패
  Future<bool> tryAutoLogin() async {
    try {
      _debugLogAuthStage('auto-login', 'start');
      debugPrint('[UserController] 자동 로그인 시도...');

      final savedInfo = await getSavedUserInfo();
      _debugLogAuthStage(
        'auto-login',
        'saved-info-loaded',
        details: <String, Object?>{'hasSavedInfo': savedInfo != null},
      );
      if (savedInfo == null) {
        debugPrint('[UserController] 저장된 로그인 정보 없음');
        return false;
      }

      final userId = savedInfo['userId'] as int;
      final accessToken = savedInfo['accessToken'] as String?;
      _debugLogAuthStage(
        'auto-login',
        'saved-credentials-resolved',
        details: <String, Object?>{
          'hasAccessToken': accessToken?.isNotEmpty ?? false,
          'tokenLength': accessToken?.length,
        },
      );
      debugPrint('[UserController] 저장된 userId: $userId');

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('[UserController] 저장된 JWT 토큰 없음');
        await clearLoginState();
        return false;
      }

      SoiApiClient.instance.setAuthToken(accessToken);
      _debugLogAuthStage(
        'auto-login',
        'token-restored',
        details: <String, Object?>{
          'isAuthenticated': SoiApiClient.instance.isAuthenticated,
        },
      );

      // 서버에서 현재 사용자 정보 조회
      final user = await _userService.getCurrentUser();
      _syncCurrentUserState(user);
      await _persistCoverImageKey(_coverImageUrlKey);
      _debugLogAuthStage(
        'auto-login',
        'get-current-user.success',
        details: <String, Object?>{
          'hasCoverImageKey': _coverImageUrlKey?.isNotEmpty ?? false,
        },
      );

      notifyListeners();
      debugPrint('[UserController] 자동 로그인 성공: ${user.name}');
      return true;
    } catch (e) {
      _debugLogAuthError('auto-login', 'restore-or-get-current-user', e);
      debugPrint('[UserController] 자동 로그인 실패: $e');
      await clearLoginState();
      return false;
    }
  }

  /// 저장된 로그인 상태를 삭제합니다.
  /// Returns: 없음
  Future<void> clearLoginState() async {
    try {
      SoiApiClient.instance.clearAuthToken();
      final prefs = await SharedPreferences.getInstance();
      await Future.wait(<Future<bool>>[
        prefs.remove(_keyIsLoggedIn),
        prefs.remove(_keynickName),
        prefs.remove(_keyPhoneNumber),
        prefs.remove(_keyAccessToken),
        prefs.remove(_keyOnboardingCompleted),
        prefs.remove(_keyCoverImageKey),
      ]);
      debugPrint('[UserController] 로그인 상태 삭제 완료');
    } catch (e) {
      debugPrint('[UserController] 로그인 상태 삭제 실패: $e');
    }
  }
}
