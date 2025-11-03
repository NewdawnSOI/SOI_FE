import 'package:dio/dio.dart';
import 'api_result.dart';

/// DioException을 ApiFailure로 변환하는 유틸리티 클래스
///
/// OpenAPI로 생성된 API 클라이트는 DioException을 throw하는데,
/// 이를 우리의 ApiResult 타입으로 변환해줍니다.
class DioExceptionHandler {
  const DioExceptionHandler._();

  /// DioException을 ApiFailure로 변환
  static ApiFailure handle(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiFailure.timeout(message: '요청 시간이 초과되었습니다');

      case DioExceptionType.badResponse:
        return _handleResponseError(error);

      case DioExceptionType.connectionError:
        return ApiFailure.network(message: '네트워크 연결을 확인해주세요');

      case DioExceptionType.cancel:
        return ApiFailure(message: '요청이 취소되었습니다', errorCode: 'CANCELLED');

      case DioExceptionType.badCertificate:
        return ApiFailure(
          message: '보안 인증서 오류가 발생했습니다',
          errorCode: 'BAD_CERTIFICATE',
        );

      case DioExceptionType.unknown:
        return ApiFailure.unknown(
          message: error.message ?? '알 수 없는 오류가 발생했습니다',
          error: error,
        );
    }
  }

  /// HTTP 응답 에러를 처리
  static ApiFailure _handleResponseError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    // 서버에서 보낸 에러 메시지 추출 시도
    String? message;
    if (data is Map<String, dynamic>) {
      message = data['message'] as String?;
    }

    switch (statusCode) {
      case 400:
        return ApiFailure(
          message: message ?? '잘못된 요청입니다',
          statusCode: 400,
          errorCode: 'BAD_REQUEST',
        );

      case 401:
        return ApiFailure.unauthorized(message: message);

      case 403:
        return ApiFailure.forbidden(message: message);

      case 404:
        return ApiFailure(
          message: message ?? '요청한 리소스를 찾을 수 없습니다',
          statusCode: 404,
          errorCode: 'NOT_FOUND',
        );

      case 409:
        return ApiFailure(
          message: message ?? '이미 존재하는 데이터입니다',
          statusCode: 409,
          errorCode: 'CONFLICT',
        );

      case 422:
        return ApiFailure(
          message: message ?? '입력값을 확인해주세요',
          statusCode: 422,
          errorCode: 'VALIDATION_ERROR',
        );

      case 500:
      case 502:
      case 503:
        return ApiFailure.server(
          statusCode: statusCode!,
          message: message ?? '서버 오류가 발생했습니다',
        );

      default:
        return ApiFailure.server(
          statusCode: statusCode ?? 500,
          message: message ?? '서버 오류가 발생했습니다',
        );
    }
  }

  /// 에러 발생시 ApiResult.failure로 감싸서 반환하는 헬퍼
  static Future<ApiResult<T>> catchError<T>(
    Future<T> Function() apiCall,
  ) async {
    try {
      final result = await apiCall();
      return ApiResult.success(result);
    } on DioException catch (e) {
      return ApiResult.failure(handle(e));
    } catch (e) {
      return ApiResult.failure(
        ApiFailure.unknown(message: '예상치 못한 오류가 발생했습니다', error: e),
      );
    }
  }
}
