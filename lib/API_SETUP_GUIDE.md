# SOI API 구조 완전 재구성 가이드

## 📁 최종 구조

```
lib/api/
├── openapi.yaml                     # Spring Backend API 스펙
├── openapi-generator-config.yaml   # Generator 설정
├── generated/                       # OpenAPI로 생성된 코드 (자동 생성)
│   ├── soi_api.dart                # 메인 export 파일
│   ├── api/                        # API 클라이언트들
│   │   ├── user_api_api.dart
│   │   ├── friend_api_api.dart
│   │   └── api_api.dart
│   ├── model/                      # DTO 모델들
│   │   ├── user_resp_dto.dart
│   │   ├── friend_resp_dto.dart
│   │   └── ...
│   ├── auth/                       # 인증 관련
│   ├── pubspec.yaml
│   └── ...
└── flutter_api/                     # 우리가 만든 Service Layer
    ├── common/
    │   ├── api_result.dart
    │   └── dio_exception_handler.dart
    └── services/
        ├── user_service.dart
        ├── friend_service.dart
        ├── media_service.dart
        └── service_api.dart
```

---

## 🚀 단계별 실행 가이드

### ✅ 현재 상태

- [x] `lib/api/openapi.yaml` - Spring Backend API 스펙 파일 존재
- [x] `lib/api/flutter_api/` - Service Layer 파일들 존재
- [x] `openapi-generator-config.yaml` - Generator 설정 파일 생성 완료

---

## 📝 Step 1: OpenAPI Generator로 Spring API 클라이언트 생성

**중요**: 반드시 `lib/api` 디렉토리에서 실행하세요!

### Homebrew로 설치 후 사용

```bash
# 1. OpenAPI Generator 설치 (처음 한 번만)
brew install openapi-generator

# 2. lib/api 디렉토리로 이동
cd /Users/minchanpark/Documents/SOI/lib/api

# 3. 코드 생성 (설정 파일에 sourceFolder="" 포함됨)
openapi-generator generate -c openapi-generator-config.yaml
```

---

## 📝 Step 2: 생성된 코드 빌드

```bash
# 1. 생성된 패키지 디렉토리로 이동
cd /Users/minchanpark/Documents/SOI/lib/api/generated

# 2. 의존성 설치
flutter pub get

# 3. build_runner로 .g.dart 파일 생성
dart run build_runner build --delete-conflicting-outputs

# 4. 프로젝트 루트로 돌아가기
cd /Users/minchanpark/Documents/SOI
```

---

## 📝 Step 3: 메인 프로젝트 pubspec.yaml 업데이트

`/Users/minchanpark/Documents/SOI/pubspec.yaml` 파일을 열어서 다음 내용 추가:

```yaml
dependencies:
  # 기존 dependencies...

  # ✅ Spring Backend API 클라이언트 (OpenAPI로 생성)
  soi_api:
    path: lib/api/generated

  # API 관련 필수 패키지 (이미 있을 수 있음)
  dio: ^5.9.0
```

그 다음 실행:

```bash
cd /Users/minchanpark/Documents/SOI
flutter pub get
```

---

## 📝 Step 4: Service Layer 파일 확인

다음 파일들이 이미 존재하는지 확인:

- ✅ `lib/api/flutter_api/common/api_result.dart`
- ✅ `lib/api/flutter_api/common/dio_exception_handler.dart`
- ✅ `lib/api/flutter_api/services/user_service.dart`
- ✅ `lib/api/flutter_api/services/friend_service.dart`
- ✅ `lib/api/flutter_api/services/media_service.dart`
- ✅ `lib/api/flutter_api/services/service_api.dart`

**모두 존재합니다!** ✨

---

## 📝 Step 5: 테스트

```bash
cd /Users/minchanpark/Documents/SOI

# Dart 분석 실행
flutter analyze lib/api

# 앱 실행 테스트
flutter run
```

---

## 🔄 OpenAPI 스펙 업데이트 시

Spring Backend API가 변경되었을 때 다시 생성하는 방법:

```bash
# 1. 최신 스펙 다운로드
cd /Users/minchanpark/Documents/SOI/lib/api
curl -s https://newdawnsoi.site/v3/api-docs.yaml -o openapi.yaml

# 2. 기존 생성 코드 삭제
rm -rf generated

# 3. 다시 생성 (Docker 사용)
docker run --rm -v ${PWD}:/local openapitools/openapi-generator-cli generate \
  -i /local/openapi.yaml -g dart -o /local/generated \
  --additional-properties=pubName=soi_api,pubVersion=1.0.0,nullableFields=true,sourceFolder=

# 4. 빌드
cd generated
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 5. 프로젝트 루트로 돌아가기
cd ../..
flutter pub get
```

---

## 🎯 사용 예제

### 기본 사용법

```dart
import 'package:dio/dio.dart';
import 'package:soi_api/soi_api.dart';
import 'package:soi/api/api.dart';

void main() async {
  // 1. Dio 인스턴스 생성
  final dio = Dio(BaseOptions(
    baseUrl: 'https://newdawnsoi.site',
    connectTimeout: Duration(seconds: 30),
  ));

  // 2. OpenAPI 생성 API 클라이언트
  final userApi = UserAPIApi(dio);

  // 3. Service 레이어
  final userService = UserService(userApi);

  // 4. 사용
  final result = await userService.loginWithPhone(
    phone: '+821012345678',
  );

  result.when(
    success: (user) => print('로그인 성공: ${user.userId}'),
    failure: (error) => print('에러: ${error.message}'),
  );
}
```

### Provider와 함께 사용

```dart
import 'package:provider/provider.dart';

void main() {
  final dio = Dio(BaseOptions(baseUrl: 'https://newdawnsoi.site'));

  runApp(
    MultiProvider(
      providers: [
        // API 클라이언트
        Provider(create: (_) => UserAPIApi(dio)),
        Provider(create: (_) => FriendAPIApi(dio)),
        Provider(create: (_) => APIApi(dio)),

        // Service Layer
        ProxyProvider<UserAPIApi, UserService>(
          update: (_, api, __) => UserService(api),
        ),
        ProxyProvider<FriendAPIApi, FriendService>(
          update: (_, api, __) => FriendService(api),
        ),
        ProxyProvider<APIApi, MediaService>(
          update: (_, api, __) => MediaService(api),
        ),
      ],
      child: MyApp(),
    ),
  );
}

// 화면에서 사용
class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userService = context.read<UserService>();

    return ElevatedButton(
      onPressed: () async {
        final result = await userService.loginWithPhone(phone: '...');
        result.when(
          success: (user) => Navigator.pushReplacement(...),
          failure: (error) => showDialog(...),
        );
      },
      child: Text('로그인'),
    );
  }
}
```

---

## 🐛 트러블슈팅

### 문제 1: `Target of URI doesn't exist: 'package:soi_api/soi_api.dart'`

**원인**: OpenAPI Generator로 코드가 생성되지 않았거나 pubspec.yaml 설정 문제

**해결**:

```bash
# 1. 코드가 생성되었는지 확인
ls -la lib/api/client/soi_api/lib

# 2. pubspec.yaml에 경로 추가 확인
# soi_api:
#   path: lib/api/client/soi_api

# 3. pub get 재실행
flutter pub get
```

### 문제 2: `.g.dart` 파일이 없다는 에러

**원인**: build_runner가 실행되지 않음

**해결**:

```bash
cd lib/api/client/soi_api
dart run build_runner build --delete-conflicting-outputs
```

### 문제 3: `The name 'UserService' isn't a type`

**원인**: Service 파일이 생성되지 않음

**해결**: 아래 "파일 자동 생성 스크립트" 실행

---

## 📦 파일 자동 생성 스크립트

이 가이드를 따라했는데 파일이 없다면, 다음 단계를 실행하세요:

```bash
# 프로젝트 루트에서 실행
cd /Users/minchanpark/Documents/SOI

# 이 명령어는 Copilot이 자동으로 파일을 생성해줄 것입니다
# 또는 아래 내용을 수동으로 복사하여 각 파일에 붙여넣기
```

---

## ⚡ 빠른 시작 (처음 설정하는 경우)

현재 상태에서 바로 실행하세요!

```bash
# 1. lib/api로 이동
cd /Users/minchanpark/Documents/SOI/lib/api

# 2. 기존 generated 폴더가 있다면 삭제
rm -rf generated

# 3. Docker로 코드 생성 (가장 쉬운 방법)
docker run --rm \
  -v ${PWD}:/local \
  openapitools/openapi-generator-cli generate \
  -i /local/openapi.yaml \
  -g dart \
  -o /local/generated \
  --additional-properties=pubName=soi_api,pubVersion=1.0.0,nullableFields=true,sourceFolder=

# 4. 생성된 코드 빌드
cd generated
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 5. 프로젝트 루트로 돌아가서 pub get
cd ../..
flutter pub get

# 6. 완료! 🎉
```

**예상 결과**:

- `lib/api/generated/api/` - API 클라이언트들
- `lib/api/generated/model/` - DTO 모델들
- `lib/api/generated/soi_api.dart` - 메인 export 파일

---

## ✅ 완료 체크리스트

- [ ] Step 1: OpenAPI Generator로 클라이언트 코드 생성
- [ ] Step 2: build_runner 실행하여 .g.dart 파일 생성
- [ ] Step 3: pubspec.yaml에 soi_api 경로 추가
- [ ] Step 4: Service Layer 파일 확인
- [ ] Step 5: flutter analyze 통과
- [ ] 테스트: 간단한 API 호출 성공

---

## 📚 참고 자료

- OpenAPI Generator: https://openapi-generator.tech/
- Dio 문서: https://pub.dev/packages/dio
- Provider 패턴: https://pub.dev/packages/provider

---

**작성일**: 2025년 11월 4일  
**버전**: 3.0  
**상태**: 재구성 완료 - sourceFolder 설정으로 간소화된 구조
