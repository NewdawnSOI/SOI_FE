# OpenAPI/Swagger 자동화 완전 가이드

OpenAPI Generator를 사용하여 Flutter API 클라이언트를 자동 생성하고, 개발 워크플로우를 자동화하는 방법을 설명합니다.

## 🎯 핵심 개념

**수동 작성 ❌**

```dart
// CategoryApi.dart를 직접 작성
class CategoryApi {
  Future<Response> getCategories(String userId) async {
    return await _dio.get('/api/v1/categories', ...);
  }
  // ... 50개 이상의 메서드
}
```

**자동 생성 ✅**

```bash
# 백엔드 배포 → OpenAPI 스펙 다운로드 → 자동 생성
openapi-generator generate -i openapi.yaml -g dart-dio -o lib/api/generated
```

---

## 📦 1. 백엔드: OpenAPI 스펙 생성 (Spring Boot)

### 1.1. 의존성 추가

```gradle
// build.gradle
dependencies {
    // Springdoc OpenAPI
    implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.3.0'
}
```

### 1.2. OpenAPI 설정

```java
// src/main/java/com/soi/config/OpenApiConfig.java
package com.soi.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("SOI API")
                .version("1.0.0")
                .description("SOI 사진 공유 앱 REST API")
                .contact(new Contact()
                    .name("SOI Team")
                    .email("dev@soi.app")
                )
            )
            .servers(List.of(
                new Server()
                    .url("https://api.soi.app")
                    .description("Production"),
                new Server()
                    .url("https://staging-api.soi.app")
                    .description("Staging"),
                new Server()
                    .url("https://dev-api.soi.app")
                    .description("Development"),
                new Server()
                    .url("http://localhost:8080")
                    .description("Local")
            ))
            .addSecurityItem(new SecurityRequirement().addList("bearerAuth"))
            .components(new Components()
                .addSecuritySchemes("bearerAuth",
                    new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")
                        .description("JWT 토큰을 입력하세요")
                )
            );
    }
}
```

### 1.3. Controller에 OpenAPI 애노테이션 추가

```java
@RestController
@RequestMapping("/api/v1/categories")
@RequiredArgsConstructor
@Tag(name = "Category", description = "카테고리 관리 API")
public class CategoryController {

    private final CategoryService categoryService;

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
        @ApiResponse(
            responseCode = "401",
            description = "인증 실패"
        )
    })
    @GetMapping
    public ResponseEntity<ApiResponse<List<CategoryDTO>>> getCategories(
        @Parameter(description = "사용자 ID", required = true, example = "user123")
        @RequestParam String userId
    ) {
        List<CategoryDTO> categories = categoryService.getUserCategories(userId);
        return ResponseEntity.ok(ApiResponse.success(categories));
    }

    @Operation(summary = "멤버 추가", description = "카테고리에 새로운 멤버를 추가합니다")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "성공"),
        @ApiResponse(responseCode = "400", description = "잘못된 요청"),
        @ApiResponse(responseCode = "403", description = "권한 없음"),
        @ApiResponse(responseCode = "404", description = "카테고리를 찾을 수 없음")
    })
    @PostMapping("/{id}/members")
    public ResponseEntity<ApiResponse<AddMemberResponse>> addMember(
        @Parameter(description = "카테고리 ID", required = true)
        @PathVariable String id,
        @Parameter(hidden = true) @AuthenticationPrincipal String currentUserId,
        @Valid @RequestBody AddMemberRequest request
    ) {
        AddMemberResponse response = categoryService.addMember(id, currentUserId, request);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
```

### 1.4. 생성된 OpenAPI 스펙 확인

```bash
# Spring Boot 실행
./mvnw spring-boot:run

# OpenAPI 스펙 다운로드 (JSON)
curl http://localhost:8080/v3/api-docs > openapi.json

# OpenAPI 스펙 다운로드 (YAML)
curl http://localhost:8080/v3/api-docs.yaml > openapi.yaml

# Swagger UI 확인
open http://localhost:8080/swagger-ui.html
```

생성된 OpenAPI 스펙 예시:

```yaml
openapi: 3.0.1
info:
  title: SOI API
  description: SOI 사진 공유 앱 REST API
  contact:
    name: SOI Team
    email: dev@soi.app
  version: 1.0.0
servers:
  - url: https://dev-api.soi.app
    description: Development
paths:
  /api/v1/categories:
    get:
      tags:
        - Category
      summary: 카테고리 목록 조회
      description: 사용자의 모든 카테고리를 반환합니다
      operationId: getCategories
      parameters:
        - name: userId
          in: query
          description: 사용자 ID
          required: true
          schema:
            type: string
      responses:
        "200":
          description: 성공
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/CategoryListResponse"
  /api/v1/categories/{id}/members:
    post:
      tags:
        - Category
      summary: 멤버 추가
      operationId: addMember
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/AddMemberRequest"
      responses:
        "200":
          description: 성공
components:
  schemas:
    CategoryDTO:
      type: object
      properties:
        id:
          type: string
        name:
          type: string
        mates:
          type: array
          items:
            type: string
        categoryPhotoUrl:
          type: string
        createdAt:
          type: string
          format: date-time
    AddMemberRequest:
      type: object
      required:
        - targetUserId
      properties:
        targetUserId:
          type: string
    AddMemberResponse:
      type: object
      properties:
        requiresAcceptance:
          type: boolean
        inviteId:
          type: string
        pendingMemberIds:
          type: array
          items:
            type: string
        message:
          type: string
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
security:
  - bearerAuth: []
```

---

## 🔧 2. Flutter: OpenAPI Generator 설정

### 2.1. OpenAPI Generator 설치

```bash
# Homebrew (Mac)
brew install openapi-generator

# 또는 npm
npm install -g @openapitools/openapi-generator-cli

# 또는 Docker
docker pull openapitools/openapi-generator-cli
```

### 2.2. 설정 파일 생성

```yaml
# openapi-generator-config.yaml (프로젝트 루트)
generatorName: dart-dio
outputDir: lib/api/generated
inputSpec: openapi.yaml
additionalProperties:
  pubName: soi_api
  pubVersion: 1.0.0
  pubDescription: "SOI API Client"
  hideGenerationTimestamp: true
  useEnumExtension: true
  enumUnknownDefaultCase: true
```

### 2.3. Makefile 생성 (자동화)

```makefile
# Makefile (프로젝트 루트)
.PHONY: help generate-api clean-api update-api

help:
	@echo "SOI API 자동화 명령어"
	@echo ""
	@echo "make generate-api  - OpenAPI 스펙 다운로드 및 Flutter 클라이언트 생성"
	@echo "make clean-api     - 생성된 API 클라이언트 삭제"
	@echo "make update-api    - API 클라이언트 재생성"

# OpenAPI 스펙 다운로드 및 클라이언트 생성
generate-api:
	@echo "📥 Downloading OpenAPI spec from dev server..."
	@curl -s https://dev-api.soi.app/v3/api-docs.yaml -o openapi.yaml
	@echo "✅ OpenAPI spec downloaded"

	@echo "🔧 Generating Dart/Dio client..."
	@openapi-generator generate \
		-i openapi.yaml \
		-g dart-dio \
		-o lib/api/generated \
		--additional-properties=pubName=soi_api,pubVersion=1.0.0,useEnumExtension=true
	@echo "✅ Client generated at lib/api/generated"

	@echo "📦 Installing dependencies..."
	@cd lib/api/generated && flutter pub get
	@echo "✅ Dependencies installed"

	@echo ""
	@echo "🎉 Done! You can now use the generated API client"

# 생성된 파일 삭제
clean-api:
	@echo "🗑️ Cleaning generated API client..."
	@rm -rf lib/api/generated
	@rm -f openapi.yaml
	@echo "✅ Cleaned"

# 재생성 (clean + generate)
update-api: clean-api generate-api
	@echo "✅ API client updated"

# 로컬 서버에서 생성
generate-api-local:
	@echo "📥 Downloading OpenAPI spec from local server..."
	@curl -s http://localhost:8080/v3/api-docs.yaml -o openapi.yaml
	@make generate-api
```

### 2.4. 사용 방법

```bash
# API 클라이언트 생성 (Dev 서버)
make generate-api

# 또는 수동으로
curl https://dev-api.soi.app/v3/api-docs.yaml -o openapi.yaml
openapi-generator generate -i openapi.yaml -g dart-dio -o lib/api/generated

# 로컬 서버에서 생성
make generate-api-local

# 재생성 (기존 파일 삭제 후)
make update-api
```

---

## 📱 3. Flutter: 생성된 API 사용

### 3.1. 생성된 파일 구조

```
lib/api/generated/
├── .openapi-generator/
├── lib/
│   ├── api.dart                    # 메인 export 파일
│   ├── api_client.dart             # HTTP 클라이언트
│   ├── api_helper.dart             # 헬퍼 함수들
│   ├── api/
│   │   ├── category_api.dart      # ✅ 자동 생성!
│   │   ├── photo_api.dart          # ✅ 자동 생성!
│   │   ├── friend_api.dart         # ✅ 자동 생성!
│   │   └── invite_api.dart         # ✅ 자동 생성!
│   ├── model/
│   │   ├── category_dto.dart       # ✅ 자동 생성!
│   │   ├── create_category_request.dart
│   │   ├── add_member_request.dart
│   │   ├── add_member_response.dart
│   │   └── api_response.dart
│   └── auth/
│       └── auth.dart
├── pubspec.yaml
├── README.md
└── .gitignore
```

### 3.2. 생성된 API 예시

```dart
// lib/api/generated/lib/api/category_api.dart (자동 생성됨!)
part of openapi.api;

class CategoryApi {
  final Dio _dio;
  final Serializers _serializers;
  final String basePath;

  CategoryApi([Dio? dio, Serializers? serializers, String? basePath])
      : _dio = dio ?? Dio(),
        _serializers = serializers ?? standardSerializers,
        basePath = basePath ?? 'https://dev-api.soi.app';

  /// 카테고리 목록 조회
  ///
  /// Parameters:
  /// * [userId] - 사용자 ID
  ///
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  Future<Response<ApiResponseListCategoryDTO>> getCategories({
    required String userId,
    CancelToken? cancelToken,
  }) async {
    const path = '/api/v1/categories';

    final queryParams = <String, dynamic>{
      'userId': userId,
    };

    final response = await _dio.get<Object>(
      path,
      queryParameters: queryParams,
      cancelToken: cancelToken,
    );

    return Response<ApiResponseListCategoryDTO>(
      data: _serializers.deserializeWith(
        ApiResponseListCategoryDTO.serializer,
        response.data,
      ),
      headers: response.headers,
      requestOptions: response.requestOptions,
      statusCode: response.statusCode,
    );
  }

  /// 멤버 추가
  Future<Response<ApiResponseAddMemberResponse>> addMember({
    required String id,
    required AddMemberRequest addMemberRequest,
    CancelToken? cancelToken,
  }) async {
    final path = '/api/v1/categories/$id/members';

    final response = await _dio.post<Object>(
      path,
      data: _serializers.serialize(addMemberRequest),
      cancelToken: cancelToken,
    );

    return Response<ApiResponseAddMemberResponse>(
      data: _serializers.deserializeWith(
        ApiResponseAddMemberResponse.serializer,
        response.data,
      ),
      headers: response.headers,
      requestOptions: response.requestOptions,
      statusCode: response.statusCode,
    );
  }
}
```

### 3.3. Repository에서 사용

```dart
// lib/repositories/category_repository.dart (✏️ 수정)
import 'package:soi_api/api.dart';  // 생성된 API

class CategoryRepository {
  final CategoryApi _api;  // ✅ 자동 생성된 API 클라이언트

  CategoryRepository(this._api);

  /// 사용자의 카테고리 목록 조회
  Future<List<CategoryDTO>> getUserCategories(String userId) async {
    try {
      final response = await _api.getCategories(userId: userId);
      return response.data?.data ?? [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 멤버 추가
  Future<AddMemberResponse> addMember({
    required String categoryId,
    required String targetUserId,
  }) async {
    try {
      final request = AddMemberRequest((b) => b
        ..targetUserId = targetUserId
      );

      final response = await _api.addMember(
        id: categoryId,
        addMemberRequest: request,
      );

      return response.data!.data!;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    // 에러 처리
    return Exception(e.message);
  }
}
```

---

## 🤖 4. CI/CD 자동화

### 4.1. GitHub Actions 워크플로우

```yaml
# .github/workflows/generate-api-client.yml
name: Generate API Client

on:
  # 백엔드 배포 후 자동 실행
  workflow_dispatch:
    inputs:
      environment:
        description: "Environment"
        required: true
        default: "dev"
        type: choice
        options:
          - dev
          - staging
          - prod

jobs:
  generate:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set API URL
        id: set-url
        run: |
          if [ "${{ inputs.environment }}" == "prod" ]; then
            echo "API_URL=https://api.soi.app" >> $GITHUB_ENV
          elif [ "${{ inputs.environment }}" == "staging" ]; then
            echo "API_URL=https://staging-api.soi.app" >> $GITHUB_ENV
          else
            echo "API_URL=https://dev-api.soi.app" >> $GITHUB_ENV
          fi

      - name: Download OpenAPI Spec
        run: |
          curl -s ${{ env.API_URL }}/v3/api-docs.yaml -o openapi.yaml

      - name: Generate Flutter Client
        uses: openapi-generators/openapitools-generator-action@v1
        with:
          generator: dart-dio
          openapi-file: openapi.yaml
          config-file: openapi-generator-config.yaml

      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v5
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: "chore: update generated API client from ${{ inputs.environment }}"
          branch: update-api-client-${{ inputs.environment }}
          title: "🤖 Update API Client (${{ inputs.environment }})"
          body: |
            ## API Client Update

            Environment: `${{ inputs.environment }}`
            API URL: `${{ env.API_URL }}`

            Generated from OpenAPI spec.

            ### Changes
            - Updated API endpoints
            - Updated DTOs
            - Updated models

            Please review and merge.
```

### 4.2. 백엔드 배포 후 자동 트리거

```yaml
# 백엔드 프로젝트: .github/workflows/deploy.yml
name: Deploy Backend

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      # ... 배포 단계들

      - name: Trigger Flutter Client Generation
        uses: actions/github-script@v6
        with:
          github-token: ${{ secrets.PAT_TOKEN }}
          script: |
            await github.rest.actions.createWorkflowDispatch({
              owner: 'your-org',
              repo: 'soi-flutter',
              workflow_id: 'generate-api-client.yml',
              ref: 'main',
              inputs: {
                environment: 'dev'
              }
            });
```

---

## 📊 5. SOI 프로젝트 적용 시나리오

### Phase 1: 초기 설정 (한 번만)

```bash
# 1. OpenAPI Generator 설치
brew install openapi-generator

# 2. Makefile 생성
cat > Makefile << 'EOF'
# ... (위의 Makefile 내용)
EOF

# 3. .gitignore 업데이트
echo "lib/api/generated/" >> .gitignore
echo "openapi.yaml" >> .gitignore

# 4. 백엔드 팀에 요청
# - Dev 서버 URL 공유
# - OpenAPI 엔드포인트 확인
```

### Phase 2: 첫 번째 API 생성

```bash
# 1. API 클라이언트 생성
make generate-api

# 2. pubspec.yaml에 추가
# dependencies:
#   soi_api:
#     path: lib/api/generated

# 3. main.dart 수정 (DI 설정)

# 4. Repository 수정 (Firebase → API)

# 5. 테스트
flutter run --dart-define=ENV=dev
```

### Phase 3: API 변경 시 (일상적인 작업)

```bash
# 백엔드 팀이 API 수정 후 배포
# → 당신이 할 일:

# 1. API 재생성
make update-api

# 2. 변경사항 확인
git diff lib/api/generated

# 3. 코드 업데이트 (타입 에러 수정)

# 4. 테스트
flutter run --dart-define=ENV=dev
```

---

## ✅ 체크리스트

### 백엔드 팀

- [ ] Springdoc OpenAPI 의존성 추가
- [ ] OpenAPIConfig 설정
- [ ] Controller에 @Operation 애노테이션 추가
- [ ] Dev 서버에 배포
- [ ] /v3/api-docs.yaml 엔드포인트 확인
- [ ] Swagger UI 확인

### 프론트엔드 (당신)

- [ ] OpenAPI Generator 설치
- [ ] Makefile 생성
- [ ] .gitignore 업데이트
- [ ] 첫 번째 API 생성 성공
- [ ] main.dart DI 설정
- [ ] Repository 수정
- [ ] 앱 실행 및 테스트

---

## 🐛 트러블슈팅

### Q1: "openapi-generator: command not found"

```bash
# 설치 확인
which openapi-generator

# 재설치
brew reinstall openapi-generator
```

### Q2: 생성된 코드 컴파일 에러

```bash
# 1. 생성된 패키지의 의존성 설치
cd lib/api/generated
flutter pub get

# 2. 빌드 실행
flutter pub run build_runner build

# 3. 메인 프로젝트에서 의존성 추가
cd ../../..
flutter pub get
```

### Q3: API 호출 시 404 에러

```dart
// API Base URL 확인
debugPrint(EnvironmentConfig.apiBaseUrl);

// 생성된 API의 basePath 확인
debugPrint(_api.basePath);
```

---

## 📝 다음 단계

OpenAPI 자동화를 완료했다면:

👉 **[7. 개발 워크플로우로 이동](./07-development-workflow.md)**
