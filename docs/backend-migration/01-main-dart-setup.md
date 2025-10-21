# main.dart 수정 가이드

Spring Boot 백엔드 전환 시 main.dart를 어떻게 수정해야 하는지 상세히 설명합니다.

## 📊 현재 main.dart 구조

```dart
// lib/main.dart (현재)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Supabase 초기화 (Storage 용도)
  await Supabase.initialize(
    url: supabaseUrl!,
    anonKey: supabaseAnonKey!,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ❌ 문제: Service/Repository가 Firebase에 직접 의존
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => CategoryController()),
        ChangeNotifierProvider(create: (_) => FriendController(
          friendService: FriendService(
            friendRepository: FriendRepository(),  // Firebase 직접 접근
            userSearchRepository: UserSearchRepository(),
          ),
        )),
        // ... 15개의 Provider
      ],
      child: MaterialApp(/* ... */),
    );
  }
}
```

### 현재 구조의 문제점

1. **환경 구분 없음**: dev/staging/prod 서버 전환 불가
2. **Firebase 강결합**: 모든 Repository가 Firebase에 직접 의존
3. **API 클라이언트 없음**: HTTP 요청 인프라 부재
4. **DI 미흡**: 의존성 주입이 부분적으로만 적용

---

## ✅ 변경될 main.dart 구조

### Phase 1: 환경 설정 추가

```dart
// lib/config/environment.dart (🆕 새로 생성)
enum Environment {
  local,    // http://localhost:8080
  dev,      // https://dev-api.soi.app
  staging,  // https://staging-api.soi.app
  production, // https://api.soi.app
}

class EnvironmentConfig {
  /// 현재 환경 (--dart-define=ENV=dev)
  static Environment get current {
    const envString = String.fromEnvironment('ENV', defaultValue: 'dev');

    switch (envString) {
      case 'local':
        return Environment.local;
      case 'dev':
        return Environment.dev;
      case 'staging':
        return Environment.staging;
      case 'prod':
        return Environment.production;
      default:
        return Environment.dev;
    }
  }

  /// API Base URL
  static String get apiBaseUrl {
    switch (current) {
      case Environment.local:
        return 'http://localhost:8080';
      case Environment.dev:
        return 'https://dev-api.soi.app';
      case Environment.staging:
        return 'https://staging-api.soi.app';
      case Environment.production:
        return 'https://api.soi.app';
    }
  }

  /// OpenAPI 스펙 URL
  static String get openApiSpecUrl => '$apiBaseUrl/v3/api-docs.yaml';

  /// Swagger UI URL
  static String get swaggerUiUrl => '$apiBaseUrl/swagger-ui.html';

  /// 환경별 설정
  static bool get isProduction => current == Environment.production;
  static bool get isDevelopment => current == Environment.dev;
  static bool get enableLogging => !isProduction;
}
```

### Phase 2: API 클라이언트 설정

```dart
// lib/config/api_config.dart (🆕 새로 생성)
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'environment.dart';

class ApiConfig {
  /// Dio 인스턴스 생성 (싱글톤)
  static Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: EnvironmentConfig.apiBaseUrl,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
      sendTimeout: Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 인터셉터 추가
    dio.interceptors.add(AuthInterceptor());

    if (EnvironmentConfig.enableLogging) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (log) => debugPrint('🌐 API: $log'),
      ));
    }

    dio.interceptors.add(ErrorInterceptor());

    return dio;
  }
}

/// JWT 토큰 인터셉터
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // SharedPreferences 또는 Secure Storage에서 토큰 가져오기
    final token = _getStoredToken();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  String? _getStoredToken() {
    // TODO: 실제 토큰 저장소에서 가져오기
    return null;
  }
}

/// 에러 처리 인터셉터
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String message = '오류가 발생했습니다.';

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = '서버 연결 시간이 초과되었습니다.';
        break;
      case DioExceptionType.badResponse:
        if (err.response?.statusCode == 401) {
          message = '인증이 만료되었습니다. 다시 로그인해주세요.';
          // TODO: 로그아웃 처리
        } else if (err.response?.statusCode == 403) {
          message = '접근 권한이 없습니다.';
        } else if (err.response?.statusCode == 404) {
          message = '요청한 리소스를 찾을 수 없습니다.';
        } else if (err.response?.statusCode == 500) {
          message = '서버 오류가 발생했습니다.';
        } else if (err.response?.data != null) {
          // 백엔드에서 보낸 에러 메시지 사용
          message = err.response!.data['message'] ?? message;
        }
        break;
      case DioExceptionType.cancel:
        message = '요청이 취소되었습니다.';
        break;
      case DioExceptionType.unknown:
        message = '네트워크 연결을 확인해주세요.';
        break;
      default:
        break;
    }

    debugPrint('❌ API Error: $message');

    // 커스텀 에러로 변환
    handler.next(DioException(
      requestOptions: err.requestOptions,
      error: message,
      type: err.type,
      response: err.response,
    ));
  }
}
```

### Phase 3: 수정된 main.dart

```dart
// lib/main.dart (✏️ 수정)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

// 🆕 새로 추가된 임포트
import 'config/environment.dart';
import 'config/api_config.dart';
import 'api/generated/lib/api.dart';  // OpenAPI Generator로 생성된 API

// 기존 임포트
import 'controllers/auth_controller.dart';
import 'controllers/category_controller.dart';
import 'controllers/friend_controller.dart';
// ... 기타 임포트

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 로드
  await dotenv.load(fileName: ".env");

  debugPrint('🚀 Starting SOI App...');
  debugPrint('🌍 Environment: ${EnvironmentConfig.current}');
  debugPrint('🔗 API Base URL: ${EnvironmentConfig.apiBaseUrl}');

  // 날짜 포맷팅 초기화
  await initializeDateFormatting('ko_KR', null);

  // 메모리 최적화: ImageCache 크기 제한
  if (kDebugMode) {
    PaintingBinding.instance.imageCache.maximumSize = 50;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  } else {
    PaintingBinding.instance.imageCache.maximumSize = 30;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;
  }

  // ⚠️ Firebase는 Auth, FCM 용도로만 유지 (선택사항)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized (Auth & FCM only)');
  } catch (e) {
    debugPrint('⚠️ Firebase initialization failed: $e');
  }

  // 🆕 Dio 인스턴스 생성
  final dio = ApiConfig.createDio();
  debugPrint('✅ HTTP Client (Dio) configured');

  // 🆕 자동 생성된 API 클라이언트들
  final categoryApi = CategoryApi(dio);
  final photoApi = PhotoApi(dio);
  final friendApi = FriendApi(dio);
  final inviteApi = InviteApi(dio);
  // ... 기타 API 클라이언트들

  debugPrint('✅ API Clients initialized');

  runApp(MyApp(
    dio: dio,
    categoryApi: categoryApi,
    photoApi: photoApi,
    friendApi: friendApi,
    inviteApi: inviteApi,
  ));
}

class MyApp extends StatelessWidget {
  final Dio dio;
  final CategoryApi categoryApi;
  final PhotoApi photoApi;
  final FriendApi friendApi;
  final InviteApi inviteApi;

  const MyApp({
    super.key,
    required this.dio,
    required this.categoryApi,
    required this.photoApi,
    required this.friendApi,
    required this.inviteApi,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 🆕 Dio Provider (필요한 곳에서 사용)
        Provider<Dio>.value(value: dio),

        // 🆕 API 클라이언트 Provider들
        Provider<CategoryApi>.value(value: categoryApi),
        Provider<PhotoApi>.value(value: photoApi),
        Provider<FriendApi>.value(value: friendApi),
        Provider<InviteApi>.value(value: inviteApi),

        // ✏️ 수정된 Controller들 (API 주입)
        ChangeNotifierProvider(
          create: (context) => AuthController(
            // AuthApi는 아직 Firebase Auth 사용 (선택사항)
          ),
        ),

        ChangeNotifierProvider(
          create: (context) => CategoryController(
            categoryApi: context.read<CategoryApi>(),  // 🆕 API 주입
          ),
        ),

        ChangeNotifierProvider(
          create: (context) => FriendController(
            friendApi: context.read<FriendApi>(),  // 🆕 API 주입
          ),
        ),

        // ... 나머지 Controller들도 동일하게 수정

        // 🆕 Notification Controller (FCM)
        ChangeNotifierProvider(create: (_) => NotificationController()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) => const StartScreen(),
            '/home_navigation_screen':
                (context) => HomePageNavigationBar(currentPageIndex: 1),
            // ... 기존 라우트들
          },
          theme: ThemeData(
            iconTheme: IconThemeData(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
```

---

## 🔄 Controller 수정 예시

### Before (Firebase 의존)

```dart
// lib/controllers/category_controller.dart (현재)
class CategoryController extends ChangeNotifier {
  final CategoryService _categoryService = CategoryService();  // ❌ 직접 생성

  Stream<List<CategoryDataModel>> streamUserCategories(String userId) {
    return _categoryService.getUserCategoriesStream(userId);  // Firebase Stream
  }
}
```

### After (API 주입)

```dart
// lib/controllers/category_controller.dart (✏️ 수정)
class CategoryController extends ChangeNotifier {
  final CategoryApi _api;  // 🆕 API 주입

  List<CategoryDataModel> _userCategories = [];
  bool _isLoading = false;
  String? _error;

  CategoryController({required CategoryApi categoryApi}) : _api = categoryApi;

  List<CategoryDataModel> get userCategories => _userCategories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 카테고리 목록 로드 (Stream 제거)
  Future<void> loadUserCategories(
    String userId, {
    bool forceReload = false,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 🆕 REST API 호출
      final response = await _api.getCategories(userId: userId);
      _userCategories = response.data?.data ?? [];

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh
  Future<void> refreshCategories(String userId) async {
    return loadUserCategories(userId, forceReload: true);
  }
}
```

---

## 🚀 실행 방법

### 개발 환경별 실행

```bash
# Dev 서버 연결
flutter run --dart-define=ENV=dev

# Local 서버 연결 (Docker)
flutter run --dart-define=ENV=local

# Staging 서버 연결
flutter run --dart-define=ENV=staging

# Production 서버 연결
flutter run --dart-define=ENV=prod
```

### VSCode Launch Configuration

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "🚀 SOI (Dev Server)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define=ENV=dev"]
    },
    {
      "name": "💻 SOI (Local Server)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define=ENV=local"]
    },
    {
      "name": "🧪 SOI (Staging Server)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define=ENV=staging"]
    },
    {
      "name": "🚢 SOI (Production)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define=ENV=prod"]
    }
  ]
}
```

이제 VSCode Run 메뉴에서 환경을 선택할 수 있습니다!

---

## 📦 pubspec.yaml 수정

```yaml
# pubspec.yaml
name: soi
dependencies:
  flutter:
    sdk: flutter

  # 🆕 HTTP 클라이언트
  dio: ^5.4.0

  # 🆕 자동 생성된 API 패키지
  soi_api:
    path: lib/api/generated

  # 기존 의존성들
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  provider: ^6.1.1
  flutter_screenutil: ^5.9.0
  # ... 기타 패키지들

dev_dependencies:
  flutter_test:
    sdk: flutter

  # 🆕 OpenAPI Generator용
  build_runner: ^2.4.0
```

---

## ✅ 체크리스트

마이그레이션 전 확인사항:

- [ ] 백엔드 개발 서버 URL 확인
- [ ] OpenAPI 스펙 다운로드 테스트
- [ ] `lib/config/` 디렉토리 생성
- [ ] `environment.dart` 파일 작성
- [ ] `api_config.dart` 파일 작성
- [ ] Dio 의존성 추가
- [ ] API 클라이언트 자동 생성
- [ ] main.dart Provider 구조 변경
- [ ] 첫 번째 Controller 수정 및 테스트
- [ ] VSCode launch.json 설정

---

## 🐛 트러블슈팅

### Q1: "Environment.dev not found" 에러

```bash
# --dart-define 없이 실행한 경우
flutter run  # ❌

# 해결: 환경 지정
flutter run --dart-define=ENV=dev  # ✅
```

### Q2: API 요청이 401 Unauthorized

```dart
// AuthInterceptor에서 토큰이 제대로 설정되었는지 확인
debugPrint('Token: ${_getStoredToken()}');
```

### Q3: "Connection refused" 에러

```bash
# Local 환경에서 백엔드가 실행 중인지 확인
curl http://localhost:8080/actuator/health

# Dev 환경에서 URL이 올바른지 확인
curl https://dev-api.soi.app/actuator/health
```

---

## 📝 다음 단계

main.dart 수정을 완료했다면:

👉 **[2. Firebase → Spring Boot 마이그레이션으로 이동](./02-firebase-to-springboot.md)**
