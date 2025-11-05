/// 사용자 API 서비스
/// UserAPIApi를 래핑하여 Flutter에서 사용하기 쉽게 만든 서비스
library;

import 'dart:developer' as developer;
import 'package:soi_api/api.dart' as api;
import '../common/api_client.dart';
import '../common/api_result.dart';
import '../common/api_exception.dart';

class UserService {
  late final api.UserAPIApi _userApi;

  UserService() {
    _userApi = api.UserAPIApi(SoiApiClient().client);
  }

  /// 전화번호로 SMS 인증 발송
  /// [phone] 전화번호 (예: "01012345678")
  /// Returns: 인증 발송 성공 여부
  Future<ApiResult<bool>> sendAuthSMS(String phone) async {
    try {
      developer.log('SMS 인증 발송: $phone', name: 'UserService');

      final response = await _userApi.authSMS(phone);

      if (response == null) {
        return Failure(ApiException.serverError('인증 발송에 실패했습니다'));
      }

      developer.log('SMS 인증 발송 성공', name: 'UserService');
      return Success(response);
    } on api.ApiException catch (e) {
      developer.log('SMS 인증 발송 실패: ${e.message}', name: 'UserService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log('SMS 인증 발송 오류: $e', name: 'UserService');
      return Failure(ApiException.networkError());
    }
  }

  /// 사용자 생성
  /// 새로운 사용자를 등록합니다.
  Future<ApiResult<api.UserRespDto>> createUser({
    required String name,
    required String userId,
    required String phone,
    required String birthDate,
    String? profileImage,
    required bool serviceAgreed,
    required bool privacyPolicyAgreed,
    required bool marketingAgreed,
  }) async {
    try {
      developer.log('사용자 생성 요청: $userId', name: 'UserService');

      final reqDto = api.UserCreateReqDto(
        name: name,
        userId: userId,
        phone: phone,
        birthDate: birthDate,
        profileImage: profileImage,
        serviceAgreed: serviceAgreed,
        privacyPolicyAgreed: privacyPolicyAgreed,
        marketingAgreed: marketingAgreed,
      );

      final response = await _userApi.createUser(reqDto);

      if (response?.data == null) {
        return Failure(ApiException.serverError('사용자 생성에 실패했습니다'));
      }

      developer.log(
        '사용자 생성 성공: ${response!.data!.userId}',
        name: 'UserService',
      );
      return Success(response.data!);
    } on api.ApiException catch (e) {
      developer.log('사용자 생성 실패: ${e.message}', name: 'UserService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log('사용자 생성 오류: $e', name: 'UserService');
      return Failure(ApiException.networkError());
    }
  }

  /// 전화번호로 로그인
  ///
  /// [phone] 인증이 완료된 전화번호
  Future<ApiResult<api.UserRespDto>> login(String phone) async {
    try {
      developer.log('로그인 요청: $phone', name: 'UserService');

      final response = await _userApi.login(phone);

      if (response?.data == null) {
        return Failure(ApiException.serverError('로그인에 실패했습니다'));
      }

      developer.log('로그인 성공: ${response!.data!.userId}', name: 'UserService');
      return Success(response.data!);
    } on api.ApiException catch (e) {
      developer.log('로그인 실패: ${e.message}', name: 'UserService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log('로그인 오류: $e', name: 'UserService');
      return Failure(ApiException.networkError());
    }
  }

  /// 사용자 ID 중복 체크
  ///
  /// [userId] 확인할 사용자 ID
  /// Returns: 사용 가능하면 true, 중복이면 false
  Future<ApiResult<bool>> checkUserIdDuplicate(String userId) async {
    try {
      developer.log('ID 중복 체크: $userId', name: 'UserService');

      final response = await _userApi.idCheck(userId);

      if (response?.data == null) {
        return Failure(ApiException.serverError('ID 중복 체크에 실패했습니다'));
      }

      final isAvailable = response!.data!;
      developer.log(
        'ID 중복 체크 완료: ${isAvailable ? "사용가능" : "중복"}',
        name: 'UserService',
      );
      return Success(isAvailable);
    } on api.ApiException catch (e) {
      developer.log('ID 중복 체크 실패: ${e.message}', name: 'UserService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log('ID 중복 체크 오류: $e', name: 'UserService');
      return Failure(ApiException.networkError());
    }
  }

  /// 키워드로 사용자 검색
  ///
  /// [keyword] 검색할 사용자 ID 키워드
  Future<ApiResult<List<api.UserRespDto>>> searchUsers(String keyword) async {
    try {
      developer.log('사용자 검색: $keyword', name: 'UserService');

      final response = await _userApi.findUser(keyword);

      if (response?.data == null) {
        return Failure(ApiException.serverError('사용자 검색에 실패했습니다'));
      }

      final users = response!.data;
      developer.log('사용자 검색 완료: ${users.length}명', name: 'UserService');
      return Success(users);
    } on api.ApiException catch (e) {
      developer.log('사용자 검색 실패: ${e.message}', name: 'UserService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log('사용자 검색 오류: $e', name: 'UserService');
      return Failure(ApiException.networkError());
    }
  }

  /// 모든 사용자 조회
  Future<ApiResult<List<api.UserFindRespDto>>> getAllUsers() async {
    try {
      developer.log('모든 사용자 조회', name: 'UserService');

      final response = await _userApi.getAllUsers();

      if (response?.data == null) {
        return Failure(ApiException.serverError('사용자 목록 조회에 실패했습니다'));
      }

      final users = response!.data;
      developer.log('모든 사용자 조회 완료: ${users.length}명', name: 'UserService');
      return Success(users);
    } on api.ApiException catch (e) {
      developer.log('사용자 목록 조회 실패: ${e.message}', name: 'UserService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log('사용자 목록 조회 오류: $e', name: 'UserService');
      return Failure(ApiException.networkError());
    }
  }

  /// 사용자 삭제
  ///
  /// [userId] 삭제할 사용자 ID
  Future<ApiResult<api.UserRespDto>> deleteUser(int userId) async {
    try {
      developer.log('사용자 삭제: $userId', name: 'UserService');

      final response = await _userApi.deleteUser(userId);

      if (response?.data == null) {
        return Failure(ApiException.serverError('사용자 삭제에 실패했습니다'));
      }

      developer.log('사용자 삭제 완료', name: 'UserService');
      return Success(response!.data!);
    } on api.ApiException catch (e) {
      developer.log('사용자 삭제 실패: ${e.message}', name: 'UserService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log('사용자 삭제 오류: $e', name: 'UserService');
      return Failure(ApiException.networkError());
    }
  }
}
