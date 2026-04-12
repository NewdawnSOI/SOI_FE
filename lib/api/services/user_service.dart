import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../models/models.dart';
import '../../utils/firebase_phone_auth_service.dart';

/// 사용자 및 인증 관련 API 래퍼 서비스
///
/// SMS 인증, 로그인, 사용자 생성/조회/수정/삭제 등 사용자 관련 기능을 제공합니다.
/// Provider를 통해 주입받아 사용합니다.
///
/// 사용 예시:
/// ```dart
/// final userService = Provider.of<UserService>(context, listen: false);
///
/// // SMS 인증 발송
/// final success = await userService.sendSmsVerification('01012345678');
///
/// // 인증 코드 확인
/// final verified = await userService.verifySmsCode('01012345678', '123456');
///
/// // 전화번호 로그인
/// final user = await userService.loginByPhone('01012345678');
///
/// // 사용자 생성
/// final user = await userService.createUser(
///   name: '홍길동',
///   nickName: 'hong123',
///   phoneNum: '01012345678',
///   birthDate: '1990-01-01',
/// );
///
/// // 사용자 조회
/// final user = await userService.getUser(1);
///
/// // 사용자 ID 중복 확인
/// final isAvailable = await userService.checknickNameAvailable('hong123');
/// ```
class UserService {
  /// JWT 인증 없이 사용하는 API 인스턴스 (SMS 인증, 사용자 생성 등)
  ///
  /// 기본적으로는 SoiApiClient의 createUnauthenticatedAuthApi를 사용하지만,
  /// 필요에 따라 커스텀 구현을 주입할 수 있도록 설계되었습니다.
  final AuthControllerApi Function() _buildUnauthenticatedAuthApi;

  /// 인증된 API 인스턴스 (JWT 토큰 포함)
  /// 기본적으로 SoiApiClient의 userApi를 사용하지만, 필요에 따라 커스텀 구현을 주입할 수 있도록 설계되었습니다.
  final UserAPIApi _userApi;

  /// Firebase 기반 전화번호 인증 상태를 유지하는 단일 서비스 인스턴스입니다.
  final FirebasePhoneVerificationService _phoneVerificationService;

  /// 로그인/재발급 응답 전체를 현재 인증 세션으로 반영합니다.
  final void Function(LoginRespDto loginResponse) _applyAuthSession;

  /// 기존 테스트와 레거시 호출부가 access token만 관찰할 수 있게 유지하는 알림 콜백입니다.
  final void Function(String token)? _notifyAccessTokenIssued;

  /// 인증 토큰 제거 콜백
  final void Function() _clearAuthSession;

  // 생성자
  UserService({
    AuthControllerApi? authApi,
    UserAPIApi? userApi,
    AuthControllerApi Function()? buildUnauthenticatedAuthApi,
    FirebasePhoneVerificationService? phoneVerificationService,
    void Function(LoginRespDto loginResponse)? onAuthSessionIssued,
    void Function(String token)? onAuthTokenIssued,
    void Function()? onAuthTokenCleared,
  }) : _buildUnauthenticatedAuthApi =
           buildUnauthenticatedAuthApi ??
           (() =>
               authApi ?? SoiApiClient.instance.createUnauthenticatedAuthApi()),
       _userApi = userApi ?? SoiApiClient.instance.userApi,
       _phoneVerificationService =
           phoneVerificationService ?? FirebasePhoneVerificationService(),
       _applyAuthSession =
           onAuthSessionIssued ?? SoiApiClient.instance.applyLoginResponse,
       _notifyAccessTokenIssued = onAuthTokenIssued,
       _clearAuthSession =
           onAuthTokenCleared ?? SoiApiClient.instance.clearAuthSession;

  /// 회원가입 화면이 Firebase 즉시 인증 완료 여부를 조회할 수 있게 현재 상태를 노출합니다.
  bool get isPhoneNumberVerified =>
      _phoneVerificationService.isCurrentPhoneVerified;

  /// 전화번호 인증 채널이 바뀌어도 이전 Firebase verification 상태가 재사용되지 않게 비웁니다.
  void resetPhoneVerificationState() {
    _phoneVerificationService.reset();
  }

  /// 인증 API 호출의 단계와 상태만 debug 로그로 남겨 실제 실패 지점을 좁힙니다.
  void _debugLogAuthStage(
    String stage, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    if (!kDebugMode) return;

    final payload = details.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    final suffix = payload.isEmpty ? '' : ', $payload';
    debugPrint('[UserService.auth] stage=$stage$suffix');
  }

  /// 인증 흐름 예외를 status와 타입 중심으로 축약해 debug 로그로 남깁니다.
  void _debugLogAuthError(String stage, Object error) {
    if (!kDebugMode) return;

    if (error is ApiException) {
      debugPrint(
        '[UserService.auth] stage=$stage, errorType=ApiException, status=${error.code}, message=${error.message}',
      );
      return;
    }

    if (error is SoiApiException) {
      debugPrint(
        '[UserService.auth] stage=$stage, errorType=${error.runtimeType}, status=${error.statusCode}, message=${error.message}',
      );
      return;
    }

    debugPrint(
      '[UserService.auth] stage=$stage, errorType=${error.runtimeType}, error=$error',
    );
  }

  /// 텍스트 정규화 (공백 제거)
  /// 사용자 입력에서 불필요한 공백을 제거하여 API 요청에 사용하기 적합한 형태로 변환합니다.
  String _normalizeText(String value) => value.trim();

  /// 선택적 텍스트 정규화 (공백 제거)
  /// 사용자 입력에서 불필요한 공백을 제거하여 API 요청에 사용하기 적합한 형태로 변환합니다.
  /// null 또는 공백만 있는 경우 null을 반환하여, API 요청 시 해당 필드를 생략할 수 있도록 합니다.
  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized; // null이 아닌 경우, 정규화된 텍스트 반환
  }

  /// 선택적 문자열을 API 직렬화용 빈 문자열 규칙으로 정규화합니다.
  /// 서버에 null 대신 빈 문자열을 보내야 하는 회원가입/프로필 필드에 사용합니다.
  String _normalizeOptionalTextOrEmpty(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return '';
    }
    return normalized;
  }

  /// 로그인 요청 DTO를 phone-only 생성 계약에 맞춰 정규화합니다.
  /// 레거시 호출부의 nickName은 호환을 위해 받되 요청 본문에는 포함하지 않습니다.
  LoginReqDto _buildLoginRequest({String? nickName, String? phoneNum}) {
    final normalizedPhoneNum = _normalizeOptionalText(phoneNum);

    if (normalizedPhoneNum == null) {
      throw const BadRequestException(message: '전화번호를 입력해야 합니다.');
    }

    return LoginReqDto(phoneNum: normalizedPhoneNum);
  }

  /// 액세스 토큰을 로그인 응답에서 추출하여 반환하는 헬퍼 함수입니다.
  String _requireAccessToken(LoginRespDto loginResponse) {
    // 로그인 응답에서 액세스 토큰을 추출하여 반환합니다.
    final accessToken = loginResponse.accessToken?.trim();
    if (accessToken == null || accessToken.isEmpty) {
      throw const DataValidationException(message: '인증 토큰이 없습니다.');
    }
    return accessToken;
  }

  // ============================================
  // SMS 인증
  // ============================================

  /// SMS 인증 코드 발송
  ///
  /// [phoneNum]으로 SMS 인증 코드를 발송합니다.
  /// 한국 번호는 서버 API를, 그 외 번호는 Firebase를 타도록 상위 레이어가 선택할 수 있습니다.
  /// 성공 시 true 반환, 실패 시 예외를 throw합니다.
  ///
  /// Parameters:
  /// - [phoneNum]: 인증할 전화번호
  ///
  /// Returns:
  /// - [bool]: true - SMS 발송 성공
  /// - [bool]: false - SMS 발송 실패 (예: API에서 false 반환)
  Future<bool> sendSmsVerification(
    String phoneNum, {
    bool useFirebase = true,
  }) async {
    try {
      final normalizedPhoneNum = _normalizeText(phoneNum);
      if (useFirebase) {
        return await _phoneVerificationService.sendVerificationCode(
          normalizedPhoneNum,
        );
      }

      final result = await _buildUnauthenticatedAuthApi().authSMS(
        normalizedPhoneNum,
      );
      return result ?? false;
    } on SoiApiException {
      rethrow;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      throw SoiApiException(message: 'SMS 인증 발송 실패: $e', originalException: e);
    }
  }

  /// SMS 인증 코드 확인
  /// [phoneNum]과 [code]를 함께 전달하여 인증 코드를 확인합니다.
  /// 한국 번호는 서버 API를, 그 외 번호는 Firebase를 타도록 상위 레이어가 선택할 수 있습니다.
  ///
  /// parameters:
  /// - [phoneNum]: 인증할 전화번호
  /// - [code]: 사용자에게 발송된 인증 코드
  ///
  /// returns:
  /// - [bool]: true - 인증 성공
  /// - [bool]: false - 인증 실패 (코드 불일치)
  Future<bool> verifySmsCode(
    String phoneNum,
    String code, {
    bool useFirebase = true,
  }) async {
    try {
      final normalizedPhoneNum = _normalizeText(phoneNum);
      final normalizedCode = _normalizeText(code);
      if (useFirebase) {
        return await _phoneVerificationService.verifyCode(
          normalizedPhoneNum,
          normalizedCode,
        );
      }

      final dto = AuthCheckReqDto(
        phoneNum: normalizedPhoneNum,
        code: normalizedCode,
      );
      final result = await _buildUnauthenticatedAuthApi().checkAuthSMS(dto);
      return result ?? false;
    } on SoiApiException {
      rethrow;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      throw SoiApiException(message: '인증 코드 확인 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 로그인
  // ============================================

  /// 레거시 수동 로그인 호출부를 현재 phone-only 인증 계약으로 연결합니다.
  /// 생성된 로그인 DTO가 `phoneNum`만 받으므로 [nickName]은 더 이상 전송하지 않습니다.
  /// 성공 시 사용자 정보(User) 반환, 실패 시 예외를 throw합니다.
  ///
  /// 반환값:
  /// - 기존 회원: User (사용자 정보)
  /// - 신규 회원: null (회원가입 필요)
  ///
  /// Throws:
  /// - [NetworkException]: 네트워크 연결 실패
  /// - [NotFoundException]: 등록되지 않은 사용자
  /// - [SoiApiException]: 기타 API 에러
  Future<User?> login({String? nickName, String? phoneNum}) async {
    final normalizedNickName = _normalizeOptionalText(nickName);
    final dto = _buildLoginRequest(nickName: nickName, phoneNum: phoneNum);
    _debugLogAuthStage(
      'manual-login.request-built',
      details: <String, Object?>{
        'legacyNicknameProvided': normalizedNickName != null,
        'phoneLength': dto.phoneNum?.length,
      },
    );

    try {
      return await _login(dto);
    } on ApiException catch (e) {
      _debugLogAuthError('manual-login.api-exception', e);
      debugPrint(
        '[UserService.login] API 예외 code=${e.code}, message=${e.message}',
      );

      if (e.code == 404) {
        debugPrint('[UserService.login] 로그인 실패 code=404');
        return null;
      }
      throw _handleApiException(e);
    } on SocketException catch (e) {
      _debugLogAuthError('manual-login.socket-exception', e);
      debugPrint('[UserService.login] 로그인 실패 code=network, error=$e');
      throw NetworkException(originalException: e);
    } on SoiApiException catch (e) {
      _debugLogAuthError('manual-login.soi-api-exception', e);
      debugPrint(
        '[UserService.login] 로그인 실패 code=${e.statusCode ?? 'unknown'}, message=${e.message}',
      );
      rethrow;
    } catch (e) {
      _debugLogAuthError('manual-login.unknown-exception', e);
      debugPrint('[UserService.login] 로그인 실패 code=unknown, error=$e');
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '로그인 실패: $e', originalException: e);
    }
  }

  /// 생성 계약의 `/auth/login` 엔드포인트를 전화번호만으로 호출합니다.
  /// SMS 인증을 마친 기존 로그인 화면과 회원가입 직후 재인증 흐름의 기본 진입점입니다.
  ///
  /// SMS 인증이 완료된 전화번호로만 로그인합니다. 닉네임 없이 전화번호만 사용합니다.
  ///
  /// 반환값:
  /// - 기존 회원: User (사용자 정보)
  /// - 미가입: null
  Future<User?> loginByPhone(String phoneNum) async {
    final dto = _buildLoginRequest(phoneNum: phoneNum);
    _debugLogAuthStage(
      'login-by-phone.request-built',
      details: <String, Object?>{'phoneLength': dto.phoneNum?.length},
    );

    try {
      return await _login(dto);
    } on ApiException catch (e) {
      _debugLogAuthError('login-by-phone.api-exception', e);
      debugPrint(
        '[UserService.loginByPhone] API 예외 code=${e.code}, message=${e.message}',
      );
      if (e.code == 404) {
        debugPrint('[UserService.loginByPhone] 로그인 실패 code=404');
        return null;
      }
      throw _handleApiException(e);
    } on SocketException catch (e) {
      _debugLogAuthError('login-by-phone.socket-exception', e);
      debugPrint('[UserService.loginByPhone] 로그인 실패 code=network, error=$e');
      throw NetworkException(originalException: e);
    } on SoiApiException catch (e) {
      _debugLogAuthError('login-by-phone.soi-api-exception', e);
      rethrow;
    } catch (e) {
      _debugLogAuthError('login-by-phone.unknown-exception', e);
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '로그인 실패: $e', originalException: e);
    }
  }

  /// refresh token으로 access/refresh 토큰을 함께 재발급받아 현재 세션으로 반영합니다.
  Future<LoginSession> refreshSession(String refreshToken) async {
    final normalizedRefreshToken = _normalizeText(refreshToken);
    if (normalizedRefreshToken.isEmpty) {
      throw const BadRequestException(message: 'refresh token이 필요합니다.');
    }

    try {
      final response = await _buildUnauthenticatedAuthApi().refresh(
        RefreshTokenReqDto(refreshToken: normalizedRefreshToken),
      );
      if (response == null) {
        throw const DataValidationException(message: '토큰 재발급 응답이 없습니다.');
      }

      final session = LoginSession.fromDto(response);
      _applyAuthSession(response);
      _notifyAccessTokenIssued?.call(session.accessToken);
      return session;
    } on ApiException catch (e) {
      _debugLogAuthError('refresh-session.api-exception', e);
      throw _handleApiException(e);
    } on SocketException catch (e) {
      _debugLogAuthError('refresh-session.socket-exception', e);
      throw NetworkException(originalException: e);
    } on SoiApiException catch (e) {
      _debugLogAuthError('refresh-session.soi-api-exception', e);
      rethrow;
    } catch (e) {
      _debugLogAuthError('refresh-session.unknown-exception', e);
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '토큰 재발급 실패: $e', originalException: e);
    }
  }

  /// refresh token 기반 서버 로그아웃을 호출해 세션을 더 이상 재사용하지 않도록 종료합니다.
  Future<bool> logout(String refreshToken) async {
    final normalizedRefreshToken = _normalizeText(refreshToken);
    if (normalizedRefreshToken.isEmpty) {
      throw const BadRequestException(message: 'refresh token이 필요합니다.');
    }

    try {
      final response = await _buildUnauthenticatedAuthApi().logout(
        RefreshTokenReqDto(refreshToken: normalizedRefreshToken),
      );
      if (response == null) {
        return false;
      }
      return response.success == true && (response.data ?? false);
    } on ApiException catch (e) {
      _debugLogAuthError('logout.api-exception', e);
      throw _handleApiException(e);
    } on SocketException catch (e) {
      _debugLogAuthError('logout.socket-exception', e);
      throw NetworkException(originalException: e);
    } on SoiApiException catch (e) {
      _debugLogAuthError('logout.soi-api-exception', e);
      rethrow;
    } catch (e) {
      _debugLogAuthError('logout.unknown-exception', e);
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '로그아웃 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 사용자 생성
  // ============================================

  /// 새 사용자 생성 (회원가입)
  ///
  /// 필수 정보를 입력받아 새 사용자를 생성합니다.
  ///
  /// Parameters:
  /// - [name]: 사용자 이름
  /// - [nickName]: 사용자 아이디 (고유)
  /// - [phoneNum]: 전화번호
  /// - [birthDate]: 생년월일 (yyyy-MM-dd 형식)
  /// - [profileImageKey]: 프로필 이미지 키 (선택)
  /// - [profileCoverImageKey]: 프로필 커버 이미지 키 (선택)
  /// - [serviceAgreed]: 서비스 약관 동의 여부
  /// - [privacyPolicyAgreed]: 개인정보 처리방침 동의 여부
  /// - [marketingAgreed]: 마케팅 수신 동의 여부 (선택)
  ///
  /// Returns: 생성된 사용자 정보 (User)
  ///
  /// Throws:
  /// - [BadRequestException]: 필수 정보 누락 또는 잘못된 형식
  /// - [SoiApiException]: 이미 존재하는 아이디/전화번호
  Future<User> createUser({
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
    _debugLogAuthStage(
      'signup.request-building',
      details: <String, Object?>{
        'nameLength': name.trim().length,
        'nicknameLength': nickName.trim().length,
        'phoneLength': phoneNum.trim().length,
        'birthDateLength': birthDate.trim().length,
        'hasProfileImageKey': profileImageKey?.trim().isNotEmpty ?? false,
        'hasProfileCoverImageKey':
            profileCoverImageKey?.trim().isNotEmpty ?? false,
        'serviceAgreed': serviceAgreed,
        'privacyPolicyAgreed': privacyPolicyAgreed,
        'marketingAgreed': marketingAgreed,
      },
    );
    try {
      final dto = UserCreateReqDto(
        name: _normalizeText(name),
        nickname: _normalizeText(nickName),
        phoneNum: _normalizeText(phoneNum),
        birthDate: _normalizeText(birthDate),
        profileImageKey: _normalizeOptionalTextOrEmpty(profileImageKey),
        profileCoverImageKey: _normalizeOptionalTextOrEmpty(
          profileCoverImageKey,
        ),
      );

      final createUserDto = UserCreateReqDto(
        name: dto.name,
        nickname: dto.nickname,
        phoneNum: dto.phoneNum,
        birthDate: dto.birthDate,
        profileImageKey: dto.profileImageKey,
        profileCoverImageKey: dto.profileCoverImageKey,
        serviceAgreed: serviceAgreed,
        privacyPolicyAgreed: privacyPolicyAgreed,
        marketingAgreed: marketingAgreed,
      );

      // 인증 없이 사용자 생성 API를 호출하기 위해 별도의 AuthControllerApi 인스턴스를 생성합니다.
      // user를 생성하는 API는 인증이 필요하지 않으므로,
      // SoiApiClient의 createUnauthenticatedAuthApi를 사용하여 인증 없이 호출합니다.
      _debugLogAuthStage(
        'signup.request-built',
        details: <String, Object?>{
          'nameLength': createUserDto.name?.length,
          'nicknameLength': createUserDto.nickname?.length,
          'phoneLength': createUserDto.phoneNum?.length,
          'birthDateLength': createUserDto.birthDate?.length,
          'profileImageKeyLength': createUserDto.profileImageKey?.length,
          'profileCoverImageKeyLength':
              createUserDto.profileCoverImageKey?.length,
        },
      );
      final response = await _buildUnauthenticatedAuthApi().createUser(
        createUserDto,
      );
      _debugLogAuthStage(
        'signup.response',
        details: <String, Object?>{
          'hasResponse': response != null,
          'success': response?.success,
          'hasData': response?.data != null,
        },
      );

      if (response == null) {
        throw const DataValidationException(message: '사용자 생성 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 생성 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '생성된 사용자 정보가 없습니다.');
      }

      return User.fromDto(response.data!);
    } on ApiException catch (e) {
      _debugLogAuthError('signup.api-exception', e);
      throw _handleApiException(e);
    } on SocketException catch (e) {
      _debugLogAuthError('signup.socket-exception', e);
      throw NetworkException(originalException: e);
    } on SoiApiException catch (e) {
      _debugLogAuthError('signup.soi-api-exception', e);
      rethrow;
    } catch (e) {
      _debugLogAuthError('signup.unknown-exception', e);
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 생성 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 사용자 조회
  // ============================================

  /// JWT 토큰 기준 현재 사용자 조회
  Future<User> getCurrentUser() async {
    _debugLogAuthStage(
      'user-get.request',
      details: <String, Object?>{
        'isAuthenticated': SoiApiClient.instance.isAuthenticated,
      },
    );
    try {
      final response = await _userApi.getUser();
      _debugLogAuthStage(
        'user-get.response',
        details: <String, Object?>{
          'hasResponse': response != null,
          'success': response?.success,
          'hasData': response?.data != null,
        },
      );

      if (response == null) {
        throw const NotFoundException(message: '사용자를 찾을 수 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 조회 실패');
      }

      if (response.data == null) {
        throw const NotFoundException(message: '사용자 정보가 없습니다.');
      }

      final user = User.fromDto(response.data!);
      _debugLogAuthStage(
        'user-get.mapped',
        details: <String, Object?>{
          'hasProfileImageUrl': user.profileImageUrl?.isNotEmpty ?? false,
          'hasCoverImageKey': user.profileCoverImageKey?.isNotEmpty ?? false,
        },
      );
      return user;
    } on ApiException catch (e) {
      _debugLogAuthError('user-get.api-exception', e);
      throw _handleApiException(e);
    } on SocketException catch (e) {
      _debugLogAuthError('user-get.socket-exception', e);
      throw NetworkException(originalException: e);
    } catch (e) {
      _debugLogAuthError('user-get.unknown-exception', e);
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 조회 실패: $e', originalException: e);
    }
  }

  /// ID로 사용자 조회
  ///
  /// [id]에 해당하는 사용자 정보를 조회합니다.
  ///
  /// Returns: 사용자 정보 (User)
  ///
  /// Throws:
  /// - [NotFoundException]: 해당 ID의 사용자가 없음
  Future<User> getUser(int id) async {
    if (SoiApiClient.instance.isAuthenticated) {
      final currentUser = await getCurrentUser();
      if (currentUser.id == id) {
        return currentUser;
      }
    }

    final users = await getAllUsers();
    for (final user in users) {
      if (user.id == id) {
        return user;
      }
    }

    throw const NotFoundException(message: '사용자를 찾을 수 없습니다.');
  }

  /// 모든 사용자 조회
  ///
  /// 등록된 모든 사용자 목록을 조회합니다.
  /// (주의: 대량 데이터 조회 시 성능 이슈 가능)
  ///
  /// Returns: 사용자 목록 (`List<User>`)
  Future<List<User>> getAllUsers() async {
    try {
      final response = await _userApi.getAllUsers();

      if (response == null) {
        return [];
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 목록 조회 실패');
      }

      return response.data.map((dto) => User.fromFindDto(dto)).toList();
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 목록 조회 실패: $e', originalException: e);
    }
  }

  /// 키워드로 사용자 검색
  ///
  /// [keyword]가 포함된 nickName를 가진 사용자를 검색합니다.
  ///
  /// Returns: 검색된 사용자 목록 (`List<User>`)
  Future<List<User>> findUsersByKeyword(String keyword) async {
    try {
      // 키워드 정규화
      final response = await _userApi.findUser(_normalizeText(keyword));

      if (response == null) {
        return [];
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 검색 실패');
      }

      return response.data.map((dto) => User.fromDto(dto)).toList();
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 검색 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 사용자 ID 중복 확인
  // ============================================

  /// 사용자 ID 중복 확인
  ///
  /// [nickName]가 사용 가능한지 확인합니다.
  ///
  /// Returns:
  /// - true: 사용 가능
  /// - false: 이미 사용 중 (중복)
  Future<bool> checknickNameAvailable(String nickName) async {
    try {
      // 닉네임 정규화
      final normalizedNickName = _normalizeText(nickName);

      // 인증 없이 ID 중복 확인 API를 호출하기 위해 별도의 UserAPIApi 인스턴스를 생성합니다.
      // ID 중복 확인 API는 인증이 필요하지 않으므로,
      // SoiApiClient의 createUnauthenticatedAuthApi를 사용하여 인증 없이 호출합니다.
      final response = await _buildUnauthenticatedAuthApi().idCheck(
        normalizedNickName,
      );

      if (response == null) {
        return false;
      }

      if (response.success != true) {
        return false;
      }

      return response.data ?? false;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: 'ID 중복 확인 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 사용자 정보 수정
  // ============================================

  /// 사용자 정보 수정
  /// 사용자의 기본 정보를 수정합니다.
  /// 보안을 위해, JWT 인증된 사용자와 요청 대상 사용자가 일치하는지 확인합니다([_ensureCurrentUserMatches]).
  ///
  /// Parameters:
  /// - [id]: 사용자 고유 ID
  /// - [name]: 변경할 이름 (선택)
  /// - [nickName]: 변경할 아이디 (선택)
  /// - [phoneNum]: 변경할 전화번호 (선택)
  /// - [birthDate]: 변경할 생년월일 (선택)
  /// - [profileImageKey]: 변경할 프로필 이미지 키 (선택)
  ///
  /// Returns: 수정된 사용자 정보 (User)
  ///
  /// Throws:
  /// - [ForbiddenException]: JWT 인증 사용자와 요청 대상 사용자가 일치하지 않는 경우
  /// - [DataValidationException]: 응답 데이터가 예상과 다른 경우 (예: null)
  /// - [SoiApiException]: 기타 API 에러
  /// - [NetworkException]: 네트워크 연결 실패
  Future<User> updateUser({
    required int id,
    String? name,
    String? nickName,
    String? phoneNum,
    String? birthDate,
    String? profileImageKey,
  }) async {
    try {
      // 보안을 위해 현재 인증된 사용자와 요청 대상 사용자가 일치하는지 확인합니다.
      await _ensureCurrentUserMatches(id);

      // 사용자 정보 수정을 위한 DTO 객체를 생성합니다.
      // parameter로 전달된 값 중 null이 아닌 값만 DTO에 포함하여 API에 전송합니다.
      final dto = UserUpdateReqDto(
        name: name,
        nickname: nickName,
        phoneNum: phoneNum,
        birthDate: birthDate,
        profileImageKey: profileImageKey,
      );

      // 사용자 정보 수정 API를 호출하여 응답을 받습니다.
      final response = await _userApi.update1(dto);

      if (response == null) {
        throw const DataValidationException(message: '사용자 수정 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 정보 수정 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '수정된 사용자 정보가 없습니다.');
      }

      return User.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 정보 수정 실패: $e', originalException: e);
    }
  }

  /// 프로필 이미지 수정
  ///
  /// 현재 인증된 사용자 프로필 이미지를 업데이트합니다.
  ///
  /// Parameters:
  /// - [profileImageKey]: 새 프로필 이미지 키
  ///
  /// Returns: 수정된 사용자 정보 (User)
  ///
  /// Throws:
  /// - [DataValidationException]: 응답 데이터가 예상과 다른 경우 (예: null)
  /// - [SoiApiException]: 기타 API 에러
  /// - [NetworkException]: 네트워크 연결 실패
  Future<User> updateProfile({String? profileImageKey}) async {
    try {
      final response = await _userApi.updateProfile(
        profileImageKey: profileImageKey,
      );

      if (response == null) {
        throw const DataValidationException(message: '프로필 수정 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '프로필 이미지 수정 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '수정된 사용자 정보가 없습니다.');
      }

      return User.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '프로필 이미지 수정 실패: $e', originalException: e);
    }
  }

  /// 프로필 이미지 수정
  /// [userId]의 프로필 이미지를 [profileImageKey] URL로 수정합니다.
  ///
  /// Parameters:
  /// - [userId]
  ///   - 프로필 이미지를 수정할 사용자 ID
  ///   - 보안을 위해, JWT 인증된 사용자와 [userId]가 일치하는지 확인합니다.
  /// - [profileImageKey]: 새 프로필 이미지 URL
  ///
  /// Returns: 수정된 사용자 정보 (User)
  ///
  /// Throws:
  /// - [ForbiddenException]: JWT 인증 사용자와 요청 대상 사용자가 일치하지 않는 경우
  /// - [SoiApiException]: 기타 API 에러
  Future<User> updateProfileImage({
    required int userId,
    required String profileImageKey,
  }) async {
    try {
      // 보안을 위해 현재 인증된 사용자와 요청 대상 사용자가 일치하는지 확인합니다.
      await _ensureCurrentUserMatches(userId);
      return updateProfile(profileImageKey: profileImageKey);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '프로필 이미지 수정 실패: $e', originalException: e);
    }
  }

  /// 커버 이미지 수정
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID (현재 인증된 사용자와 일치해야 함)
  /// - [coverImageKey]: 새 커버 이미지 키
  ///
  /// Returns: 수정된 사용자 정보 (User)
  Future<User> updateCoverImage({
    required int userId,
    required String coverImageKey,
  }) async {
    try {
      // 보안을 위해 현재 인증된 사용자와 요청 대상 사용자가 일치하는지 확인합니다.
      await _ensureCurrentUserMatches(userId);

      // 사용자 정보 수정을 위한 API 호출을 수행합니다.
      // response는 API 응답 객체로, ApiResponseDtoUserRespDto를 받습니다.
      final response = await _userApi.updateCoverImage(
        coverImageKey: coverImageKey,
      );
      if (response == null) {
        throw const DataValidationException(message: '커버 이미지 수정 응답이 없습니다.');
      }
      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '커버 이미지 수정 실패');
      }
      if (response.data == null) {
        throw const DataValidationException(message: '수정된 사용자 정보가 없습니다.');
      }

      // API 응답에서 수정된 사용자 정보를 User 모델로 변환하여 반환합니다.
      return User.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '커버 이미지 수정 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 사용자 삭제
  // ============================================

  /// 사용자 삭제 (회원탈퇴)
  ///
  /// [id]에 해당하는 사용자를 삭제합니다.
  ///
  /// Returns: 삭제된 사용자 정보 (User)
  ///
  /// Throws:
  /// - [NotFoundException]: 해당 ID의 사용자가 없음
  Future<User> deleteUser(int id) async {
    try {
      final response = await _userApi.deleteUser(id);

      if (response == null) {
        throw const DataValidationException(message: '사용자 삭제 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '사용자 삭제 실패');
      }

      if (response.data == null) {
        throw const DataValidationException(message: '삭제된 사용자 정보가 없습니다.');
      }

      return User.fromDto(response.data!);
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '사용자 삭제 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 에러 핸들링 헬퍼
  // ============================================

  SoiApiException _handleApiException(ApiException e) {
    debugPrint('API Error [${e.code}]: ${e.message}');

    if (_isTransportFailure(e.message)) {
      return NetworkException(
        message: '네트워크 연결을 확인해주세요.',
        originalException: e,
      );
    }

    switch (e.code) {
      case 400:
        return BadRequestException(
          message: e.message ?? '잘못된 요청입니다.',
          originalException: e,
        );
      case 401:
        return AuthException(
          message: e.message ?? '인증이 필요합니다.',
          originalException: e,
        );
      case 403:
        return ForbiddenException(
          message: e.message ?? '접근 권한이 없습니다.',
          originalException: e,
        );
      case 404:
        return NotFoundException(
          message: e.message ?? '사용자를 찾을 수 없습니다.',
          originalException: e,
        );
      case >= 500:
        return ServerException(
          statusCode: e.code,
          message: e.message ?? '서버 오류가 발생했습니다.',
          originalException: e,
        );
      default:
        return SoiApiException(
          statusCode: e.code,
          message: e.message ?? '알 수 없는 오류가 발생했습니다.',
          originalException: e,
        );
    }
  }

  bool _isTransportFailure(String? message) {
    if (message == null) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('socket operation failed') ||
        normalized.contains('tls/ssl communication failed') ||
        normalized.contains('http connection failed') ||
        normalized.contains('i/o operation failed');
  }

  ///
  Future<User?> _login(LoginReqDto dto) async {
    // 로그인 API는 JWT 발급 전 호출하는 인증 API이므로, 인증 없이 호출해야 합니다.
    // SoiApiClient의 createUnauthenticatedAuthApi를 사용하여 인증 없이 호출합니다.
    _debugLogAuthStage('auth-login.request');
    LoginRespDto? loginResponse;
    try {
      loginResponse = await _buildUnauthenticatedAuthApi().login(dto);
    } catch (e) {
      _debugLogAuthError('auth-login.request', e);
      rethrow;
    }
    _debugLogAuthStage(
      'auth-login.response',
      details: <String, Object?>{'hasResponse': loginResponse != null},
    );

    // loginResponse가 null인 경우, return으로 null을 반환하여 로그인 실패를 나타냅니다.
    if (loginResponse == null) {
      return null;
    }

    // loginResponse에서 accessToken을 추출합니다.
    late final String accessToken;
    try {
      accessToken = _requireAccessToken(loginResponse);
    } catch (e) {
      _debugLogAuthError('auth-login.token-parse', e);
      rethrow;
    }
    _debugLogAuthStage(
      'auth-login.token-issued',
      details: <String, Object?>{'tokenLength': accessToken.length},
    );

    // 로그인 응답 전체를 현재 세션으로 적용해 refresh token과 만료 정보도 함께 유지합니다.
    _applyAuthSession(loginResponse);
    _notifyAccessTokenIssued?.call(accessToken);
    _debugLogAuthStage(
      'auth-login.token-applied',
      details: <String, Object?>{
        'isAuthenticated': SoiApiClient.instance.isAuthenticated,
      },
    );

    try {
      _debugLogAuthStage('auth-login.user-get.request');
      final user = await getCurrentUser();
      _debugLogAuthStage(
        'auth-login.user-get.success',
        details: <String, Object?>{
          'hasProfileImageUrl': user.profileImageUrl?.isNotEmpty ?? false,
          'hasCoverImageKey': user.profileCoverImageKey?.isNotEmpty ?? false,
        },
      );
      return user;
    } catch (e) {
      _debugLogAuthError('auth-login.user-get.failure', e);
      _clearAuthSession();
      _debugLogAuthStage('auth-login.token-cleared-after-failure');
      rethrow;
    }
  }

  /// 현재 인증된 사용자와 요청 대상 사용자가 일치하는지 확인합니다.
  /// 현재 인증된 사용자: JWT 토큰에서 추출된 사용자 정보입니다.
  /// 요청 대상 사용자: 수정/삭제하려는 사용자 ID입니다.
  ///
  /// 일치하지 않는 경우, ForbiddenException을 throw하여 권한 오류를 나타냅니다.
  ///
  /// parameters:
  /// - [expectedUserId]: 요청 대상 사용자 ID
  ///
  /// returns:
  /// - 일치하는 경우: void (예외 없이 반환)
  /// - 일치하지 않는 경우: ForbiddenException 예외 throw
  ///
  /// Throws:
  /// - [ForbiddenException]: JWT 인증 사용자와 요청 대상 사용자가 일치하지 않는 경우
  /// - [SoiApiException]: 기타 API 에러
  Future<void> _ensureCurrentUserMatches(int expectedUserId) async {
    // 인증되지 않은 상태에서는 일치 여부를 확인할 수 없으므로,
    // 예외 없이 반환하여 호출한 메서드가 계속 실행되도록 합니다.
    if (!SoiApiClient.instance.isAuthenticated) {
      return;
    }

    final currentUser = await getCurrentUser(); // 현재 인증된 사용자 정보 조회

    // 현재 인증된 사용자의 ID와 요청 대상 사용자 ID가 일치하는지 확인합니다.
    if (currentUser.id == expectedUserId) {
      // 일치하는 경우, 아무 예외 없이 반환하여 호출한 메서드가 계속 실행되도록 합니다.
      return;
    }

    throw const ForbiddenException(
      message: 'JWT 인증 사용자와 요청 대상 사용자가 일치하지 않습니다.',
    );
  }
}
