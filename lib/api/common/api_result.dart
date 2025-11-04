/// API 결과를 Success 또는 Failure로 표현하는 클래스
/// Either 패턴 구현
library;

import 'api_exception.dart';

sealed class ApiResult<T> {
  const ApiResult();

  /// 성공 케이스
  bool get isSuccess => this is Success<T>;

  /// 실패 케이스
  bool get isFailure => this is Failure<T>;

  /// 성공 시 데이터 반환, 실패 시 null
  T? get dataOrNull => switch (this) {
    Success(data: final data) => data,
    Failure() => null,
  };

  /// 성공 시 데이터 반환, 실패 시 예외 throw
  T get dataOrThrow => switch (this) {
    Success(data: final data) => data,
    Failure(exception: final exception) => throw exception,
  };

  /// 실패 시 예외 반환, 성공 시 null
  ApiException? get exceptionOrNull => switch (this) {
    Success() => null,
    Failure(exception: final exception) => exception,
  };

  /// when 패턴 매칭
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException exception) failure,
  }) {
    return switch (this) {
      Success(data: final data) => success(data),
      Failure(exception: final exception) => failure(exception),
    };
  }
}

/// 성공 케이스
class Success<T> extends ApiResult<T> {
  final T data;

  const Success(this.data);

  @override
  String toString() => 'Success(data: $data)';
}

/// 실패 케이스
class Failure<T> extends ApiResult<T> {
  final ApiException exception;

  const Failure(this.exception);

  @override
  String toString() => 'Failure(exception: $exception)';
}
