/// 친구 API 서비스
/// FriendAPIApi를 래핑하여 Flutter에서 사용하기 쉽게 만든 서비스
library;

import 'dart:developer' as developer;
import 'package:soi_api_client/api.dart' as api;
import '../common/api_client.dart';
import '../common/api_result.dart';
import '../common/api_exception.dart';

class FriendService {
  late final api.FriendAPIApi _friendApi;

  FriendService() {
    _friendApi = api.FriendAPIApi(SoiApiClient().client);
  }

  /// 친구 추가 요청 API
  ///
  /// [requesterId] 요청하는 사용자의 ID
  /// [receiverId] 요청받는 사용자의 ID
  Future<ApiResult<api.FriendRespDto>> addFriend({
    required int requesterId,
    required int receiverId,
  }) async {
    try {
      developer.log(
        '친구 추가 요청: $requesterId -> $receiverId',
        name: 'FriendService',
      );

      final reqDto = api.FriendReqDto(
        requesterId: requesterId,
        receiverId: receiverId,
      );

      final response = await _friendApi.create(reqDto);

      if (response?.data == null) {
        return Failure(ApiException.serverError('친구 추가에 실패했습니다'));
      }

      developer.log('친구 추가 성공', name: 'FriendService');
      return Success(response!.data!);
    } on api.ApiException catch (e) {
      developer.log('친구 추가 실패: ${e.message}', name: 'FriendService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log('친구 추가 오류: $e', name: 'FriendService');
      return Failure(ApiException.networkError());
    }
  }

  /// 친구 삭제 요청 API
  ///
  /// [requesterId] 삭제를 요청하는 사용자의 ID
  /// [receiverId] 삭제될 친구의 ID
  Future<ApiResult<bool>> deleteFriend({
    required int requesterId,
    required int receiverId,
  }) async {
    try {
      developer.log(
        '친구 삭제 요청: $requesterId -> $receiverId',
        name: 'FriendService',
      );

      final reqDto = api.FriendReqDto(
        requesterId: requesterId,
        receiverId: receiverId,
      );

      final response = await _friendApi.deleteFriend(reqDto);

      if (response?.data == null) {
        return Failure(ApiException.serverError('친구 삭제에 실패했습니다'));
      }

      developer.log('친구 삭제 성공', name: 'FriendService');
      return Success(response!.data!);
    } on api.ApiException catch (e) {
      developer.log('친구 삭제 실패: ${e.message}', name: 'FriendService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log('친구 삭제 오류: $e', name: 'FriendService');
      return Failure(ApiException.networkError());
    }
  }

  /// 모든 친구 조회 API
  ///
  /// [userId] 조회할 사용자의 ID
  Future<ApiResult<List<api.UserFindRespDto>>> getAllFriends(int userId) async {
    try {
      developer.log('친구 목록 조회: $userId', name: 'FriendService');

      final response = await _friendApi.getAllFriend(userId);

      if (response?.data == null) {
        return Failure(ApiException.serverError('친구 목록 조회에 실패했습니다'));
      }

      final friends = response!.data;
      developer.log('친구 목록 조회 완료: ${friends.length}명', name: 'FriendService');
      return Success(friends);
    } on api.ApiException catch (e) {
      developer.log('친구 목록 조회 실패: ${e.message}', name: 'FriendService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log('친구 목록 조회 오류: $e', name: 'FriendService');
      return Failure(ApiException.networkError());
    }
  }

  /// 친구 차단 API
  ///
  /// [requesterId] 차단하는 사용자의 ID
  /// [receiverId] 차단될 사용자의 ID
  Future<ApiResult<bool>> blockFriend({
    required int requesterId,
    required int receiverId,
  }) async {
    try {
      developer.log(
        '친구 차단 요청: $requesterId -> $receiverId',
        name: 'FriendService',
      );

      final reqDto = api.FriendReqDto(
        requesterId: requesterId,
        receiverId: receiverId,
      );

      final response = await _friendApi.blockFriend(reqDto);

      if (response?.data == null) {
        return Failure(ApiException.serverError('친구 차단에 실패했습니다'));
      }

      developer.log('친구 차단 성공', name: 'FriendService');
      return Success(response!.data!);
    } on api.ApiException catch (e) {
      developer.log(' 친구 차단 실패: ${e.message}', name: 'FriendService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log(' 친구 차단 오류: $e', name: 'FriendService');
      return Failure(ApiException.networkError());
    }
  }

  /// 친구 차단 해제 API
  ///
  /// [requesterId] 차단 해제하는 사용자의 ID
  /// [receiverId] 차단 해제될 사용자의 ID
  Future<ApiResult<bool>> unblockFriend({
    required int requesterId,
    required int receiverId,
  }) async {
    try {
      developer.log(
        '친구 차단 해제 요청: $requesterId -> $receiverId',
        name: 'FriendService',
      );

      final reqDto = api.FriendReqDto(
        requesterId: requesterId,
        receiverId: receiverId,
      );

      final response = await _friendApi.unBlockFriend(reqDto);

      if (response?.data == null) {
        return Failure(ApiException.serverError('친구 차단 해제에 실패했습니다'));
      }

      developer.log('친구 차단 해제 성공', name: 'FriendService');
      return Success(response!.data!);
    } on api.ApiException catch (e) {
      developer.log(' 친구 차단 해제 실패: ${e.message}', name: 'FriendService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log(' 친구 차단 해제 오류: $e', name: 'FriendService');
      return Failure(ApiException.networkError());
    }
  }

  /// 친구 상태 업데이트 API
  ///
  /// [friendId] 친구 관계 ID
  /// [status] 변경할 상태 (PENDING, ACCEPTED, BLOCKED, CANCELLED)
  Future<ApiResult<api.FriendRespDto>> updateFriendStatus({
    required int friendId,
    required api.FriendUpdateRespDtoStatusEnum status,
  }) async {
    try {
      developer.log('친구 상태 업데이트: $friendId -> $status', name: 'FriendService');

      final reqDto = api.FriendUpdateRespDto(id: friendId, status: status);

      final response = await _friendApi.update(reqDto);

      if (response?.data == null) {
        return Failure(ApiException.serverError('친구 상태 업데이트에 실패했습니다'));
      }

      developer.log('친구 상태 업데이트 성공', name: 'FriendService');
      return Success(response!.data!);
    } on api.ApiException catch (e) {
      developer.log(' 친구 상태 업데이트 실패: ${e.message}', name: 'FriendService');
      return Failure(ApiException.fromStatusCode(e.code, e.message));
    } catch (e) {
      developer.log(' 친구 상태 업데이트 오류: $e', name: 'FriendService');
      return Failure(ApiException.networkError());
    }
  }
}
