/// API 클라이언트 싱글톤
/// Spring Boot API와 통신하기 위한 중앙 집중식 클라이언트
library;

import 'package:soi_api_client/api.dart' as api;

class SoiApiClient {
  static SoiApiClient? _instance;
  late api.ApiClient _apiClient;

  // 싱글톤 패턴
  factory SoiApiClient() {
    _instance ??= SoiApiClient._internal();
    return _instance!;
  }

  SoiApiClient._internal() {
    _initialize();
  }

  void _initialize() {
    // Production 서버 URL
    const baseUrl = 'https://newdawnsoi.site';

    _apiClient = api.ApiClient(basePath: baseUrl);

    // 기본 헤더 설정
    _apiClient.addDefaultHeader('Content-Type', 'application/json');
    _apiClient.addDefaultHeader('Accept', 'application/json');
  }

  /// API 클라이언트 인스턴스 가져오기
  api.ApiClient get client => _apiClient;

  /// 인증 토큰 설정 (필요한 경우)
  void setAuthToken(String token) {
    _apiClient.addDefaultHeader('Authorization', 'Bearer $token');
  }

  /// 인증 토큰 제거
  void clearAuthToken() {
    // ApiClient에 removeDefaultHeaderByKey가 없으므로 재초기화
    _initialize();
  }

  /// Base URL 변경 (개발/프로덕션 전환 시)
  void setBaseUrl(String baseUrl) {
    _apiClient = api.ApiClient(basePath: baseUrl);
    _initialize();
  }

  /// 클라이언트 초기화 (로그아웃 시 등)
  void reset() {
    _initialize();
  }
}
