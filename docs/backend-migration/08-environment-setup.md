# 개발 환경 설정 가이드

로컬 백엔드 없이 개발하는 방법과 필요시 로컬 환경을 구성하는 방법을 설명합니다.

## 🌍 환경 구성 전략

### 기본 원칙

**당신은 대부분의 경우 백엔드 서버를 로컬에서 실행하지 않습니다.**

대신 다음 순서로 환경을 활용합니다:

1. **Dev 서버** (항상 켜져 있음) - 90% 작업
2. **Mock 서버** (Prism) - 백엔드 개발 전 UI 작업
3. **로컬 Docker** (선택적) - 오프라인 개발, 디버깅
4. **Staging 서버** - QA 테스트
5. **Production 서버** - 실제 서비스

---

## 🔧 1. Dev 서버 환경 (권장)

### 특징

- ✅ 항상 실행 중
- ✅ 최신 백엔드 코드 반영
- ✅ 실제 PostgreSQL 데이터베이스
- ✅ Firebase Admin SDK 연동
- ✅ 팀원 모두 동일한 데이터 공유
- ✅ 별도 설정 불필요

### Flutter 설정

```dart
// lib/config/environment.dart
enum Environment {
  local,
  dev,      // ✅ 기본 환경
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
        return 'https://dev-api.soi.app';  // ✅ Dev 서버
      case Environment.staging:
        return 'https://staging-api.soi.app';
      case Environment.production:
        return 'https://api.soi.app';
    }
  }

  static bool get isProduction => _current == Environment.production;
  static bool get isDevelopment => _current == Environment.dev || _current == Environment.local;
}
```

### VSCode 실행 설정

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "SOI (Dev)", // ✅ 기본 실행
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define=ENV=dev"]
    },
    {
      "name": "SOI (Local)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define=ENV=local"]
    },
    {
      "name": "SOI (Staging)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define=ENV=staging"]
    },
    {
      "name": "SOI (Production)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define=ENV=prod"]
    }
  ]
}
```

### 환경 변수 초기화

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 설정
  const envString = String.fromEnvironment('ENV', defaultValue: 'dev');
  final environment = Environment.values.firstWhere(
    (e) => e.name == envString,
    orElse: () => Environment.dev,
  );

  EnvironmentConfig.setEnvironment(environment);

  debugPrint('🚀 Running in ${environment.name} mode');
  debugPrint('📡 API URL: ${EnvironmentConfig.apiBaseUrl}');

  // Firebase 초기화 (선택적)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}
```

### 사용 방법

```bash
# Dev 환경으로 실행 (기본)
flutter run --dart-define=ENV=dev

# VSCode에서 F5 누르면 자동으로 Dev 환경 실행
```

---

## 🎭 2. Mock 서버 (Prism)

### 사용 시나리오

백엔드 개발이 완료되지 않았지만 UI를 먼저 구현하고 싶을 때.

### Prism 설치

```bash
# npm으로 설치
npm install -g @stoplight/prism-cli

# 또는 Docker
docker pull stoplight/prism
```

### OpenAPI 스펙 준비

```yaml
# openapi-mock.yaml (간단한 예시)
openapi: 3.0.0
info:
  title: SOI API (Mock)
  version: 1.0.0
servers:
  - url: http://localhost:4010
paths:
  /api/v1/categories:
    get:
      summary: Get categories
      parameters:
        - name: userId
          in: query
          required: true
          schema:
            type: string
      responses:
        "200":
          description: Success
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean
                    example: true
                  data:
                    type: array
                    items:
                      type: object
                      properties:
                        id:
                          type: string
                          example: cat123
                        name:
                          type: string
                          example: 가족
                        mates:
                          type: array
                          items:
                            type: object
                            properties:
                              userId:
                                type: string
                                example: user456
                              name:
                                type: string
                                example: 홍길동
                              profileImageUrl:
                                type: string
                                example: https://example.com/profile.jpg
```

### Mock 서버 실행

```bash
# Prism 실행 (동적 예시 생성)
prism mock openapi-mock.yaml

# 출력:
# [1:23:45 PM] › [CLI] …  awaiting  Starting Prism…
# [1:23:45 PM] › [CLI] ✔  success   Prism is listening on http://127.0.0.1:4010
```

### Flutter에서 사용

```bash
# Mock 서버 대상으로 실행
flutter run --dart-define=ENV=local

# main.dart에서 baseUrl이 http://localhost:4010으로 설정되어야 함
```

### Makefile에 추가

```makefile
# Makefile
.PHONY: mock-server

mock-server:
	@echo "🎭 Starting mock server..."
	@prism mock openapi-mock.yaml
```

사용:

```bash
# 터미널 1: Mock 서버 실행
make mock-server

# 터미널 2: Flutter 앱 실행
flutter run --dart-define=ENV=local
```

---

## 🐳 3. 로컬 Docker 환경 (선택적)

### 사용 시나리오

- 비행기 안에서 오프라인 개발
- 백엔드 코드를 직접 디버깅해야 할 때
- 네트워크 없는 환경

### Docker Compose 설정

```yaml
# docker-compose.yml (백엔드 프로젝트)
version: "3.8"

services:
  postgres:
    image: postgres:15-alpine
    container_name: soi-postgres
    environment:
      POSTGRES_DB: soi
      POSTGRES_USER: soi
      POSTGRES_PASSWORD: soi123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: soi-backend
    depends_on:
      - postgres
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/soi
      SPRING_DATASOURCE_USERNAME: soi
      SPRING_DATASOURCE_PASSWORD: soi123
      SPRING_JPA_HIBERNATE_DDL_AUTO: update
    ports:
      - "8080:8080"
    volumes:
      - ./src:/app/src # 코드 변경 시 핫리로드 (개발 모드)

volumes:
  postgres_data:
```

### Dockerfile

```dockerfile
# Dockerfile (백엔드 프로젝트)
FROM eclipse-temurin:17-jdk-alpine AS build

WORKDIR /app

# Gradle 파일 복사
COPY build.gradle settings.gradle gradlew ./
COPY gradle ./gradle

# 의존성 다운로드
RUN ./gradlew dependencies --no-daemon

# 소스 코드 복사
COPY src ./src

# 빌드
RUN ./gradlew bootJar --no-daemon

# 실행 이미지
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

COPY --from=build /app/build/libs/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 로컬 환경 시작

```bash
# 백엔드 프로젝트에서
cd ~/backend-project
docker-compose up -d

# 로그 확인
docker-compose logs -f backend

# 출력:
# backend | Started SoiApplication in 3.456 seconds
```

### Flutter 연결

```bash
# Flutter 앱 실행
flutter run --dart-define=ENV=local
```

### 데이터베이스 접근

```bash
# PostgreSQL 접속
docker exec -it soi-postgres psql -U soi -d soi

# SQL 실행
SELECT * FROM users;
```

### 중지 및 정리

```bash
# 중지
docker-compose down

# 데이터까지 삭제
docker-compose down -v
```

---

## 🔐 4. 인증 토큰 관리

### Dev/Staging 환경 테스트 계정

백엔드 팀에서 제공하는 테스트 계정 사용:

```dart
// lib/config/test_accounts.dart
class TestAccounts {
  static const devTestUser = {
    'phone': '+821012345678',
    'name': '테스트유저1',
    'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',  // Dev 서버 토큰
  };

  static const stagingTestUser = {
    'phone': '+821087654321',
    'name': '테스트유저2',
    'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',  // Staging 서버 토큰
  };

  static Map<String, dynamic> get current {
    switch (EnvironmentConfig.current) {
      case Environment.dev:
      case Environment.local:
        return devTestUser;
      case Environment.staging:
        return stagingTestUser;
      default:
        throw Exception('No test account for production');
    }
  }
}
```

### 개발 모드 자동 로그인

```dart
// lib/main.dart
void main() async {
  // ...

  if (EnvironmentConfig.isDevelopment) {
    // 개발 환경에서는 자동 로그인
    await _autoLoginForDevelopment();
  }

  runApp(MyApp());
}

Future<void> _autoLoginForDevelopment() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('auth_token', TestAccounts.current['token']);
  await prefs.setString('user_id', 'dev_user_123');

  debugPrint('🔐 Auto-logged in with dev token');
}
```

---

## 📊 5. 환경별 비교

| 항목              | Dev 서버  | Mock 서버        | 로컬 Docker      |
| ----------------- | --------- | ---------------- | ---------------- |
| **설정 난이도**   | ⭐ 쉬움   | ⭐⭐ 보통        | ⭐⭐⭐⭐ 어려움  |
| **사용 빈도**     | 90%       | 5%               | 5%               |
| **인터넷 필요**   | ✅ 필요   | ❌ 불필요        | ❌ 불필요        |
| **실제 데이터**   | ✅ 있음   | ❌ 없음 (예시)   | ⚠️ 로컬 DB       |
| **백엔드 디버깅** | ❌ 불가   | ❌ 불가          | ✅ 가능          |
| **최신 API 반영** | ✅ 즉시   | ⚠️ 수동 업데이트 | ⚠️ 수동 빌드     |
| **추천 사용처**   | 일상 개발 | UI 선행 개발     | 오프라인, 디버깅 |

---

## 🎯 6. 실전 시나리오별 환경 선택

### 시나리오 A: 일반적인 기능 개발

```
✅ Dev 서버 사용

1. make update-api
2. flutter run --dart-define=ENV=dev
3. 개발 및 테스트
```

### 시나리오 B: 백엔드가 아직 개발 중

```
✅ Mock 서버 사용

1. openapi-mock.yaml 작성 (예상 스펙)
2. make mock-server (터미널 1)
3. flutter run --dart-define=ENV=local (터미널 2)
4. UI 먼저 구현
5. 백엔드 완료 후 Dev 서버로 전환
```

### 시나리오 C: 비행기 안 개발

```
✅ 로컬 Docker 사용

출발 전:
1. docker-compose pull
2. 최신 백엔드 코드 pull
3. make update-api

비행기 안:
1. docker-compose up -d
2. flutter run --dart-define=ENV=local
3. 오프라인 개발
```

### 시나리오 D: API 응답 시간이 너무 느림

```
✅ Mock 서버 또는 로컬 Docker

Mock 서버:
- 빠른 응답 (< 10ms)
- UI 애니메이션 테스트에 적합

로컬 Docker:
- 실제 비즈니스 로직 테스트
- 복잡한 데이터 관계 확인
```

### 시나리오 E: 백엔드 버그 재현

```
✅ Staging 서버 또는 로컬 Docker

Staging 서버:
- 실제 서버 환경과 동일
- 백엔드 팀과 함께 디버깅

로컬 Docker:
- 백엔드 코드 수정 가능
- 로그 직접 확인
```

---

## 🛠️ 7. 환경 전환 명령어 모음

```bash
# Makefile에 추가
.PHONY: run-dev run-staging run-prod run-local mock-server docker-backend

# Dev 서버 (기본)
run-dev:
	flutter run --dart-define=ENV=dev

# Staging 서버
run-staging:
	flutter run --dart-define=ENV=staging

# Production (주의!)
run-prod:
	@echo "⚠️  WARNING: Running in PRODUCTION mode!"
	@read -p "Are you sure? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		flutter run --dart-define=ENV=prod; \
	fi

# Local (Mock 또는 Docker)
run-local:
	flutter run --dart-define=ENV=local

# Mock 서버 시작
mock-server:
	@echo "🎭 Starting mock server on http://localhost:4010"
	@prism mock openapi-mock.yaml

# Docker 백엔드 시작
docker-backend:
	@echo "🐳 Starting local backend with Docker..."
	@cd ~/backend-project && docker-compose up -d
	@echo "✅ Backend running on http://localhost:8080"

# Docker 백엔드 중지
docker-backend-stop:
	@cd ~/backend-project && docker-compose down
	@echo "✅ Backend stopped"

# 환경 확인
check-env:
	@echo "Current environment configuration:"
	@echo ""
	@echo "📍 Dev Server:     https://dev-api.soi.app"
	@echo "📍 Staging Server: https://staging-api.soi.app"
	@echo "📍 Production:     https://api.soi.app"
	@echo "📍 Local:          http://localhost:8080"
	@echo ""
	@echo "Run with:"
	@echo "  make run-dev      (recommended)"
	@echo "  make run-staging"
	@echo "  make run-local"
```

사용:

```bash
# 일상적인 개발
make run-dev

# Mock 서버 + Flutter
make mock-server &  # 백그라운드 실행
make run-local

# Docker + Flutter
make docker-backend
make run-local

# 환경 정보 확인
make check-env
```

---

## ✅ 환경 설정 체크리스트

### 초기 설정 (한 번만)

- [ ] `lib/config/environment.dart` 생성
- [ ] `.vscode/launch.json` 설정
- [ ] `Makefile`에 환경 명령어 추가
- [ ] Dev 서버 URL 확인
- [ ] 테스트 계정 받기

### 일상 개발 (매번)

- [ ] `make run-dev` 실행
- [ ] 백엔드 API 변경 시 `make update-api`
- [ ] 환경이 Dev인지 확인 (로그 출력)

### Mock 서버 사용 시

- [ ] `openapi-mock.yaml` 작성
- [ ] Prism 설치
- [ ] `make mock-server` 실행
- [ ] `make run-local` 실행

### 로컬 Docker 사용 시 (선택)

- [ ] 백엔드 프로젝트 clone
- [ ] `docker-compose.yml` 확인
- [ ] `make docker-backend` 실행
- [ ] PostgreSQL 접속 확인
- [ ] `make run-local` 실행

---

## 🎓 베스트 프랙티스

### 1. 대부분의 개발은 Dev 서버로

```bash
# 90% 작업
make run-dev
```

Dev 서버는 항상 최신 상태이고, 팀원 모두 동일한 데이터를 공유합니다.

### 2. 환경 전환은 코드 변경 없이

```bash
# 환경은 launch configuration 또는 --dart-define으로만 전환
flutter run --dart-define=ENV=dev
flutter run --dart-define=ENV=staging

# ❌ 코드에서 하드코딩하지 않기
# const apiUrl = 'https://dev-api.soi.app';  // Bad!
```

### 3. Production 환경은 신중히

```bash
# Production은 실수 방지를 위해 확인 절차 추가
make run-prod
# ⚠️  WARNING: Running in PRODUCTION mode!
# Are you sure? (yes/no):
```

### 4. 로컬 환경은 최소한으로

```bash
# 로컬 Docker는 정말 필요할 때만
# (네트워크 없음, 백엔드 디버깅 필요 등)
make docker-backend
```

---

## 📝 다음 단계

환경 설정을 완료했다면, 실제 마이그레이션을 시작할 수 있습니다:

👉 **[README로 돌아가기](./README.md)** - 전체 마이그레이션 단계 확인
👉 **[1. main.dart 설정으로 이동](./01-main-dart-setup.md)** - 첫 번째 단계 시작
