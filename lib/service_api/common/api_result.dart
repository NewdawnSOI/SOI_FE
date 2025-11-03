/// API 호출 결과를 나타내는 sealed class
///
/// 성공(Success)과 실패(Failure) 두 가지 상태를 명확하게 구분합니다.
///
/// 사용 예시:
/// ```dart
/// final result = await friendService.addFriend(userId);
/// result.when(
///   success: (friend) => print('친구 추가 성공: ${friend.id}'),
///   failure: (error) => print('에러: ${error.message}'),
/// );
/// ```
sealed class ApiResult<T> {
  const ApiResult();

  /// 성공 케이스
  factory ApiResult.success(T data) = Success<T>;

  /// 실패 케이스
  factory ApiResult.failure(ApiFailure failure) = Failure<T>;

  /// 패턴 매칭을 위한 when 메서드
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiFailure failure) failure,
  }) {
    return switch (this) {
      Success<T>(data: final data) => success(data),
      Failure<T>(failure: final error) => failure(error),
    };
  }

  /// 성공인지 확인
  bool get isSuccess => this is Success<T>;

  /// 실패인지 확인
  bool get isFailure => this is Failure<T>;

  /// 성공 데이터 가져오기 (실패시 null)
  T? get dataOrNull => switch (this) {
    Success<T>(data: final data) => data,
    _ => null,
  };

  /// 실패 정보 가져오기 (성공시 null)
  ApiFailure? get failureOrNull => switch (this) {
    Failure<T>(failure: final error) => error,
    _ => null,
  };
}

/// 성공 결과
final class Success<T> extends ApiResult<T> {
  final T data;
  const Success(this.data);

  @override
  String toString() => 'Success(data: $data)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;
}

/// 실패 결과
final class Failure<T> extends ApiResult<T> {
  final ApiFailure failure;
  const Failure(this.failure);

  @override
  String toString() => 'Failure(failure: $failure)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => failure.hashCode;
}

/// API 실패 정보
class ApiFailure {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final dynamic originalError;

  const ApiFailure({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.originalError,
  });

  /// 네트워크 에러
  factory ApiFailure.network({String? message}) => ApiFailure(
    message: message ?? '네트워크 연결을 확인해주세요',
    errorCode: 'NETWORK_ERROR',
  );

  /// 서버 에러
  factory ApiFailure.server({required int statusCode, String? message}) =>
      ApiFailure(
        message: message ?? '서버 오류가 발생했습니다',
        statusCode: statusCode,
        errorCode: 'SERVER_ERROR',
      );

  /// 인증 에러
  factory ApiFailure.unauthorized({String? message}) => ApiFailure(
    message: message ?? '로그인이 필요합니다',
    statusCode: 401,
    errorCode: 'UNAUTHORIZED',
  );

  /// 권한 에러
  factory ApiFailure.forbidden({String? message}) => ApiFailure(
    message: message ?? '접근 권한이 없습니다',
    statusCode: 403,
    errorCode: 'FORBIDDEN',
  );

  /// 타임아웃 에러
  factory ApiFailure.timeout({String? message}) =>
      ApiFailure(message: message ?? '요청 시간이 초과되었습니다', errorCode: 'TIMEOUT');

  /// 알 수 없는 에러
  factory ApiFailure.unknown({String? message, dynamic error}) => ApiFailure(
    message: message ?? '알 수 없는 오류가 발생했습니다',
    errorCode: 'UNKNOWN',
    originalError: error,
  );

  @override
  String toString() =>
      'ApiFailure(message: $message, statusCode: $statusCode, errorCode: $errorCode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          statusCode == other.statusCode &&
          errorCode == other.errorCode;

  @override
  int get hashCode =>
      message.hashCode ^ statusCode.hashCode ^ errorCode.hashCode;
}
