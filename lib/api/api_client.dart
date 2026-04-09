import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:soi_api_client/api.dart';

import 'api_exception.dart';
import 'models/login.dart';

/// SOI API 클라이언트 설정 및 인증 세션을 관리합니다.
/// 생성 클라이언트의 HTTP 계층에 토큰 재발급과 인증 손실 브로드캐스트를 연결해 전역 호출이 같은 세션 상태를 공유하게 합니다.
class SoiApiClient {
  static final SoiApiClient _instance = SoiApiClient._internal();

  /// 싱글톤 인스턴스 접근자
  static SoiApiClient get instance => _instance;

  SoiApiClient._internal();

  /// 기본 API 서버 URL
  static const String defaultBasePath = 'https://newdawnsoi.site';

  /// OpenAPI 생성 클라이언트
  late ApiClient _apiClient;

  /// 재시도 없는 원시 HTTP 클라이언트
  late http.Client _rawHttpClient;

  /// 401 감지 후 refresh -> 1회 재시도를 수행하는 HTTP 클라이언트
  late http.BaseClient _authRefreshingHttpClient;

  /// 초기화 여부
  bool _isInitialized = false;

  /// 현재 인증 세션
  LoginSession? _authSession;

  /// 동시 401 요청이 하나의 refresh 결과를 공유하도록 직렬화합니다.
  Completer<bool>? _refreshCompleter;

  /// refresh 실패로 인증이 사라졌을 때 전역 UI가 한 번만 정리할 수 있게 알립니다.
  final Set<VoidCallback> _authLossListeners = <VoidCallback>{};

  bool _isNotifyingAuthLoss = false;

  // ============================================
  // API 인스턴스들 (Lazy initialization)
  // ============================================

  AuthControllerApi? _authApi;
  UserAPIApi? _userApi;
  CategoryAPIApi? _categoryApi;
  PostAPIApi? _postApi;
  FriendAPIApi? _friendApi;
  CommentAPIApi? _commentApi;
  NotificationAPIApi? _notificationApi;
  NotificationDeviceAPIApi? _notificationDeviceApi;
  APIApi? _mediaApi;
  ReportControllerApi? _reportApi;

  // ============================================
  // 초기화 메서드
  // ============================================

  /// API 클라이언트를 초기화하고 인증 재시도 레이어를 연결합니다.
  ///
  /// [basePath]를 지정하지 않으면 기본값 `https://newdawnsoi.site`를 사용합니다.
  void initialize({
    String basePath = defaultBasePath,
    http.Client? httpClient,
  }) {
    if (_isInitialized) {
      _authRefreshingHttpClient.close();
    }

    _rawHttpClient = httpClient ?? http.Client();
    _authRefreshingHttpClient = _AuthRefreshingClient(
      owner: this,
      inner: _rawHttpClient,
    );
    _apiClient = ApiClient(basePath: basePath);
    _apiClient.client = _authRefreshingHttpClient;
    _isInitialized = true;
    _authSession = null;
    _refreshCompleter = null;
    _authLossListeners.clear();
    _isNotifyingAuthLoss = false;

    _authApi = null;
    _userApi = null;
    _categoryApi = null;
    _postApi = null;
    _friendApi = null;
    _commentApi = null;
    _notificationApi = null;
    _notificationDeviceApi = null;
    _mediaApi = null;
    _reportApi = null;
  }

  /// 초기화 확인
  void _checkInitialized() {
    if (!_isInitialized) {
      throw const SoiApiException(
        message: 'SoiApiClient가 초기화되지 않았습니다. initialize()를 먼저 호출해주세요.',
      );
    }
  }

  // ============================================
  // 인증 세션 관리
  // ============================================

  /// 생성 로그인 응답을 현재 인증 세션으로 적용합니다.
  void applyLoginResponse(LoginRespDto loginResponse) {
    setAuthSession(LoginSession.fromDto(loginResponse));
  }

  /// access/refresh 토큰과 만료 정보를 함께 보관하고 Authorization 헤더를 갱신합니다.
  void setAuthSession(LoginSession session) {
    _checkInitialized();
    _authSession = session;
    _applyAuthorizationHeader(session.accessToken);
  }

  /// 레거시 호출부가 access token만 복원해도 기존 동작을 유지하게 합니다.
  void setAuthToken(String token) {
    final currentSession = _authSession;
    setAuthSession(
      LoginSession(
        accessToken: token,
        refreshToken: currentSession?.refreshToken,
        accessTokenExpiresInMs: currentSession?.accessTokenExpiresInMs,
        refreshTokenExpiresInMs: currentSession?.refreshTokenExpiresInMs,
        issuedAtEpochMs: currentSession?.issuedAtEpochMs,
      ),
    );
  }

  /// 현재 인증 세션을 제거하고 기본 Authorization 헤더를 비웁니다.
  void clearAuthToken() {
    if (!_isInitialized) {
      _authSession = null;
      return;
    }
    _authSession = null;
    _apiClient.defaultHeaderMap.remove('Authorization');
  }

  /// 새 코드가 더 명시적으로 세션 전체를 지울 수 있게 별칭을 제공합니다.
  void clearAuthSession() => clearAuthToken();

  /// 현재 access token 확인
  String? get authToken => _authSession?.accessToken;

  /// 현재 refresh token 확인
  String? get refreshToken => _authSession?.refreshToken;

  /// 현재 인증 세션 확인
  LoginSession? get currentAuthSession => _authSession;

  /// 인증 상태 확인
  bool get isAuthenticated => authToken != null && authToken!.isNotEmpty;

  /// 재발급 가능한 refresh token 보유 여부
  bool get hasRefreshToken => _authSession?.hasRefreshToken ?? false;

  /// refresh 실패 시 앱 루트가 세션 정리와 라우팅을 동기화할 수 있게 listener를 등록합니다.
  void addAuthLossListener(VoidCallback listener) {
    _authLossListeners.add(listener);
  }

  /// 더 이상 세션 손실 알림이 필요 없는 owner가 listener를 해제할 수 있게 합니다.
  void removeAuthLossListener(VoidCallback listener) {
    _authLossListeners.remove(listener);
  }

  // ============================================
  // API 인스턴스 Getter들
  // ============================================

  /// 인증 API
  AuthControllerApi get authApi {
    _checkInitialized();
    return _authApi ??= AuthControllerApi(_apiClient);
  }

  /// 인증 헤더 없이 호출해야 하는 공개 인증 API
  ///
  /// `/auth/login`, `/auth/refresh`, `/auth/logout`처럼 자체 토큰 갱신을 담당하는 엔드포인트에 사용합니다.
  AuthControllerApi createUnauthenticatedAuthApi() {
    _checkInitialized();
    return AuthControllerApi(_createApiClientWithoutAuthorization());
  }

  /// 사용자 API
  UserAPIApi get userApi {
    _checkInitialized();
    return _userApi ??= UserAPIApi(_apiClient);
  }

  /// 인증 헤더 없이 호출해야 하는 공개 사용자 API
  ///
  /// `/user/auth` 같은 비로그인 엔드포인트에 사용합니다.
  UserAPIApi createUnauthenticatedUserApi() {
    _checkInitialized();
    return UserAPIApi(_createApiClientWithoutAuthorization());
  }

  /// 카테고리 API
  CategoryAPIApi get categoryApi {
    _checkInitialized();
    return _categoryApi ??= CategoryAPIApi(_apiClient);
  }

  /// 게시물 API
  PostAPIApi get postApi {
    _checkInitialized();
    return _postApi ??= PostAPIApi(_apiClient);
  }

  /// 친구 API
  FriendAPIApi get friendApi {
    _checkInitialized();
    return _friendApi ??= FriendAPIApi(_apiClient);
  }

  /// 댓글 API
  CommentAPIApi get commentApi {
    _checkInitialized();
    return _commentApi ??= CommentAPIApi(_apiClient);
  }

  /// 알림 API
  NotificationAPIApi get notificationApi {
    _checkInitialized();
    return _notificationApi ??= NotificationAPIApi(_apiClient);
  }

  /// 디바이스 토큰 API
  NotificationDeviceAPIApi get notificationDeviceApi {
    _checkInitialized();
    return _notificationDeviceApi ??= NotificationDeviceAPIApi(_apiClient);
  }

  /// 미디어 API
  APIApi get mediaApi {
    _checkInitialized();
    return _mediaApi ??= APIApi(_apiClient);
  }

  /// 신고 API
  ReportControllerApi get reportApi {
    _checkInitialized();
    return _reportApi ??= ReportControllerApi(_apiClient);
  }

  /// 기본 ApiClient 접근 (고급 사용자용)
  ApiClient get apiClient {
    _checkInitialized();
    return _apiClient;
  }

  // ============================================
  // 기본 헤더 관리
  // ============================================

  /// 기본 헤더 추가
  void addDefaultHeader(String key, String value) {
    _checkInitialized();
    _apiClient.addDefaultHeader(key, value);
  }

  /// 기본 헤더 제거
  void removeDefaultHeader(String key) {
    _checkInitialized();
    _apiClient.defaultHeaderMap.remove(key);
  }

  void _applyAuthorizationHeader(String token) {
    _apiClient.addDefaultHeader('Authorization', 'Bearer $token');
  }

  ApiClient _createApiClientWithoutAuthorization() {
    final unauthenticatedClient = ApiClient(basePath: _apiClient.basePath);
    unauthenticatedClient.client = _rawHttpClient;
    for (final entry in _apiClient.defaultHeaderMap.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        continue;
      }
      unauthenticatedClient.addDefaultHeader(entry.key, entry.value);
    }
    return unauthenticatedClient;
  }

  /// 401 응답이 현재 세션 기준인지 확인한 뒤 refresh를 한 번만 수행합니다.
  Future<bool> _refreshSessionAfterUnauthorized({
    String? failedAccessToken,
  }) async {
    _checkInitialized();

    final latestAccessToken = authToken;
    if (failedAccessToken != null &&
        latestAccessToken != null &&
        latestAccessToken.isNotEmpty &&
        latestAccessToken != failedAccessToken) {
      return true;
    }

    final inFlightRefresh = _refreshCompleter;
    if (inFlightRefresh != null) {
      return inFlightRefresh.future;
    }

    final currentRefreshToken = refreshToken;
    if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
      await _expireCurrentSession();
      return false;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final response = await createUnauthenticatedAuthApi().refresh(
        RefreshTokenReqDto(refreshToken: currentRefreshToken),
      );
      if (response == null) {
        await _expireCurrentSession();
        completer.complete(false);
        return false;
      }

      applyLoginResponse(response);
      completer.complete(true);
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[SoiApiClient] token refresh failed: $error');
      }
      await _expireCurrentSession();
      completer.complete(false);
      return false;
    } finally {
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
    }
  }

  /// refresh 실패 시 메모리 세션을 지우고 UI owner들에게 한 번만 브로드캐스트합니다.
  Future<void> _expireCurrentSession() async {
    final hadSession =
        (_authSession != null) ||
        _apiClient.defaultHeaderMap.containsKey('Authorization');
    clearAuthSession();
    if (!hadSession || _isNotifyingAuthLoss) {
      return;
    }

    _isNotifyingAuthLoss = true;
    try {
      for (final listener in List<VoidCallback>.of(_authLossListeners)) {
        listener();
      }
    } finally {
      _isNotifyingAuthLoss = false;
    }
  }
}

/// 인증이 필요한 요청의 401을 감지해 refresh 후 원요청을 한 번만 재시도합니다.
/// `/auth/login`, `/auth/refresh`, `/auth/logout` 같은 인증 엔드포인트는 순환 호출을 막기 위해 제외합니다.
class _AuthRefreshingClient extends http.BaseClient {
  _AuthRefreshingClient({
    required SoiApiClient owner,
    required http.Client inner,
  }) : _owner = owner,
       _inner = inner;

  final SoiApiClient _owner;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final originalAuthorization = request.headers['Authorization'];
    final retryRequest = _cloneRetryableRequest(request);
    final response = await _inner.send(request);

    if (!_shouldAttemptRefresh(
      request: request,
      response: response,
      originalAuthorization: originalAuthorization,
    )) {
      return response;
    }

    final responseBytes = await response.stream.toBytes();
    final refreshed = await _owner._refreshSessionAfterUnauthorized(
      failedAccessToken: _extractBearerToken(originalAuthorization),
    );
    if (!refreshed || retryRequest == null) {
      return _rebuildStreamedResponse(response, responseBytes);
    }

    _applyLatestAuthorization(retryRequest);
    return _inner.send(retryRequest);
  }

  bool _shouldAttemptRefresh({
    required http.BaseRequest request,
    required http.StreamedResponse response,
    required String? originalAuthorization,
  }) {
    if (response.statusCode != 401) {
      return false;
    }
    if (originalAuthorization == null || originalAuthorization.isEmpty) {
      return false;
    }

    final normalizedPath = request.url.path.toLowerCase();
    if (normalizedPath == '/auth/login' ||
        normalizedPath == '/auth/refresh' ||
        normalizedPath == '/auth/logout') {
      return false;
    }
    return true;
  }

  http.BaseRequest? _cloneRetryableRequest(http.BaseRequest request) {
    if (request is! http.Request) {
      return null;
    }

    final clone = http.Request(request.method, request.url)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return clone;
  }

  void _applyLatestAuthorization(http.BaseRequest request) {
    final latestToken = _owner.authToken;
    if (latestToken == null || latestToken.isEmpty) {
      request.headers.remove('Authorization');
      return;
    }
    request.headers['Authorization'] = 'Bearer $latestToken';
  }

  String? _extractBearerToken(String? authorizationHeader) {
    if (authorizationHeader == null || authorizationHeader.isEmpty) {
      return null;
    }

    const prefix = 'bearer ';
    final normalizedHeader = authorizationHeader.trim();
    if (normalizedHeader.toLowerCase().startsWith(prefix)) {
      return normalizedHeader.substring(prefix.length).trim();
    }
    return normalizedHeader;
  }

  http.StreamedResponse _rebuildStreamedResponse(
    http.StreamedResponse response,
    List<int> bodyBytes,
  ) {
    return http.StreamedResponse(
      Stream<List<int>>.value(bodyBytes),
      response.statusCode,
      contentLength: bodyBytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
  }
}
