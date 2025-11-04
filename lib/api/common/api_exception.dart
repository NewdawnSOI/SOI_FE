/// API 예외 처리 클래스
/// 네트워크 에러, 서버 에러 등을 일관되게 처리
library;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic error;

  ApiException({required this.message, this.statusCode, this.error});

  /// 네트워크 에러
  factory ApiException.networkError() {
    return ApiException(message: '네트워크 연결을 확인해주세요', statusCode: 0);
  }

  /// 서버 에러
  factory ApiException.serverError([String? message]) {
    return ApiException(message: message ?? '서버 오류가 발생했습니다', statusCode: 500);
  }

  /// 인증 에러
  factory ApiException.unauthorized() {
    return ApiException(message: '인증이 필요합니다', statusCode: 401);
  }

  /// 권한 에러
  factory ApiException.forbidden() {
    return ApiException(message: '권한이 없습니다', statusCode: 403);
  }

  /// 찾을 수 없음
  factory ApiException.notFound([String? message]) {
    return ApiException(
      message: message ?? '요청한 리소스를 찾을 수 없습니다',
      statusCode: 404,
    );
  }

  /// 잘못된 요청
  factory ApiException.badRequest([String? message]) {
    return ApiException(message: message ?? '잘못된 요청입니다', statusCode: 400);
  }

  /// HTTP 상태 코드로부터 예외 생성
  factory ApiException.fromStatusCode(int statusCode, [String? message]) {
    switch (statusCode) {
      case 400:
        return ApiException.badRequest(message);
      case 401:
        return ApiException.unauthorized();
      case 403:
        return ApiException.forbidden();
      case 404:
        return ApiException.notFound(message);
      case 500:
      case 502:
      case 503:
        return ApiException.serverError(message);
      default:
        return ApiException(
          message: message ?? '알 수 없는 오류가 발생했습니다',
          statusCode: statusCode,
        );
    }
  }

  @override
  String toString() {
    return 'ApiException(message: $message, statusCode: $statusCode)';
  }
}
