import 'package:soi_api/soi_api.dart';
import '../common/api_result.dart';
import '../common/dio_exception_handler.dart';

/// Friend API를 wrapping한 Service 클래스
///
/// OpenAPI로 생성된 FriendAPIApi를 실제 앱에서 사용하기 쉽게 래핑합니다.
/// - DioException을 ApiResult로 변환하여 에러 처리를 간편하게 합니다
/// - 비즈니스 로직 검증을 추가합니다
/// - 로깅, 에러 핸들링 등의 공통 로직을 처리합니다
///
/// 사용 예시:
/// ```dart
/// final service = FriendService(friendApi);
///
/// // 친구 추가
/// final result = await service.addFriend(
///   requesterId: 1,
///   receiverId: 2,
/// );
///
/// result.when(
///   success: (friend) => print('친구 추가 성공: ${friend.id}'),
///   failure: (error) => print('에러: ${error.message}'),
/// );
/// ```
class FriendService {
  final FriendAPIApi _api;

  FriendService(this._api);

  /// 친구 추가 요청
  ///
  /// [requesterId] 친구 요청을 보내는 사용자 ID
  /// [receiverId] 친구 요청을 받는 사용자 ID
  ///
  /// Returns [ApiResult<FriendRespDto>]
  /// - Success: 생성된 친구 관계 정보
  /// - Failure: 에러 정보
  Future<ApiResult<FriendRespDto>> addFriend({
    required int requesterId,
    required int receiverId,
  }) async {
    // 입력값 검증
    if (requesterId == receiverId) {
      return ApiResult.failure(
        ApiFailure(
          message: '자기 자신에게 친구 요청을 보낼 수 없습니다',
          errorCode: 'INVALID_REQUEST',
        ),
      );
    }

    if (requesterId <= 0 || receiverId <= 0) {
      return ApiResult.failure(
        ApiFailure(message: '유효하지 않은 사용자 ID입니다', errorCode: 'INVALID_USER_ID'),
      );
    }

    // API 호출
    return DioExceptionHandler.catchError(() async {
      final response = await _api.create(
        friendReqDto: FriendReqDto(
          requesterId: requesterId,
          receiverId: receiverId,
        ),
      );

      // API 응답 검증
      final apiResponse = response.data;
      if (apiResponse == null) {
        throw ApiFailure(message: '서버 응답이 없습니다', errorCode: 'EMPTY_RESPONSE');
      }

      if (apiResponse.success != true) {
        throw ApiFailure(
          message: apiResponse.message ?? '친구 추가에 실패했습니다',
          errorCode: 'API_FAILED',
        );
      }

      final friendData = apiResponse.data;
      if (friendData == null) {
        throw ApiFailure(message: '친구 정보가 없습니다', errorCode: 'EMPTY_DATA');
      }

      return friendData;
    });
  }

  /// 친구 요청 수락
  ///
  /// [friendshipId] 친구 관계 ID
  ///
  /// Returns [ApiResult<FriendRespDto>]
  Future<ApiResult<FriendRespDto>> acceptFriendRequest({
    required int friendshipId,
  }) async {
    return _updateFriendStatus(
      friendshipId: friendshipId,
      status: FriendUpdateRespDtoStatusEnum.ACCEPTED,
    );
  }

  /// 친구 요청 거절 (취소)
  ///
  /// [friendshipId] 친구 관계 ID
  ///
  /// Returns [ApiResult<FriendRespDto>]
  Future<ApiResult<FriendRespDto>> cancelFriendRequest({
    required int friendshipId,
  }) async {
    return _updateFriendStatus(
      friendshipId: friendshipId,
      status: FriendUpdateRespDtoStatusEnum.CANCELLED,
    );
  }

  /// 친구 차단
  ///
  /// [friendshipId] 친구 관계 ID
  ///
  /// Returns [ApiResult<FriendRespDto>]
  Future<ApiResult<FriendRespDto>> blockFriend({
    required int friendshipId,
  }) async {
    return _updateFriendStatus(
      friendshipId: friendshipId,
      status: FriendUpdateRespDtoStatusEnum.BLOCKED,
    );
  }

  /// 친구 상태 업데이트 (내부 헬퍼 메서드)
  ///
  /// [friendshipId] 친구 관계 ID
  /// [status] 변경할 상태
  ///
  /// Returns [ApiResult<FriendRespDto>]
  Future<ApiResult<FriendRespDto>> _updateFriendStatus({
    required int friendshipId,
    required FriendUpdateRespDtoStatusEnum status,
  }) async {
    // 입력값 검증
    if (friendshipId <= 0) {
      return ApiResult.failure(
        ApiFailure(
          message: '유효하지 않은 친구 관계 ID입니다',
          errorCode: 'INVALID_FRIENDSHIP_ID',
        ),
      );
    }

    // API 호출
    return DioExceptionHandler.catchError(() async {
      final response = await _api.update(
        friendUpdateRespDto: FriendUpdateRespDto(
          id: friendshipId,
          status: status,
        ),
      );

      // API 응답 검증
      final apiResponse = response.data;
      if (apiResponse == null) {
        throw ApiFailure(message: '서버 응답이 없습니다', errorCode: 'EMPTY_RESPONSE');
      }

      if (apiResponse.success != true) {
        throw ApiFailure(
          message: apiResponse.message ?? '친구 상태 업데이트에 실패했습니다',
          errorCode: 'API_FAILED',
        );
      }

      final friendData = apiResponse.data;
      if (friendData == null) {
        throw ApiFailure(message: '친구 정보가 없습니다', errorCode: 'EMPTY_DATA');
      }

      return friendData;
    });
  }

  /// 친구 요청이 대기 중인지 확인
  static bool isPending(FriendRespDto friend) {
    return friend.status == FriendRespDtoStatusEnum.PENDING;
  }

  /// 친구 요청이 수락되었는지 확인
  static bool isAccepted(FriendRespDto friend) {
    return friend.status == FriendRespDtoStatusEnum.ACCEPTED;
  }

  /// 친구가 차단되었는지 확인
  static bool isBlocked(FriendRespDto friend) {
    return friend.status == FriendRespDtoStatusEnum.BLOCKED;
  }

  /// 친구 요청이 취소되었는지 확인
  static bool isCancelled(FriendRespDto friend) {
    return friend.status == FriendRespDtoStatusEnum.CANCELLED;
  }
}
