import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/utils/username_validator.dart';

import '../api_client.dart';

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

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  /// 생성자
  ///
  /// [userService]를 주입받아 사용합니다. 테스트 시 MockUserService를 주입할 수 있습니다.
  UserController({UserService? userService})
    : _userService = userService ?? UserService();

  /// 현재 로그인된 사용자
  User? get currentUser => _currentUser;

  /// 현재 로그인된 사용자 ID
  int? get currentUserId => _currentUser?.id;

  /// 로그인 상태
  bool get isLoggedIn => _currentUser != null;

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  // ============================================
  // SMS 인증
  // ============================================

  /// SMS 인증 요청
  /// [phoneNumber]로 인증 SMS를 전송합니다.
  ///
  /// Parameters:
  ///   - [phoneNumber]: 인증할 전화번호 (String)
  ///
  /// Returns: 요청 성공 여부
  ///   - true: 요청 성공
  ///   - false: 요청 실패

  Future<bool> requestSmsVerification(String phoneNumber) async {
    final normalizedPhoneNumber = phoneNumber.trim();

    _setLoading(true);
    _clearError();

    try {
      final result = await _userService.sendSmsVerification(
        normalizedPhoneNumber,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('SMS 인증 요청 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 인증 코드 확인
  /// [phoneNumber]와 [code]를 사용하여 인증 코드를 확인합니다.
  ///
  /// Parameters:
  ///   - [phoneNumber]: 인증할 전화번호 (String)
  ///   - [code]: 인증 코드 (String)
  ///
  /// Returns: 확인 성공 여부
  ///   - true: 확인 성공
  ///   - false: 확인 실패

  Future<bool> verifySmsCode(String phoneNumber, String code) async {
    final normalizedPhoneNumber = phoneNumber.trim();
    final normalizedCode = code.trim();

    _setLoading(true);
    _clearError();

    try {
      final result = await _userService.verifySmsCode(
        normalizedPhoneNumber,
        normalizedCode,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('인증 코드 확인 실패: $e');
      _setLoading(false);
      return false;
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

    _setLoading(true);
    _clearError();

    try {
      final user = await _userService.login(
        nickName: normalizedNickname,
        phoneNum: normalizedPhoneNumber,
      );
      _currentUser = user;

      // 로그인 성공 시 상태 저장
      if (user != null) {
        await saveLoginState(userId: user.id, phoneNumber: user.phoneNumber);
      } else {
        debugPrint('[UserController.login] 로그인 실패 code=404');
      }

      _setLoading(false);
      notifyListeners();
      return user;
    } on NotFoundException catch (e) {
      debugPrint(
        '[UserController.login] 로그인 실패 code=${e.statusCode ?? 404}, message=${e.message}',
      );
      _currentUser = null;
      _setLoading(false);
      notifyListeners();
      return null;
    } on SoiApiException catch (e) {
      debugPrint(
        '[UserController.login] 로그인 실패 code=${e.statusCode ?? 'unknown'}, message=${e.message}',
      );
      _setError('로그인 실패: $e');
      _setLoading(false);
      rethrow;
    } catch (e) {
      debugPrint('[UserController.login] 로그인 실패 code=unknown, error=$e');
      final wrapped = SoiApiException(
        message: '로그인 실패: $e',
        originalException: e,
      );
      _setError(wrapped.message);
      _setLoading(false);
      throw wrapped;
    }
  }

  /// 로그아웃
  /// 현재 로그인된 사용자를 로그아웃 처리합니다.

  Future<void> logout() async {
    _currentUser = null;
    _clearError();

    // 저장된 로그인 상태도 삭제
    await clearLoginState();
    notifyListeners();
  }

  /// 현재 사용자 정보 갱신

  Future<void> refreshCurrentUser() async {
    if (!SoiApiClient.instance.isAuthenticated) return;

    _setLoading(true);
    try {
      final user = await _userService.getCurrentUser();
      _currentUser = user;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('사용자 정보 갱신 실패: $e');
      _setLoading(false);
    }
  }

  /// 현재 사용자 설정 (외부에서 직접 설정 필요 시)
  void setCurrentUser(User? user) {
    _currentUser = user;
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
  ///   - [serviceAgreed]: 서비스 이용약관 동의 여부 (기본값: true)
  ///   - [privacyPolicyAgreed]: 개인정보 처리방침 동의 여부 (기본값: true)
  ///   - [marketingAgreed]: 마케팅 정보 수신 동의 여부 (기본값: false)
  ///
  /// Returns: 생성된 사용자 정보 (User)
  ///   - null: 생성 실패

  Future<User?> createUser({
    required String name,
    required String nickName,
    required String phoneNum,
    required String birthDate,
    String? profileImageKey,
    bool serviceAgreed = true,
    bool privacyPolicyAgreed = true,
    bool marketingAgreed = false,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _userService.createUser(
        name: name,
        nickName: nickName,
        phoneNum: phoneNum,
        birthDate: birthDate,
        profileImageKey: profileImageKey,
        serviceAgreed: serviceAgreed,
        privacyPolicyAgreed: privacyPolicyAgreed,
        marketingAgreed: marketingAgreed,
      );

      final authenticatedUser = await _authenticateAfterSignup(
        phoneNum: phoneNum,
        nickName: nickName,
      );
      if (authenticatedUser == null) {
        throw const AuthException(message: '회원가입 후 로그인에 실패했습니다.');
      }

      _currentUser = authenticatedUser;
      await saveLoginState(userId: authenticatedUser.id, phoneNumber: phoneNum);
      notifyListeners();
      _setLoading(false);
      return authenticatedUser;
    } catch (e) {
      _currentUser = null;
      await clearLoginState();
      _setError('사용자 생성 실패: $e');
      _setLoading(false);
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
    _setLoading(true);
    _clearError();

    try {
      final user = await _userService.getUser(id);
      _setLoading(false);
      return user;
    } catch (e) {
      _setError('사용자 조회 실패: $e');
      _setLoading(false);
      return null;
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
    _setLoading(true);
    _clearError();

    try {
      final users = await _userService.getAllUsers();
      _setLoading(false);
      return users;
    } catch (e) {
      _setError('사용자 목록 조회 실패: $e');
      _setLoading(false);
      return [];
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
    _setLoading(true);
    _clearError();

    try {
      final users = await _userService.findUsersByKeyword(keyword);
      _setLoading(false);
      return users;
    } catch (e) {
      _setError('사용자 검색 실패: $e');
      _setLoading(false);
      return [];
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
    _setLoading(true);
    _clearError();

    try {
      final isAvailable = await _userService.checknickNameAvailable(nickName);
      _setLoading(false);
      return isAvailable;
    } catch (e) {
      _setError('ID 중복 확인 실패: $e');
      _setLoading(false);
      return false;
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
    _setLoading(true);
    _clearError();

    try {
      if (nickName != null && isForbiddenUsername(nickName)) {
        _setError('This username is not allowed. Please choose another.');
        _setLoading(false);
        return null;
      }
      final user = await _userService.updateUser(
        id: id,
        name: name,
        nickName: nickName,
        phoneNum: phoneNum,
        birthDate: birthDate,
        profileImageKey: profileImageKey,
      );
      _setLoading(false);
      return user;
    } catch (e) {
      _setError('사용자 정보 수정 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  /// 사용자의 프로필 이미지를 업데이트합니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  /// - [profileImageKey]: 프로필 이미지 키
  ///
  /// Returns: 수정된 사용자 정보 (User)
  Future<User?> updateprofileImageUrl({
    required int userId,
    required String profileImageKey,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _userService.updateProfileImage(
        userId: userId,
        profileImageKey: profileImageKey,
      );
      _setLoading(false);
      return user;
    } catch (e) {
      _setError('프로필 이미지 수정 실패: $e');
      _setLoading(false);
      return null;
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
    _setLoading(true);
    _clearError();

    try {
      final user = await _userService.deleteUser(id);
      _currentUser = null;
      await clearLoginState();
      _setLoading(false);
      notifyListeners();
      return user;
    } catch (e) {
      _setError('사용자 삭제 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
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

      await prefs.setBool(_keyIsLoggedIn, hasAccessToken);
      await prefs.setInt(_keynickName, userId);
      await prefs.setString(_keyPhoneNumber, phoneNumber);
      if (hasAccessToken) {
        await prefs.setString(_keyAccessToken, effectiveAccessToken);
      } else {
        await prefs.remove(_keyAccessToken);
      }
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

      final nickName = prefs.getInt(_keynickName);
      final phoneNumber = prefs.getString(_keyPhoneNumber);
      final accessToken = prefs.getString(_keyAccessToken);

      if (nickName == null) {
        return null;
      }

      return {
        'nickName': nickName,
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
      debugPrint('[UserController] 자동 로그인 시도...');

      final savedInfo = await getSavedUserInfo();
      if (savedInfo == null) {
        debugPrint('[UserController] 저장된 로그인 정보 없음');
        return false;
      }

      final nickName = savedInfo['nickName'] as int;
      final accessToken = savedInfo['accessToken'] as String?;
      debugPrint('[UserController] 저장된 nickName: $nickName');

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('[UserController] 저장된 JWT 토큰 없음');
        await clearLoginState();
        return false;
      }

      SoiApiClient.instance.setAuthToken(accessToken);

      // 서버에서 현재 사용자 정보 조회
      final user = await _userService.getCurrentUser();
      _currentUser = user;
      notifyListeners();
      debugPrint('[UserController] 자동 로그인 성공: ${user.name}');
      return true;
    } catch (e) {
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
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keynickName);
      await prefs.remove(_keyPhoneNumber);
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyOnboardingCompleted);
      debugPrint('[UserController] 로그인 상태 삭제 완료');
    } catch (e) {
      debugPrint('[UserController] 로그인 상태 삭제 실패: $e');
    }
  }
}
