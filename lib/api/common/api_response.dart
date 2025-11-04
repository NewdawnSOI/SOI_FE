/// API 응답 래퍼 클래스
/// Spring Boot API의 ApiResponseDto를 Flutter에서 사용하기 쉽게 변환
library;

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
  });

  /// 성공 응답 생성
  factory ApiResponse.success({
    required T data,
    String? message,
    int statusCode = 200,
  }) {
    return ApiResponse(
      success: true,
      data: data,
      message: message ?? 'Success',
      statusCode: statusCode,
    );
  }

  /// 실패 응답 생성
  factory ApiResponse.error({required String message, int statusCode = 500}) {
    return ApiResponse(
      success: false,
      message: message,
      statusCode: statusCode,
    );
  }

  /// 응답 데이터가 있는지 확인
  bool get hasData => data != null;

  @override
  String toString() {
    return 'ApiResponse(success: $success, data: $data, message: $message, statusCode: $statusCode)';
  }
}
