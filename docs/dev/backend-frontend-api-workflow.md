# 백엔드-프론트엔드 API 협업 워크플로우

## 📋 목차

1. [개요 및 전략](#개요-및-전략)
2. [백엔드 개발자 체크리스트](#백엔드-개발자-체크리스트)
3. [프론트엔드 개발자 체크리스트](#프론트엔드-개발자-체크리스트)
4. [실전 워크플로우 시나리오](#실전-워크플로우-시나리오)
5. [트러블슈팅](#트러블슈팅)

---

## 개요 및 전략

### 🎯 핵심 원칙

**"프론트엔드 개발자는 백엔드 서버를 직접 실행하지 않습니다"**

대신 다음 전략을 사용합니다:

1. **Dev Server 사용 (권장 90%)** - 항상 켜져 있는 개발 서버
2. **Mock Server 사용 (10%)** - 백엔드 개발 전 또는 서버 다운 시
3. **OpenAPI 자동화** - 수동 API 코딩 0%

### 📊 개발 환경 전략

```
┌─────────────────────────────────────────────────────────┐
│                    프론트엔드 개발                          │
│                                                         │
│  ┌─────────────┐    ┌──────────────┐    ┌──────────┐  │
│  │ Dev Server  │───▶│ API 자동 생성 │───▶│ Flutter  │  │
│  │ (90% 사용)   │    │ (OpenAPI)    │    │   앱     │  │
│  └─────────────┘    └──────────────┘    └──────────┘  │
│                                                         │
│  ┌─────────────┐    ┌──────────────┐                   │
│  │Mock Server  │───▶│ 테스트 데이터 │                   │
│  │ (10% 사용)   │    │              │                   │
│  └─────────────┘    └──────────────┘                   │
└─────────────────────────────────────────────────────────┘
```

### ✅ 장점

- ✅ 백엔드 서버 설치/실행 불필요
- ✅ 최신 API 자동 동기화
- ✅ 백엔드 다운타임 영향 최소화
- ✅ 팀 협업 효율 극대화

---

## 백엔드 개발자 체크리스트

### 1️⃣ 초기 설정 (프로젝트 시작 시 한 번)

#### 1.1. Springdoc OpenAPI 의존성 추가

```gradle
// build.gradle
dependencies {
    // Springdoc OpenAPI 3.x (Spring Boot 3.x용)
    implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.3.0'
}
```

#### 1.2. OpenAPI 설정 클래스 생성

```java
// src/main/java/com/soi/config/OpenApiConfig.java
package com.soi.config;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.info.Contact;
import io.swagger.v3.oas.annotations.servers.Server;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import org.springframework.context.annotation.Configuration;

@Configuration
@OpenAPIDefinition(
    info = @Info(
        title = "SOI API",
        version = "1.0.0",
        description = "SOI 사진 공유 앱 REST API",
        contact = @Contact(
            name = "SOI Team",
            email = "dev@soi.app"
        )
    ),
    servers = {
        @Server(url = "https://dev-api.soi.app", description = "Development"),
        @Server(url = "https://staging-api.soi.app", description = "Staging"),
        @Server(url = "https://api.soi.app", description = "Production"),
        @Server(url = "http://localhost:8080", description = "Local")
    },
    security = @SecurityRequirement(name = "bearerAuth")
)
@SecurityScheme(
    name = "bearerAuth",
    type = SecuritySchemeType.HTTP,
    scheme = "bearer",
    bearerFormat = "JWT",
    description = "JWT 인증 토큰"
)
public class OpenApiConfig {
}
```

#### 1.3. application.yml 설정

```yaml
# src/main/resources/application.yml
springdoc:
  api-docs:
    enabled: true
    path: /v3/api-docs # JSON 엔드포인트
  swagger-ui:
    enabled: true
    path: /swagger-ui.html # Swagger UI 경로
    operations-sorter: method
    tags-sorter: alpha
  packages-to-scan: com.soi.controller
  paths-to-match: /api/**
```

#### 1.4. 초기 설정 확인

```bash
# Spring Boot 실행
./mvnw spring-boot:run

# 브라우저에서 확인
# Swagger UI: http://localhost:8080/swagger-ui.html
# OpenAPI JSON: http://localhost:8080/v3/api-docs
# OpenAPI YAML: http://localhost:8080/v3/api-docs.yaml
```

**✅ 체크포인트:**

- [ ] Swagger UI 정상 접속
- [ ] OpenAPI JSON 다운로드 가능
- [ ] 서버 정보 정확히 표시

---

### 2️⃣ API 개발 시 (매번)

#### 2.1. Controller에 OpenAPI 애노테이션 추가

```java
// src/main/java/com/soi/controller/CategoryController.java
package com.soi.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/categories")
@Tag(name = "Category", description = "카테고리 관리 API")
public class CategoryController {

    @Operation(
        summary = "카테고리 목록 조회",
        description = "사용자의 모든 카테고리를 반환합니다. 차단된 사용자가 포함된 카테고리는 제외됩니다."
    )
    @ApiResponses({
        @ApiResponse(
            responseCode = "200",
            description = "성공",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = CategoryListResponse.class)
            )
        ),
        @ApiResponse(responseCode = "401", description = "인증 실패"),
        @ApiResponse(responseCode = "500", description = "서버 오류")
    })
    @GetMapping
    public ResponseEntity<ApiResponse<List<CategoryDTO>>> getCategories(
        @Parameter(description = "사용자 ID", required = true, example = "user123")
        @RequestParam String userId
    ) {
        // 구현...
    }

    @Operation(summary = "카테고리 생성")
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "생성 성공"),
        @ApiResponse(responseCode = "400", description = "잘못된 요청")
    })
    @PostMapping
    public ResponseEntity<ApiResponse<CategoryDTO>> createCategory(
        @Valid @RequestBody CreateCategoryRequest request
    ) {
        // 구현...
    }
}
```

#### 2.2. DTO 클래스에 Schema 애노테이션 추가

```java
// src/main/java/com/soi/dto/CategoryDTO.java
package com.soi.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Getter;
import java.time.LocalDateTime;
import java.util.List;

@Getter
@Builder
@Schema(description = "카테고리 정보")
public class CategoryDTO {

    @Schema(description = "카테고리 ID", example = "cat123")
    private String id;

    @Schema(description = "카테고리 이름", example = "가족", required = true)
    private String name;

    @Schema(description = "멤버 목록")
    private List<CategoryMemberDTO> mates;

    @Schema(description = "카테고리 대표 사진 URL", example = "https://...")
    private String categoryPhotoUrl;

    @Schema(description = "생성 시간")
    private LocalDateTime createdAt;
}
```

#### 2.3. Validation 애노테이션 활용

```java
// src/main/java/com/soi/dto/CreateCategoryRequest.java
package com.soi.dto;

import jakarta.validation.constraints.*;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Getter;
import lombok.NoArgsConstructor;
import java.util.List;

@Getter
@NoArgsConstructor
@Schema(description = "카테고리 생성 요청")
public class CreateCategoryRequest {

    @NotBlank(message = "카테고리 이름은 필수입니다")
    @Size(max = 50, message = "카테고리 이름은 50자 이하여야 합니다")
    @Schema(description = "카테고리 이름", example = "친구들", required = true)
    private String name;

    @Size(max = 10, message = "초기 멤버는 최대 10명입니다")
    @Schema(description = "초기 멤버 ID 목록")
    private List<String> initialMemberIds;
}
```

**✅ 체크포인트:**

- [ ] 모든 Controller에 `@Tag` 추가
- [ ] 모든 엔드포인트에 `@Operation` 추가
- [ ] Request/Response에 `@Schema` 추가
- [ ] Validation 제약사항 추가

---

### 3️⃣ Dev 서버 배포 (API 변경 시마다)

#### 3.1. 코드 커밋 및 푸시

```bash
git add .
git commit -m "feat: Add category member management API"
git push origin main
```

#### 3.2. CI/CD 자동 배포 확인

```bash
# GitHub Actions, Jenkins 등에서 자동 배포
# Dev 서버: https://dev-api.soi.app
```

#### 3.3. OpenAPI 스펙 확인

```bash
# 배포 완료 후 확인
curl https://dev-api.soi.app/v3/api-docs.yaml

# 또는 브라우저에서
open https://dev-api.soi.app/swagger-ui.html
```

#### 3.4. 프론트엔드 팀에 알림

**Slack/Teams 메시지 템플릿:**

```
✅ Category API 업데이트 완료

**Environment:** Dev
**Endpoints:**
- GET /api/v1/categories - 카테고리 목록 조회
- POST /api/v1/categories - 카테고리 생성
- POST /api/v1/categories/{id}/members - 멤버 추가

**Changes:**
- CategoryDTO에 mates 필드 타입 변경 (List<String> → List<CategoryMemberDTO>)
- AddMemberResponse에 inviteId 추가

**OpenAPI Spec:**
https://dev-api.soi.app/v3/api-docs.yaml

**Swagger UI:**
https://dev-api.soi.app/swagger-ui.html

**프론트 작업:**
`make update-api` 실행 후 CategoryRepository 확인 필요
```

**✅ 체크포인트:**

- [ ] Dev 서버 배포 완료
- [ ] OpenAPI 스펙 다운로드 가능
- [ ] Swagger UI에서 새 API 확인 가능
- [ ] 프론트엔드 팀에 알림 전송

---

## 프론트엔드 개발자 체크리스트

### 1️⃣ 초기 설정 (프로젝트 시작 시 한 번)

#### 1.1. OpenAPI Generator 설치

```bash
# Mac (Homebrew)
brew install openapi-generator

# 또는 npm
npm install -g @openapitools/openapi-generator-cli

# 설치 확인
openapi-generator version
```

#### 1.2. 프로젝트 루트에 설정 파일 생성

```yaml
# openapi-generator-config.yaml
generatorName: dart-dio
outputDir: lib/api/generated
inputSpec: openapi.yaml
additionalProperties:
  pubName: soi_api
  pubVersion: 1.0.0
  pubDescription: "SOI API Client"
  hideGenerationTimestamp: true
  useEnumExtension: true
```

#### 1.3. Makefile 생성 (자동화)

```makefile
# Makefile
.PHONY: help generate-api clean-api update-api

help:
	@echo "SOI API 자동화 명령어"
	@echo ""
	@echo "make generate-api  - Dev 서버에서 OpenAPI 스펙 다운로드 및 클라이언트 생성"
	@echo "make clean-api     - 생성된 API 클라이언트 삭제"
	@echo "make update-api    - API 클라이언트 재생성 (clean + generate)"

generate-api:
	@echo "📥 Downloading OpenAPI spec from Dev server..."
	@curl -s https://dev-api.soi.app/v3/api-docs.yaml -o openapi.yaml
	@echo "✅ Downloaded"
	@echo ""
	@echo "🔧 Generating Dart/Dio client..."
	@openapi-generator generate \
		-i openapi.yaml \
		-g dart-dio \
		-o lib/api/generated \
		--additional-properties=pubName=soi_api,pubVersion=1.0.0,useEnumExtension=true
	@echo "✅ Generated at lib/api/generated"
	@echo ""
	@echo "📦 Installing dependencies..."
	@cd lib/api/generated && flutter pub get
	@echo "✅ Done!"

clean-api:
	@echo "🗑️ Cleaning..."
	@rm -rf lib/api/generated
	@rm -f openapi.yaml
	@echo "✅ Cleaned"

update-api: clean-api generate-api
	@echo "✅ API client updated!"
```

#### 1.4. .gitignore 업데이트

```gitignore
# .gitignore
lib/api/generated/
openapi.yaml
```

#### 1.5. 환경 설정 파일 생성

```dart
// lib/config/environment.dart
enum Environment {
  local,
  dev,
  staging,
  production,
}

class EnvironmentConfig {
  static Environment _current = Environment.dev;

  static void setEnvironment(Environment env) {
    _current = env;
  }

  static String get apiBaseUrl {
    switch (_current) {
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

  static Environment get current => _current;
  static bool get isDevelopment => _current == Environment.dev || _current == Environment.local;
}
```

**✅ 체크포인트:**

- [ ] OpenAPI Generator 설치 완료
- [ ] Makefile 생성
- [ ] .gitignore 업데이트
- [ ] Environment 설정 완료

---

### 2️⃣ 첫 번째 API 생성

#### 2.1. API 클라이언트 생성

```bash
# Dev 서버에서 OpenAPI 스펙 다운로드 및 클라이언트 생성
make generate-api
```

**출력 예시:**

```
📥 Downloading OpenAPI spec from Dev server...
✅ Downloaded

🔧 Generating Dart/Dio client...
✅ Generated at lib/api/generated

📦 Installing dependencies...
✅ Done!
```

#### 2.2. 생성된 파일 구조 확인

```
lib/api/generated/
├── lib/
│   ├── api.dart                 # 메인 export
│   ├── api/
│   │   ├── category_api.dart    # ✅ 자동 생성!
│   │   ├── photo_api.dart
│   │   └── friend_api.dart
│   └── model/
│       ├── category_dto.dart    # ✅ 자동 생성!
│       └── create_category_request.dart
└── pubspec.yaml
```

#### 2.3. pubspec.yaml에 추가

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter

  # HTTP Client
  dio: ^5.4.0

  # 자동 생성된 API 클라이언트
  soi_api:
    path: lib/api/generated

  # 상태 관리
  provider: ^6.1.1
```

#### 2.4. main.dart 수정

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:soi_api/api.dart';  // ✅ 자동 생성된 API
import 'config/environment.dart';
import 'config/api_config.dart';

void main() {
  // 환경 설정
  const envString = String.fromEnvironment('ENV', defaultValue: 'dev');
  final environment = Environment.values.firstWhere(
    (e) => e.name == envString,
    orElse: () => Environment.dev,
  );
  EnvironmentConfig.setEnvironment(environment);

  debugPrint('🚀 Environment: ${environment.name}');
  debugPrint('📡 API URL: ${EnvironmentConfig.apiBaseUrl}');

  // Dio 클라이언트 생성
  final dio = ApiConfig.createDio();

  runApp(
    MultiProvider(
      providers: [
        // ✅ API 클라이언트들
        Provider<CategoryApi>(
          create: (_) => CategoryApi(dio),
        ),
        Provider<PhotoApi>(
          create: (_) => PhotoApi(dio),
        ),

        // ✅ Repository들
        Provider<CategoryRepository>(
          create: (context) => CategoryRepository(
            context.read<CategoryApi>(),
          ),
        ),

        // ✅ Controller들
        ChangeNotifierProvider<CategoryController>(
          create: (context) => CategoryController(
            context.read<CategoryRepository>(),
          ),
        ),
      ],
      child: MyApp(),
    ),
  );
}
```

#### 2.5. ApiConfig 생성

```dart
// lib/config/api_config.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'environment.dart';

class ApiConfig {
  static Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: EnvironmentConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Auth 인터셉터
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 저장된 토큰 추가
        final token = await _getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));

    // 로깅 인터셉터 (개발 모드만)
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }

    return dio;
  }

  static Future<String?> _getToken() async {
    // SharedPreferences 또는 SecureStorage에서 토큰 가져오기
    return null; // 실제 구현 필요
  }
}
```

**✅ 체크포인트:**

- [ ] `make generate-api` 성공
- [ ] lib/api/generated/ 폴더 생성 확인
- [ ] pubspec.yaml 업데이트
- [ ] main.dart DI 설정 완료
- [ ] ApiConfig 생성 완료

---

### 3️⃣ API 사용 (매번)

#### 3.1. Repository 수정

```dart
// lib/repositories/category_repository.dart
import 'package:soi_api/api.dart';  // ✅ 자동 생성
import 'package:dio/dio.dart';

class CategoryRepository {
  final CategoryApi _api;  // ✅ 자동 생성된 API

  CategoryRepository(this._api);

  /// 카테고리 목록 조회
  Future<List<CategoryDTO>> getUserCategories() async {
    try {
      final response = await _api.getCategories();
      return response.data?.data ?? [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 카테고리 생성
  Future<CategoryDTO> createCategory(String name, List<String> memberIds) async {
    try {
      final request = CreateCategoryRequest(
        name: name,
        initialMemberIds: memberIds,
      );

      final response = await _api.createCategory(request);
      return response.data!.data!;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    final errorCode = e.response?.data?['error']?['code'];
    switch (errorCode) {
      case 'FRIEND_NOT_FOUND':
        return Exception('친구를 먼저 추가해주세요');
      case 'CATEGORY_FULL':
        return Exception('카테고리 인원이 가득 찼습니다 (최대 10명)');
      default:
        return Exception(e.message ?? '알 수 없는 오류');
    }
  }
}
```

#### 3.2. Controller 수정

```dart
// lib/controllers/category_controller.dart
import 'package:flutter/foundation.dart';
import 'package:soi_api/api.dart';  // ✅ DTO 사용
import '../repositories/category_repository.dart';

class CategoryController extends ChangeNotifier {
  final CategoryRepository _repository;

  List<CategoryDTO> _categories = [];
  List<CategoryDTO> get categories => _categories;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  CategoryController(this._repository);

  /// 카테고리 목록 로드
  Future<void> loadCategories({bool forceReload = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _categories = await _repository.getUserCategories();
    } catch (e) {
      debugPrint('❌ Load categories error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

#### 3.3. 앱 실행

```bash
# Dev 서버로 실행
flutter run --dart-define=ENV=dev

# 또는 VSCode에서 F5 (launch.json 설정 후)
```

**✅ 체크포인트:**

- [ ] Repository API 호출 성공
- [ ] Controller 데이터 로드 성공
- [ ] UI에 데이터 정상 표시

---

### 4️⃣ API 변경 시 (백엔드 업데이트 후)

#### 4.1. 백엔드 팀 알림 확인

```
✅ Category API 업데이트 완료
...
프론트 작업: `make update-api` 실행
```

#### 4.2. API 재생성

```bash
# 한 줄 명령어
make update-api
```

#### 4.3. 변경사항 확인

```bash
# Git diff로 변경 확인
git diff lib/api/generated
```

#### 4.4. 코드 수정

```dart
// 타입 에러가 발생하면 수정
// 예: CategoryDTO의 mates 필드 타입이 변경된 경우
// List<String> → List<CategoryMemberDTO>
```

#### 4.5. 테스트

```bash
flutter run --dart-define=ENV=dev
```

**✅ 체크포인트:**

- [ ] `make update-api` 성공
- [ ] 컴파일 에러 수정 완료
- [ ] 테스트 통과

---

## 실전 워크플로우 시나리오

### 시나리오 1: 정상 개발 (Dev Server 사용) ⭐ 권장

**상황:** 백엔드 팀이 Dev 서버를 운영 중

```
┌──────────────────────────────────────────────────────┐
│          일상적인 개발 흐름 (90% 케이스)                 │
└──────────────────────────────────────────────────────┘

백엔드:
1. API 개발 및 애노테이션 추가
2. Dev 서버에 배포
3. Slack에 알림 전송

프론트엔드:
1. Slack 알림 확인
2. make update-api 실행  ← 핵심! 이것만 하면 됨
3. 자동 생성된 API 사용
4. 테스트

총 소요 시간: 5분
```

**프론트엔드 작업:**

```bash
# 1. API 업데이트
make update-api

# 2. 앱 실행
flutter run --dart-define=ENV=dev

# 끝!
```

**장점:**

- ✅ 백엔드 서버 설치 불필요
- ✅ 최신 API 자동 반영
- ✅ 실제 데이터로 테스트

---

### 시나리오 2: 백엔드 서버 없을 때 (Mock Server) 🎭

**상황:**

- 백엔드가 아직 개발 중
- Dev 서버가 일시적으로 다운
- UI 먼저 구현하고 싶을 때

#### 옵션 A: Prism Mock Server 사용

```bash
# 1. Prism 설치
npm install -g @stoplight/prism-cli

# 2. OpenAPI 스펙으로 Mock 서버 실행
prism mock openapi.yaml

# 출력:
# [1:23:45 PM] › [CLI] ✔  success   Prism is listening on http://127.0.0.1:4010
```

```dart
// lib/config/environment.dart 수정
static String get apiBaseUrl {
  switch (_current) {
    case Environment.local:
      return 'http://localhost:4010';  // ← Prism Mock Server
    case Environment.dev:
      return 'https://dev-api.soi.app';
    // ...
  }
}
```

```bash
# 3. Flutter 앱 실행 (Mock 서버 대상)
flutter run --dart-define=ENV=local
```

**장점:**

- ✅ 백엔드 없이 개발 가능
- ✅ OpenAPI 스펙 기반 응답
- ✅ 빠른 응답 속도 (< 10ms)

**단점:**

- ⚠️ 더미 데이터만 제공
- ⚠️ 비즈니스 로직 없음

#### 옵션 B: 로컬 Mock 데이터

```dart
// lib/repositories/category_repository_mock.dart
import 'package:soi_api/api.dart';

class CategoryRepositoryMock implements CategoryRepository {
  @override
  Future<List<CategoryDTO>> getUserCategories() async {
    // 지연 시뮬레이션
    await Future.delayed(Duration(milliseconds: 500));

    // Mock 데이터
    return [
      CategoryDTO(
        id: 'cat1',
        name: '가족',
        mates: [
          CategoryMemberDTO(
            userId: 'user1',
            name: '엄마',
            profileImageUrl: 'https://...',
          ),
        ],
        categoryPhotoUrl: 'https://...',
        createdAt: DateTime.now(),
      ),
      // ... 더 많은 Mock 데이터
    ];
  }
}
```

```dart
// lib/main.dart에서 환경에 따라 선택
Provider<CategoryRepository>(
  create: (context) => EnvironmentConfig.isDevelopment
      ? CategoryRepositoryMock()  // Mock 데이터
      : CategoryRepository(context.read<CategoryApi>()),  // 실제 API
),
```

**장점:**

- ✅ 오프라인 개발 가능
- ✅ 원하는 데이터 커스터마이징

**단점:**

- ⚠️ Mock 데이터 수동 관리 필요

---

### 시나리오 3: 새로운 API 추가 (전체 흐름)

**예시: 사진 좋아요 기능 추가**

#### 백엔드 개발자 (Day 1)

```java
// 1. Entity, DTO, Repository, Service 개발
// 2. Controller 작성
@RestController
@RequestMapping("/api/v1/photos/{photoId}/likes")
@Tag(name = "PhotoLike", description = "사진 좋아요 API")
public class PhotoLikeController {

    @Operation(summary = "좋아요 토글")
    @PostMapping
    public ResponseEntity<ApiResponse<PhotoLikeResponse>> toggleLike(
        @PathVariable String photoId
    ) {
        // ...
    }
}

// 3. Dev 서버 배포
git push origin main

// 4. Slack 알림
```

```
✅ Photo Like API 배포 완료

**Endpoints:**
- POST /api/v1/photos/{photoId}/likes - 좋아요 토글

**OpenAPI Spec:**
https://dev-api.soi.app/v3/api-docs.yaml

**프론트 작업:**
`make update-api` 실행
```

#### 프론트엔드 개발자 (Day 2)

```bash
# 1. API 재생성
make update-api

# 출력:
# ✅ PhotoLikeApi 생성됨
# ✅ PhotoLikeResponse 생성됨
```

```dart
// 2. Repository 추가
class PhotoLikeRepository {
  final PhotoLikeApi _api;  // ✅ 자동 생성!

  Future<PhotoLikeResponse> toggleLike(String photoId) async {
    final response = await _api.toggleLike(photoId: photoId);
    return response.data!.data!;
  }
}

// 3. Controller 추가
class PhotoLikeController extends ChangeNotifier {
  final PhotoLikeRepository _repository;

  Future<void> toggleLike(String photoId) async {
    await _repository.toggleLike(photoId);
    notifyListeners();
  }
}

// 4. UI 구현
class PhotoLikeButton extends StatelessWidget {
  // ...
}
```

```bash
# 5. 테스트
flutter run --dart-define=ENV=dev
```

**총 소요 시간: 2일 (백엔드 1일 + 프론트 1일)**

---

## 트러블슈팅

### Q1: "openapi-generator: command not found"

**해결:**

```bash
# 재설치
brew reinstall openapi-generator

# 또는 npm 버전 사용
npm install -g @openapitools/openapi-generator-cli
```

---

### Q2: `make generate-api` 시 "Failed to download OpenAPI spec"

**원인:** Dev 서버 접근 불가

**해결:**

```bash
# 1. Dev 서버 상태 확인
curl https://dev-api.soi.app/v3/api-docs.yaml

# 2. VPN 확인 (필요한 경우)

# 3. 백엔드 팀에 문의
```

**임시 해결 (Mock Server 사용):**

```bash
# Prism으로 Mock 서버 실행
prism mock openapi.yaml

# Local 환경으로 개발
flutter run --dart-define=ENV=local
```

---

### Q3: 생성된 코드 컴파일 에러

**해결:**

```bash
# 1. 생성된 패키지 의존성 설치
cd lib/api/generated
flutter pub get

# 2. Build Runner 실행
flutter pub run build_runner build

# 3. 메인 프로젝트 의존성 재설치
cd ../../..
flutter pub get
```

---

### Q4: API 호출 시 404 에러

**원인 1: Base URL 잘못 설정**

```dart
// 확인
debugPrint(EnvironmentConfig.apiBaseUrl);
```

**원인 2: 엔드포인트 경로 오류**

```bash
# Swagger UI에서 정확한 경로 확인
open https://dev-api.soi.app/swagger-ui.html
```

**원인 3: 환경 설정 오류**

```bash
# Dev 환경으로 실행했는지 확인
flutter run --dart-define=ENV=dev
```

---

### Q5: 백엔드 API가 변경되었는데 Flutter에 반영 안됨

**해결:**

```bash
# 1. 강제 재생성
make update-api

# 2. Flutter 클린 빌드
flutter clean
flutter pub get

# 3. 재실행
flutter run --dart-define=ENV=dev
```

---

### Q6: Mock Server로 개발 중인데 실제 데이터가 필요함

**해결:**

```bash
# 1. Mock Server 종료 (Ctrl+C)

# 2. Dev 환경으로 전환
flutter run --dart-define=ENV=dev

# Dev 서버의 실제 데이터 사용
```

---

## 📝 요약

### 백엔드 개발자 할 일

1. ✅ Springdoc OpenAPI 설정 (초기 1회)
2. ✅ Controller에 애노테이션 추가 (매번)
3. ✅ Dev 서버 배포 (매번)
4. ✅ 프론트 팀에 알림 (매번)

### 프론트엔드 개발자 할 일

1. ✅ OpenAPI Generator 설치 (초기 1회)
2. ✅ Makefile 설정 (초기 1회)
3. ✅ `make update-api` 실행 (백엔드 변경 시)
4. ✅ 자동 생성된 API 사용 (매번)

### 핵심 명령어

```bash
# 프론트엔드 (가장 자주 사용)
make update-api              # API 재생성
flutter run --dart-define=ENV=dev  # Dev 서버로 실행

# 백엔드
./mvnw spring-boot:run       # 로컬 서버 실행
open http://localhost:8080/swagger-ui.html  # Swagger UI

# Mock Server (백엔드 없을 때)
prism mock openapi.yaml      # Mock 서버 실행
flutter run --dart-define=ENV=local  # Mock 서버로 실행
```

---

## 🎓 베스트 프랙티스

### DO ✅

- ✅ 대부분 Dev 서버 사용
- ✅ `make update-api` 정기적 실행
- ✅ 환경 변수로 서버 전환
- ✅ Mock Server로 UI 선행 개발
- ✅ OpenAPI 스펙 버전 관리

### DON'T ❌

- ❌ 백엔드 서버 로컬 실행 (불필요)
- ❌ API 클라이언트 수동 작성
- ❌ 하드코딩된 API URL
- ❌ Production 환경 테스트
- ❌ 생성된 코드 수정

---

**📚 더 자세한 내용:**

- [전체 마이그레이션 가이드](../backend-migration/README.md)
- [OpenAPI 자동화 상세](../backend-migration/06-openapi-automation.md)
- [개발 워크플로우](../backend-migration/07-development-workflow.md)
